import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../models/scanned_document.dart';
import 'image_processing_isolate.dart';
import 'auto_cropper.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Blur-detection: Laplacian variance below this value is considered blurry.
const double _blurVarianceThreshold = 100.0;

/// Image quality analysis thresholds.
const double _brightnessTooLow = 0.3;
const double _brightnessTooHigh = 0.8;
const double _contrastTooLow = 0.3;

/// Contrast multiplier applied during basic enhancement.
const double _contrastMultiplier = 1.2;

/// Minimum acceptable output dimension (pixels).
const double _minOutputDimension = 100;

/// Default fallback output dimensions when corner data is invalid.
const Size _defaultFallbackSize = Size(400, 300);

/// Number of leading/trailing bytes used for the image-data cache key.
const int _hashSampleBytes = 10;

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// High-level image processing service.
///
/// Coordinates auto-crop, colour filters, perspective correction, and image
/// quality analysis. Delegates heavy lifting to [ImageProcessingIsolateService]
/// and [AutoCropper].
class ImageProcessor {
  final ImageProcessingIsolateService _isolateService;
  final AutoCropper _autoCropper;
  final Map<String, List<Offset>> _edgeCache = {};

  ImageProcessor()
      : _isolateService = ImageProcessingIsolateService(),
        _autoCropper = AutoCropper();

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Process image according to [options].
  ///
  /// If [autoCorrectPerspective] is enabled, uses the [AutoCropper] pipeline
  /// first, then applies colour filters. Otherwise falls back to the
  /// [ImageProcessingIsolateService] pipeline.
  Future<Uint8List> processImage(
    Uint8List imageData,
    DocumentProcessingOptions options,
  ) async {
    try {
      if (options.autoCorrectPerspective) {
        final autoCropResult = await _autoCropper.autoCrop(imageData);

        if (options.convertToGrayscale || options.enhanceContrast) {
          return await _applyAdditionalProcessing(
            autoCropResult.croppedImageData,
            options,
          );
        }
        return autoCropResult.croppedImageData;
      }

      final job = ImageProcessingJob(
        imageData: imageData,
        options: options,
        detectEdges: false,
        jobId: _generateJobId(),
      );

      final result = await _isolateService.processImageInBackground(job);

      if (result.error != null) {
        throw ImageProcessingException(result.error!);
      }
      if (result.processedImageData == null) {
        throw ImageProcessingException('No processed image data returned');
      }

      if (result.detectedEdges != null && result.detectedEdges!.isNotEmpty) {
        _edgeCache[job.jobId!] = result.detectedEdges!;
      }

      return result.processedImageData!;
    } catch (e) {
      throw ImageProcessingException('Failed to process image: $e');
    }
  }

  /// Process image with auto-crop and return a rich result including metadata.
  Future<Map<String, dynamic>> processImageWithAutoCrop(
    Uint8List imageData,
    DocumentProcessingOptions options,
  ) async {
    try {
      if (options.autoCorrectPerspective) {
        final autoCropResult = await _autoCropper.autoCrop(imageData);

        Uint8List finalData = autoCropResult.croppedImageData;
        if (options.convertToGrayscale || options.enhanceContrast) {
          finalData = await _applyAdditionalProcessing(
            autoCropResult.croppedImageData,
            options,
          );
        }

        return {
          'processedImageData': finalData,
          'detectedEdges': autoCropResult.corners,
          'metadata': {
            'autoCrop': {
              'applied': true,
              'durationMs': autoCropResult.durationMs,
              'confidence': autoCropResult.confidence,
              'fallbackUsed': autoCropResult.fallbackUsed,
              ...autoCropResult.metadata,
            },
          },
        };
      }

      final processedImageData = await processImage(imageData, options);
      return {
        'processedImageData': processedImageData,
        'detectedEdges': <Offset>[],
        'metadata': {
          'autoCrop': {'applied': false},
        },
      };
    } catch (e) {
      throw ImageProcessingException(
        'Failed to process image with auto-crop: $e',
      );
    }
  }

