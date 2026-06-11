import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;
import 'package:image/image.dart' as img;

/// Result of an auto-crop operation.
class AutoCropResult {
  /// Cropped (perspective-corrected) image, or the original when [fallbackUsed].
  final Uint8List croppedImageData;

  /// Detected document corners in **original image** pixel coordinates,
  /// ordered top-left, top-right, bottom-right, bottom-left.
  final List<Offset> corners;

  /// Processing duration in milliseconds (informational).
  final int durationMs;

  /// Detection confidence in `[0, 1]`.
  final double confidence;

  /// True when detection was not confident and the original image was returned.
  final bool fallbackUsed;

  /// Diagnostic metadata.
  final Map<String, dynamic> metadata;

  const AutoCropResult({
    required this.croppedImageData,
    required this.corners,
    required this.durationMs,
    required this.confidence,
    required this.fallbackUsed,
    required this.metadata,
  });
}

/// Detects a bright document on a darker background (Otsu binarisation +
/// largest-white-blob), then perspective-corrects it.
///
/// This targets the common "printed sheet on a desk" case (see issue #30). It
/// is intentionally a single, well-understood strategy rather than a brittle
/// Canny/contour pipeline. All work is pure Dart on [img.Image], so it can run
/// inside an isolate via `compute`.
class AutoCropper {
  /// Long-edge size the detection runs at (for speed); corners are scaled back.
  static const int _maxProcessingDimension = 800;

  /// A blob must cover at least this fraction of the frame to be a document.
  static const double _minBlobRatio = 0.15;

  /// A blob covering more than this is treated as "no contrast" (skip).
  static const double _maxBlobRatio = 0.97;

  /// Minimum confidence required to actually apply the perspective crop.
  static const double _minConfidence = 0.5;

  /// Minimum output edge length (px) to avoid degenerate crops.
  static const int _minOutputDimension = 16;

  /// Perform auto-crop on the given encoded image bytes.
  Future<AutoCropResult> autoCrop(Uint8List imageData) async {
    final stopwatch = Stopwatch()..start();
    final metadata = <String, dynamic>{};

    final original = img.decodeImage(imageData);
    if (original == null) {
      throw Exception('Failed to decode image');
    }

    metadata['originalWidth'] = original.width;
    metadata['originalHeight'] = original.height;

    try {
      // Downscale for detection only.
      final maxDim = math.max(original.width, original.height);
      final scale = maxDim > _maxProcessingDimension
          ? _maxProcessingDimension / maxDim
          : 1.0;
      final working = scale < 1.0
          ? img.copyResize(
              original,
              width: (original.width * scale).round(),
              height: (original.height * scale).round(),
            )
          : original;

      final detection = _detectWhiteBlob(working);

      if (detection == null || detection.confidence < _minConfidence) {
        return _fallback(
          original,
          imageData,
          stopwatch,
          metadata,
          detection == null ? 'no_document' : 'low_confidence',
          detection?.confidence ?? 0.0,
        );
      }

      // Scale corners back to original resolution.
      final invScale = scale < 1.0 ? 1.0 / scale : 1.0;
      final corners = detection.corners
          .map((c) => Offset(c.dx * invScale, c.dy * invScale))
          .toList();

      final warped = _perspectiveWarp(original, corners);
      if (warped == null) {
        return _fallback(
          original,
          imageData,
          stopwatch,
          metadata,
          'degenerate_quad',
          detection.confidence,
        );
      }

      stopwatch.stop();
      metadata['detectionTimeMs'] = stopwatch.elapsedMilliseconds;
      metadata['detectionMethod'] = 'otsu_white_blob';
      metadata['blobRatio'] = detection.blobRatio;

      return AutoCropResult(
        croppedImageData: Uint8List.fromList(
          img.encodeJpg(warped, quality: 95),
        ),
        corners: corners,
        durationMs: stopwatch.elapsedMilliseconds,
        confidence: detection.confidence,
        fallbackUsed: false,
        metadata: metadata,
      );
    } catch (e) {
      return _fallback(
        original,
        imageData,
        stopwatch,
        metadata,
        'error: $e',
        0.0,
      );
    }
  }