  /// Apply editing options (rotation, colour filter, crop) to an image.
  Future<Uint8List> applyImageEditing(
    Uint8List imageData,
    ImageEditingOptions editingOptions,
  ) async {
    try {
      img.Image? image = img.decodeImage(imageData);
      if (image == null) {
        throw ImageProcessingException('Failed to decode image data');
      }

      // Rotation (normalised to multiples of 90 degrees)
      final normalizedRotation = editingOptions.rotationDegrees % 360;
      if (normalizedRotation != 0) {
        image = img.copyRotate(image, angle: normalizedRotation);
      }

      // Perspective crop
      if (editingOptions.cropCorners != null &&
          editingOptions.cropCorners!.length == 4) {
        image = await _applyCropWithPerspective(
          image,
          editingOptions.cropCorners!,
          format: editingOptions.documentFormat,
        );
      }

      // Colour filter
      image = _applyColorFilter(image, editingOptions.colorFilter);

      return _encodeImage(image, ImageFormat.jpeg, 0.9);
    } catch (e) {
      throw ImageProcessingException('Failed to apply image editing: $e');
    }
  }

  /// Detect document edges with caching.
  Future<List<Offset>> detectDocumentEdges(Uint8List imageData) async {
    final cacheKey = _generateImageHash(imageData);

    if (_edgeCache.containsKey(cacheKey)) {
      return _edgeCache[cacheKey]!;
    }

    try {
      final job = ImageProcessingJob(
        imageData: imageData,
        options: const DocumentProcessingOptions(autoCorrectPerspective: false),
        detectEdges: true,
        jobId: cacheKey,
      );

      final result = await _isolateService.processImageInBackground(job);

      if (result.error != null || result.detectedEdges == null) {
        final fallback = _getFallbackCorners(imageData);
        _edgeCache[cacheKey] = fallback;
        return fallback;
      }

      _edgeCache[cacheKey] = result.detectedEdges!;
      return result.detectedEdges!;
    } catch (_) {
      final fallback = _getFallbackCorners(imageData);
      _edgeCache[cacheKey] = fallback;
      return fallback;
    }
  }

  /// Analyse image quality and return suggestions.
  Map<String, dynamic> analyzeImageQuality(Uint8List imageData) {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) {
        return {'error': 'Failed to decode image'};
      }

      final isBlurry = _detectBlur(image);
      final brightness = _calculateBrightness(image);
      final contrast = _calculateContrast(image);

      final suggestions = <String>[
        if (isBlurry) 'Image appears blurry - try holding camera steady',
        if (brightness < _brightnessTooLow)
          'Image is too dark - try better lighting',
        if (brightness > _brightnessTooHigh)
          'Image is too bright - reduce lighting or avoid flash',
        if (contrast < _contrastTooLow)
          'Low contrast - ensure good lighting on document',
      ];

      return {
        'width': image.width,
        'height': image.height,
        'aspectRatio': image.width / image.height,
        'isBlurry': isBlurry,
        'brightness': brightness,
        'contrast': contrast,
        'suggestions': suggestions,
      };
    } catch (e) {
      return {'error': 'Failed to analyze image: $e'};
    }
  }

  /// Clear the edge-detection cache.
  void clearEdgeCache() => _edgeCache.clear();

  /// Release resources.
  void dispose() {
    clearEdgeCache();
    _isolateService.dispose();
  }

  // -------------------------------------------------------------------------
  // Colour filters
  // -------------------------------------------------------------------------

  img.Image _applyColorFilter(img.Image image, ColorFilter filter) {
    switch (filter) {
      case ColorFilter.none:
        return image;
      case ColorFilter.highContrast:
        return _applyEnhancedFilter(image);
      case ColorFilter.blackAndWhite:
        return _applyBlackAndWhiteFilter(image);
    }
  }

  /// Black & white filter using Otsu's method for adaptive thresholding.
  img.Image _applyBlackAndWhiteFilter(img.Image image) {
    final histogram = List<int>.filled(256, 0);
    final totalPixels = image.width * image.height;
    final luminanceValues = Float64List(totalPixels);

    // Single pass: compute luminance histogram
    int idx = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final lum = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
        luminanceValues[idx++] = lum;
        histogram[lum.round().clamp(0, 255)]++;
      }
    }

    final threshold = _calculateOtsuThreshold(histogram, totalPixels);

    // Apply threshold
    final result = img.Image(width: image.width, height: image.height);
    idx = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final v = luminanceValues[idx++] > threshold ? 255 : 0;
        result.setPixel(x, y, img.ColorRgb8(v, v, v));
      }
    }
    return result;
  }

  /// Enhanced filter using per-channel histogram equalization with clip limit.
  img.Image _applyEnhancedFilter(img.Image image) {
    const clipLimit = 2.0;

    final histR = List<int>.filled(256, 0);
    final histG = List<int>.filled(256, 0);
    final histB = List<int>.filled(256, 0);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        histR[p.r.toInt()]++;
        histG[p.g.toInt()]++;
        histB[p.b.toInt()]++;
      }
    }

    final totalPixels = image.width * image.height;
    final clipThreshold = (totalPixels * clipLimit / 256).round();

    _clipHistogram(histR, clipThreshold);
    _clipHistogram(histG, clipThreshold);
    _clipHistogram(histB, clipThreshold);

    final lookupR = _buildEqualizationLookup(histR, totalPixels);
    final lookupG = _buildEqualizationLookup(histG, totalPixels);
    final lookupB = _buildEqualizationLookup(histB, totalPixels);

    final result = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        result.setPixel(
          x,
          y,
          img.ColorRgb8(
            lookupR[p.r.toInt()],
            lookupG[p.g.toInt()],
            lookupB[p.b.toInt()],
          ),
        );
      }
    }
    return result;
  }

  // -------------------------------------------------------------------------
  // Histogram helpers
  // -------------------------------------------------------------------------

  int _calculateOtsuThreshold(List<int> histogram, int totalPixels) {
    double sum = 0;
    for (int i = 0; i < 256; i++) {
      sum += i * histogram[i];
    }

    double sumB = 0;
    int weightB = 0;
    double maxVariance = 0;
    int threshold = 0;

    for (int i = 0; i < 256; i++) {
      weightB += histogram[i];
      if (weightB == 0) continue;
      final weightF = totalPixels - weightB;
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

  void _clipHistogram(List<int> histogram, int clipThreshold) {
    int excess = 0;
    for (int i = 0; i < histogram.length; i++) {
      if (histogram[i] > clipThreshold) {
        excess += histogram[i] - clipThreshold;
        histogram[i] = clipThreshold;
      }
    }
    if (excess > 0) {
      final redistribution = excess ~/ histogram.length;
      final remainder = excess % histogram.length;
      for (int i = 0; i < histogram.length; i++) {
        histogram[i] += redistribution;
        if (i < remainder) histogram[i]++;
      }
    }
  }

  List<int> _buildEqualizationLookup(List<int> histogram, int totalPixels) {
    // CDF
    final cdf = List<int>.filled(256, 0);
    cdf[0] = histogram[0];
    for (int i = 1; i < 256; i++) {
      cdf[i] = cdf[i - 1] + histogram[i];
    }

    // Normalise
    final cdfMin = cdf.firstWhere((v) => v > 0);
    final lookup = List<int>.filled(256, 0);
    for (int i = 0; i < 256; i++) {
      lookup[i] =
          (((cdf[i] - cdfMin) / (totalPixels - cdfMin)) * 255).round().clamp(0, 255);
    }
    return lookup;
  }

  // -------------------------------------------------------------------------
  // Perspective / crop
  // -------------------------------------------------------------------------

  Future<img.Image> _applyCropWithPerspective(
    img.Image image,
    List<Offset> corners, {
    DocumentFormat format = DocumentFormat.auto,
  }) async {
    final ui.Codec codec =
        await ui.instantiateImageCodec(img.encodeJpg(image));
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image uiImage = frame.image;

    final outputDimensions = _calculateOutputDimensions(corners, format: format);

    final transformedImage = await _applyPerspectiveTransformation(
      uiImage,
      corners,
      outputDimensions.width.toInt(),
      outputDimensions.height.toInt(),
    );

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.drawImage(transformedImage, Offset.zero, Paint());

    final ui.Picture picture = recorder.endRecording();
    final ui.Image resultImage = await picture.toImage(
      outputDimensions.width.toInt(),
      outputDimensions.height.toInt(),
    );

    final ByteData? byteData =
        await resultImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw ImageProcessingException('Failed to convert transformed image');
    }

    return img.Image.fromBytes(
      width: resultImage.width,
      height: resultImage.height,
      bytes: byteData.buffer,
      format: img.Format.uint8,
      numChannels: 4,
    );
  }

  Future<ui.Image> _applyPerspectiveTransformation(
    ui.Image sourceImage,
    List<Offset> sourceCorners,
    int outputWidth,
    int outputHeight,
  ) async {
    final ByteData? sourceData =
        await sourceImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (sourceData == null) throw Exception('Failed to get source image data');

    final sourcePixels = sourceData.buffer.asUint8List();
    final srcW = sourceImage.width;
    final srcH = sourceImage.height;

    final outputPixels = Uint8List(outputWidth * outputHeight * 4);

    final destCorners = [
      const Offset(0, 0),
      Offset(outputWidth.toDouble(), 0),
      Offset(outputWidth.toDouble(), outputHeight.toDouble()),
      Offset(0, outputHeight.toDouble()),
    ];

    final matrix = _calculatePerspectiveMatrix(destCorners, sourceCorners);

    for (int y = 0; y < outputHeight; y++) {
      for (int x = 0; x < outputWidth; x++) {
        final sp = _transformPoint(
          Offset(x.toDouble(), y.toDouble()),
          matrix,
        );

        final oi = (y * outputWidth + x) * 4;
        if (sp.dx >= 0 && sp.dx < srcW && sp.dy >= 0 && sp.dy < srcH) {
          final color = _bilinearInterpolation(
            sourcePixels,
            srcW,
            srcH,
            sp.dx,
            sp.dy,
          );
          outputPixels[oi] = color[0];
          outputPixels[oi + 1] = color[1];
          outputPixels[oi + 2] = color[2];
          outputPixels[oi + 3] = color[3];
        } else {
          outputPixels[oi] = 255;
          outputPixels[oi + 1] = 255;
          outputPixels[oi + 2] = 255;
          outputPixels[oi + 3] = 255;
        }
      }
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(outputPixels);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: outputWidth,
      height: outputHeight,
      pixelFormat: ui.PixelFormat.rgba8888,
    );

    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  // -------------------------------------------------------------------------
  // Homography
  // -------------------------------------------------------------------------

  List<double> _calculatePerspectiveMatrix(
    List<Offset> source,
    List<Offset> dest,
  ) {
    final s = source;
    final d = dest;

    final A = <List<double>>[
      [s[0].dx, s[0].dy, 1, 0, 0, 0, -s[0].dx * d[0].dx, -s[0].dy * d[0].dx],
      [0, 0, 0, s[0].dx, s[0].dy, 1, -s[0].dx * d[0].dy, -s[0].dy * d[0].dy],
      [s[1].dx, s[1].dy, 1, 0, 0, 0, -s[1].dx * d[1].dx, -s[1].dy * d[1].dx],
      [0, 0, 0, s[1].dx, s[1].dy, 1, -s[1].dx * d[1].dy, -s[1].dy * d[1].dy],
      [s[2].dx, s[2].dy, 1, 0, 0, 0, -s[2].dx * d[2].dx, -s[2].dy * d[2].dx],
      [0, 0, 0, s[2].dx, s[2].dy, 1, -s[2].dx * d[2].dy, -s[2].dy * d[2].dy],
      [s[3].dx, s[3].dy, 1, 0, 0, 0, -s[3].dx * d[3].dx, -s[3].dy * d[3].dx],
      [0, 0, 0, s[3].dx, s[3].dy, 1, -s[3].dx * d[3].dy, -s[3].dy * d[3].dy],
    ];

    final b = <double>[
      d[0].dx, d[0].dy, d[1].dx, d[1].dy,
      d[2].dx, d[2].dy, d[3].dx, d[3].dy,
    ];

    final h = _solveLinearSystem(A, b);
    return [h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7], 1.0];
  }

  /// Gaussian elimination with partial pivoting.
  List<double> _solveLinearSystem(List<List<double>> A, List<double> b) {
    final n = A.length;
    final aug = [
      for (int i = 0; i < n; i++) [...A[i], b[i]],
    ];

    for (int i = 0; i < n; i++) {
      int maxRow = i;
      for (int k = i + 1; k < n; k++) {
        if (aug[k][i].abs() > aug[maxRow][i].abs()) maxRow = k;
      }
      if (maxRow != i) {
        final tmp = aug[i];
        aug[i] = aug[maxRow];
        aug[maxRow] = tmp;
      }
      for (int k = i + 1; k < n; k++) {
        if (aug[i][i] != 0) {
          final factor = aug[k][i] / aug[i][i];
          for (int j = i; j < n + 1; j++) {
            aug[k][j] -= factor * aug[i][j];
          }
        }
      }
    }

    final x = List<double>.filled(n, 0.0);
    for (int i = n - 1; i >= 0; i--) {
      x[i] = aug[i][n];
      for (int j = i + 1; j < n; j++) {
        x[i] -= aug[i][j] * x[j];
      }
      if (aug[i][i] != 0) x[i] /= aug[i][i];
    }
    return x;
  }

  Offset _transformPoint(Offset point, List<double> m) {
    final x = point.dx, y = point.dy;
    final w = m[6] * x + m[7] * y + m[8];
    if (w == 0) return point;
    return Offset(
      (m[0] * x + m[1] * y + m[2]) / w,
      (m[3] * x + m[4] * y + m[5]) / w,
    );
  }

  // -------------------------------------------------------------------------
  // Bilinear interpolation
  // -------------------------------------------------------------------------

  List<int> _bilinearInterpolation(
    Uint8List pixels,
    int width,
    int height,
    double x,
    double y,
  ) {
    final x1 = x.floor().clamp(0, width - 1);
    final y1 = y.floor().clamp(0, height - 1);
    final x2 = (x1 + 1).clamp(0, width - 1);
    final y2 = (y1 + 1).clamp(0, height - 1);

    final dx = x - x1;
    final dy = y - y1;

    List<int> px(int px, int py) {
      final i = (py * width + px) * 4;
      return [pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3]];
    }

    final p1 = px(x1, y1), p2 = px(x2, y1);
    final p3 = px(x1, y2), p4 = px(x2, y2);

    return [
      for (int c = 0; c < 4; c++)
        ((p1[c] * (1 - dx) + p2[c] * dx) * (1 - dy) +
                (p3[c] * (1 - dx) + p4[c] * dx) * dy)
            .round(),
    ];
  }

  // -------------------------------------------------------------------------
  // Output dimensions
  // -------------------------------------------------------------------------

  Size _calculateOutputDimensions(
    List<Offset> corners, {
    DocumentFormat? format,
    int rotation = 0,
  }) {
    if (corners.length != 4) return _defaultFallbackSize;

    final topWidth = (corners[1] - corners[0]).distance;
    final bottomWidth = (corners[2] - corners[3]).distance;
    final leftHeight = (corners[3] - corners[0]).distance;
    final rightHeight = (corners[2] - corners[1]).distance;

    final maxW = math.max(topWidth, bottomWidth).ceilToDouble();
    final maxH = math.max(leftHeight, rightHeight).ceilToDouble();

    if (format == null || format == DocumentFormat.auto) {
      return Size(
        math.max(maxW, _minOutputDimension),
        math.max(maxH, _minOutputDimension),
      );
    }

    return _applyDocumentFormatRatio(maxW, maxH, format, rotation);
  }

  Size _applyDocumentFormatRatio(
    double maxW,
    double maxH,
    DocumentFormat format,
    int rotation,
  ) {
    final baseAR = _getDocumentFormatAspectRatio(format);
    final detectedIsLandscape = maxW > maxH;
    final rotationIsLandscape = (rotation % 180) == 90;
    final finalIsLandscape = detectedIsLandscape != rotationIsLandscape;
    final ar = finalIsLandscape ? (1.0 / baseAR) : baseAR;

    double outW, outH;
    if (ar >= 1.0) {
      outW = maxW;
      outH = maxW / ar;
      if (outH > maxH) {
        outH = maxH;
        outW = maxH * ar;
      }
    } else {
      outH = maxH;
      outW = maxH * ar;
      if (outW > maxW) {
        outW = maxW;
        outH = maxW / ar;
      }
    }

    return Size(
      math.max(outW, _minOutputDimension),
      math.max(outH, _minOutputDimension),
    );
  }

  double _getDocumentFormatAspectRatio(DocumentFormat format) {
    switch (format) {
      case DocumentFormat.isoA:
        return 1.0 / math.sqrt2; // 1/sqrt(2) ~ 0.707
      case DocumentFormat.usLetter:
        return 8.5 / 11.0;
      case DocumentFormat.usLegal:
        return 8.5 / 14.0;
      case DocumentFormat.square:
        return 1.0;
      case DocumentFormat.receipt:
        return 0.6;
      case DocumentFormat.businessCard:
        return 3.5 / 2.0;
      case DocumentFormat.auto:
        return 1.0;
    }
  }

  // -------------------------------------------------------------------------
  // Quality analysis helpers
  // -------------------------------------------------------------------------

  bool _detectBlur(img.Image image) {
    final grayscale = img.grayscale(image);
    final laplacian = img.sobel(grayscale);

    double sum = 0, sumSq = 0;
    int count = 0;
    for (int y = 0; y < laplacian.height; y++) {
      for (int x = 0; x < laplacian.width; x++) {
        final v = img.getLuminance(laplacian.getPixel(x, y));
        sum += v;
        sumSq += v * v;
        count++;
      }
    }

    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    return variance < _blurVarianceThreshold;
  }

  double _calculateBrightness(img.Image image) {
    double sum = 0;
    int count = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        sum += img.getLuminance(image.getPixel(x, y));
        count++;
      }
    }
    return (sum / count) / 255.0;
  }

  double _calculateContrast(img.Image image) {
    double lo = 255.0, hi = 0.0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final lum = img.getLuminance(image.getPixel(x, y)).toDouble();
        if (lum < lo) lo = lum;
        if (lum > hi) hi = lum;
      }
    }
    return (hi - lo) / 255.0;
  }

  // -------------------------------------------------------------------------
  // Misc helpers
  // -------------------------------------------------------------------------

  Future<Uint8List> _applyAdditionalProcessing(
    Uint8List imageData,
    DocumentProcessingOptions options,
  ) async {
    img.Image? image = img.decodeImage(imageData);
    if (image == null) {
      throw ImageProcessingException('Failed to decode image data');
    }
    if (options.convertToGrayscale) image = img.grayscale(image);
    if (options.enhanceContrast) {
      image = img.adjustColor(image, contrast: _contrastMultiplier);
    }
    return _encodeImage(image, options.outputFormat, options.compressionQuality);
  }

  Uint8List _encodeImage(img.Image image, ImageFormat format, double quality) {
    switch (format) {
      case ImageFormat.jpeg:
      case ImageFormat.webp:
        return Uint8List.fromList(
          img.encodeJpg(image, quality: (quality * 100).round()),
        );
      case ImageFormat.png:
        return Uint8List.fromList(img.encodePng(image));
    }
  }

  List<Offset> _getFallbackCorners(Uint8List imageData) {
    final image = img.decodeImage(imageData);
    if (image == null) {
      return const [Offset(0, 0), Offset(100, 0), Offset(100, 100), Offset(0, 100)];
    }
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    return [Offset(0, 0), Offset(w, 0), Offset(w, h), Offset(0, h)];
  }

  String _generateJobId() {
    return '${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(10000)}';
  }

  String _generateImageHash(Uint8List data) {
    if (data.isEmpty) return 'empty';
    final size = data.length;
    final n = math.min(_hashSampleBytes, size);
    final first = data.sublist(0, n);
    final last = data.sublist(math.max(0, size - n));
    return '${size}_${first.join(',')}_${last.join(',')}';
  }
}

/// Exception thrown when image processing fails.
class ImageProcessingException implements Exception {
  final String message;
  const ImageProcessingException(this.message);

  @override
  String toString() => 'ImageProcessingException: $message';
}