  /// Detect document corners (in original-image coordinates) **without**
  /// warping. Returns null when no confident document is found.
  ///
  /// Useful for pre-positioning the crop handles in the editor.
  ({List<Offset> corners, double confidence})? detectCorners(
    Uint8List imageData,
  ) {
    final original = img.decodeImage(imageData);
    if (original == null) return null;

    final maxDim = math.max(original.width, original.height);
    final scale = maxDim > _maxProcessingDimension
        ? _maxProcessingDimension / maxDim
        : 1.0;
    final working = scale < 1.0
        ? img.copyResize(
            original,
            width: (original.width * scale).round(),
            height: (original.height * scale).round(),
          )
        : original;

    final detection = _detectWhiteBlob(working);
    if (detection == null) return null;

    final invScale = scale < 1.0 ? 1.0 / scale : 1.0;
    final corners = detection.corners
        .map((c) => Offset(c.dx * invScale, c.dy * invScale))
        .toList();
    return (corners: corners, confidence: detection.confidence);
  }

  // ---------------------------------------------------------------------------
  // Detection
  // ---------------------------------------------------------------------------

  _Detection? _detectWhiteBlob(img.Image image) {
    final width = image.width;
    final height = image.height;
    final total = width * height;
    if (total == 0) return null;

    // Luminance + histogram (flat typed arrays; rows are NOT aliased).
    final luminance = Uint8List(total);
    final histogram = List<int>.filled(256, 0);
    var idx = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = image.getPixel(x, y);
        final lum = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(
          0,
          255,
        );
        luminance[idx++] = lum;
        histogram[lum]++;
      }
    }

    final threshold = _otsuThreshold(histogram, total);

    // Connected components over "bright" pixels (iterative BFS — no recursion).
    final labels = Int32List(total);
    final queue = <int>[];
    var bestLabel = 0;
    var bestSize = 0;
    var nextLabel = 0;

    for (var seed = 0; seed < total; seed++) {
      if (luminance[seed] <= threshold || labels[seed] != 0) continue;
      nextLabel++;
      var size = 0;
      labels[seed] = nextLabel;
      queue
        ..clear()
        ..add(seed);
      while (queue.isNotEmpty) {
        final ci = queue.removeLast();
        size++;
        final cx = ci % width;
        final cy = ci ~/ width;
        // 4-connected neighbours.
        if (cx > 0) {
          _visit(ci - 1, nextLabel, threshold, luminance, labels, queue);
        }
        if (cx < width - 1) {
          _visit(ci + 1, nextLabel, threshold, luminance, labels, queue);
        }
        if (cy > 0) {
          _visit(ci - width, nextLabel, threshold, luminance, labels, queue);
        }
        if (cy < height - 1) {
          _visit(ci + width, nextLabel, threshold, luminance, labels, queue);
        }
      }
      if (size > bestSize) {
        bestSize = size;
        bestLabel = nextLabel;
      }
    }

    if (bestLabel == 0) return null;

    final blobRatio = bestSize / total;
    if (blobRatio < _minBlobRatio || blobRatio > _maxBlobRatio) {
      return null;
    }

    // Extreme corners of the blob (robust 4-corner extraction):
    //   TL = min(x+y), BR = max(x+y), TR = max(x-y), BL = min(x-y).
    double minSum = double.infinity, maxSum = -double.infinity;
    double minDiff = double.infinity, maxDiff = -double.infinity;
    Offset tl = Offset.zero,
        tr = Offset.zero,
        br = Offset.zero,
        bl = Offset.zero;
    idx = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (labels[idx++] != bestLabel) continue;
        final s = x + y.toDouble();
        final d = x - y.toDouble();
        if (s < minSum) {
          minSum = s;
          tl = Offset(x.toDouble(), y.toDouble());
        }
        if (s > maxSum) {
          maxSum = s;
          br = Offset(x.toDouble(), y.toDouble());
        }
        if (d > maxDiff) {
          maxDiff = d;
          tr = Offset(x.toDouble(), y.toDouble());
        }
        if (d < minDiff) {
          minDiff = d;
          bl = Offset(x.toDouble(), y.toDouble());
        }
      }
    }

    final corners = <Offset>[tl, tr, br, bl];
    final quadArea = _polygonArea(corners);
    if (quadArea <= 0) return null;

    // Confidence: rectangularity (right angles) × solidity (blob fills its
    // quad) gated by sensible coverage.
    final rect = _rectangularity(corners);
    final solidity = (bestSize / quadArea).clamp(0.0, 1.0);
    final confidence = (0.5 * rect + 0.5 * solidity).clamp(0.0, 1.0);

    return _Detection(corners, confidence, blobRatio);
  }

  static void _visit(
    int i,
    int label,
    int threshold,
    Uint8List luminance,
    Int32List labels,
    List<int> queue,
  ) {
    if (labels[i] != 0 || luminance[i] <= threshold) return;
    labels[i] = label;
    queue.add(i);
  }

  static int _otsuThreshold(List<int> histogram, int total) {
    var sum = 0.0;
    for (var i = 0; i < 256; i++) {
      sum += i * histogram[i];
    }
    var sumB = 0.0;
    var weightB = 0;
    var maxVariance = 0.0;
    var threshold = 0;
    for (var i = 0; i < 256; i++) {
      weightB += histogram[i];
      if (weightB == 0) continue;
      final weightF = total - weightB;
      if (weightF == 0) break;
      sumB += i * histogram[i];
      final meanB = sumB / weightB;
      final meanF = (sum - sumB) / weightF;
      final variance = weightB * weightF * (meanB - meanF) * (meanB - meanF);
      if (variance > maxVariance) {
        maxVariance = variance;
        threshold = i;
      }
    }
    return threshold;
  }

  /// 1.0 when all four interior angles are 90°, decreasing with deviation.
  double _rectangularity(List<Offset> c) {
    var deviation = 0.0;
    for (var i = 0; i < 4; i++) {
      final prev = c[(i + 3) % 4];
      final cur = c[i];
      final next = c[(i + 1) % 4];
      final v1 = prev - cur;
      final v2 = next - cur;
      final denom = v1.distance * v2.distance;
      if (denom == 0) return 0.0;
      final cos = ((v1.dx * v2.dx + v1.dy * v2.dy) / denom).clamp(-1.0, 1.0);
      final angle = math.acos(cos);
      deviation += (angle - math.pi / 2).abs();
    }
    final avg = deviation / 4.0;
    return math.max(0.0, 1.0 - avg / (math.pi / 4));
  }

  double _polygonArea(List<Offset> pts) {
    var area = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      area += a.dx * b.dy - b.dx * a.dy;
    }
    return area.abs() / 2.0;
  }

  // ---------------------------------------------------------------------------
  // Perspective warp (real homography + bilinear sampling, pure Dart)
  // ---------------------------------------------------------------------------

  img.Image? _perspectiveWarp(img.Image src, List<Offset> quad) {
    final wTop = (quad[1] - quad[0]).distance;
    final wBot = (quad[2] - quad[3]).distance;
    final hLeft = (quad[3] - quad[0]).distance;
    final hRight = (quad[2] - quad[1]).distance;

    final outW = math.max(wTop, wBot).round();
    final outH = math.max(hLeft, hRight).round();
    if (outW < _minOutputDimension || outH < _minOutputDimension) return null;

    final dest = <Offset>[
      const Offset(0, 0),
      Offset(outW.toDouble(), 0),
      Offset(outW.toDouble(), outH.toDouble()),
      Offset(0, outH.toDouble()),
    ];

    // H maps destination (output) -> source (quad), so each output pixel maps
    // back into the source for sampling.
    final h = _homography(dest, quad);
    if (h == null) return null;

    final out = img.Image(width: outW, height: outH);
    final maxX = src.width - 1;
    final maxY = src.height - 1;
    for (var y = 0; y < outH; y++) {
      for (var x = 0; x < outW; x++) {
        final w = h[6] * x + h[7] * y + h[8];
        if (w == 0) continue;
        final sx = (h[0] * x + h[1] * y + h[2]) / w;
        final sy = (h[3] * x + h[4] * y + h[5]) / w;
        if (sx < 0 || sy < 0 || sx > maxX || sy > maxY) {
          out.setPixel(x, y, img.ColorRgb8(255, 255, 255));
          continue;
        }
        out.setPixel(x, y, _bilinear(src, sx, sy));
      }
    }
    return out;
  }

  img.Color _bilinear(img.Image src, double x, double y) {
    final x1 = x.floor();
    final y1 = y.floor();
    final x2 = math.min(x1 + 1, src.width - 1);
    final y2 = math.min(y1 + 1, src.height - 1);
    final dx = x - x1;
    final dy = y - y1;

    final p11 = src.getPixel(x1, y1);
    final p21 = src.getPixel(x2, y1);
    final p12 = src.getPixel(x1, y2);
    final p22 = src.getPixel(x2, y2);

    double lerp(num a, num b, num c, num d) {
      final top = a * (1 - dx) + b * dx;
      final bot = c * (1 - dx) + d * dx;
      return top * (1 - dy) + bot * dy;
    }

    return img.ColorRgb8(
      lerp(p11.r, p21.r, p12.r, p22.r).round().clamp(0, 255),
      lerp(p11.g, p21.g, p12.g, p22.g).round().clamp(0, 255),
      lerp(p11.b, p21.b, p12.b, p22.b).round().clamp(0, 255),
    );
  }

  /// Solve the 8-parameter homography mapping [from] -> [to] (4 point pairs).
  /// Returns a 9-element row-major matrix (h8 == 1), or null if singular.
  List<double>? _homography(List<Offset> from, List<Offset> to) {
    final a = <List<double>>[];
    final b = <double>[];
    for (var i = 0; i < 4; i++) {
      final s = from[i];
      final d = to[i];
      a.add([s.dx, s.dy, 1, 0, 0, 0, -s.dx * d.dx, -s.dy * d.dx]);
      b.add(d.dx);
      a.add([0, 0, 0, s.dx, s.dy, 1, -s.dx * d.dy, -s.dy * d.dy]);
      b.add(d.dy);
    }
    final x = _solve(a, b);
    if (x == null) return null;
    return [x[0], x[1], x[2], x[3], x[4], x[5], x[6], x[7], 1.0];
  }

  /// Gaussian elimination with partial pivoting. Returns null if singular.
  List<double>? _solve(List<List<double>> a, List<double> b) {
    final n = a.length;
    final m = [
      for (var i = 0; i < n; i++) [...a[i], b[i]],
    ];
    for (var i = 0; i < n; i++) {
      var pivot = i;
      for (var k = i + 1; k < n; k++) {
        if (m[k][i].abs() > m[pivot][i].abs()) pivot = k;
      }
      if (m[pivot][i].abs() < 1e-9) return null; // singular
      if (pivot != i) {
        final tmp = m[i];
        m[i] = m[pivot];
        m[pivot] = tmp;
      }
      for (var k = i + 1; k < n; k++) {
        final factor = m[k][i] / m[i][i];
        for (var j = i; j <= n; j++) {
          m[k][j] -= factor * m[i][j];
        }
      }
    }
    final x = List<double>.filled(n, 0);
    for (var i = n - 1; i >= 0; i--) {
      var sum = m[i][n];
      for (var j = i + 1; j < n; j++) {
        sum -= m[i][j] * x[j];
      }
      x[i] = sum / m[i][i];
    }
    return x;
  }

  // ---------------------------------------------------------------------------
  // Fallback
  // ---------------------------------------------------------------------------

  AutoCropResult _fallback(
    img.Image original,
    Uint8List originalData,
    Stopwatch stopwatch,
    Map<String, dynamic> metadata,
    String reason,
    double confidence,
  ) {
    stopwatch.stop();
    metadata['detectionTimeMs'] = stopwatch.elapsedMilliseconds;
    metadata['detectionMethod'] = 'fallback';
    metadata['fallbackReason'] = reason;

    final w = original.width.toDouble();
    final h = original.height.toDouble();
    return AutoCropResult(
      // Return the ORIGINAL bytes unchanged (no silent re-encode loss).
      croppedImageData: originalData,
      corners: [const Offset(0, 0), Offset(w, 0), Offset(w, h), Offset(0, h)],
      durationMs: stopwatch.elapsedMilliseconds,
      confidence: confidence,
      fallbackUsed: true,
      metadata: metadata,
    );
  }
}

/// Internal detection result.
class _Detection {
  final List<Offset> corners;
  final double confidence;
  final double blobRatio;
  const _Detection(this.corners, this.confidence, this.blobRatio);
}
