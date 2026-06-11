import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import '../models/scanned_document.dart';
import 'auto_cropper.dart';

/// Data transfer object for image processing jobs.
class ImageProcessingJob {
  final Uint8List imageData;
  final DocumentProcessingOptions options;
  final bool detectEdges;
  final String? jobId;

  const ImageProcessingJob({
    required this.imageData,
    required this.options,
    this.detectEdges = true,
    this.jobId,
  });

  Map<String, dynamic> toMap() {
    return {
      'imageData': imageData,
      'options': options.toJson(),
      'detectEdges': detectEdges,
      'jobId': jobId,
    };
  }

  factory ImageProcessingJob.fromMap(Map<String, dynamic> map) {
    return ImageProcessingJob(
      imageData: map['imageData'],
      options: DocumentProcessingOptions.fromJson(map['options']),
      detectEdges: map['detectEdges'] ?? true,
      jobId: map['jobId'],
    );
  }
}

/// Result of an image processing job.
class ImageProcessingResult {
  final Uint8List? processedImageData;
  final List<Offset>? detectedEdges;
  final String? error;
  final String? jobId;
  final Map<String, dynamic>? metadata;

  const ImageProcessingResult({
    this.processedImageData,
    this.detectedEdges,
    this.error,
    this.jobId,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'processedImageData': processedImageData,
      'detectedEdges': detectedEdges
          ?.map((offset) => {'dx': offset.dx, 'dy': offset.dy})
          .toList(),
      'error': error,
      'jobId': jobId,
      'metadata': metadata,
    };
  }

  factory ImageProcessingResult.fromMap(Map<String, dynamic> map) {
    final detectedEdgesList = map['detectedEdges'] as List?;
    final detectedEdges = detectedEdgesList?.map((item) {
      return Offset(item['dx'].toDouble(), item['dy'].toDouble());
    }).toList();

    return ImageProcessingResult(
      processedImageData: map['processedImageData'],
      detectedEdges: detectedEdges,
      error: map['error'],
      jobId: map['jobId'],
      metadata: map['metadata'],
    );
  }
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Maximum long-edge dimension for edge-detection downscaling.
const int _edgeDetectionMaxDimension = 800;

/// Maximum long-edge dimension for the "size" PDF resolution.
const int _sizeResolutionMaxDimension = 1200;

/// Padding added around the detected bounding box (pixels).
const int _boundingBoxPadding = 10;

/// Luminance threshold for classifying an edge pixel.
const int _edgePixelThreshold = 128;

/// Contrast multiplier applied when [enhanceContrast] is true.
const double _contrastMultiplier = 1.2;

/// Fraction of the mean gradient magnitude used as adaptive threshold.
const double _adaptiveThresholdFraction = 0.5;

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Service for processing images with auto-crop, colour filters, and resizing.
///
/// Heavy work (decode / detect / warp / encode) runs in a background isolate
/// via `compute`, using the DTO round-trip ([ImageProcessingJob.toMap] /
/// [ImageProcessingResult.fromMap]) to ferry data across the isolate boundary.
class ImageProcessingIsolateService {
  static final ImageProcessingIsolateService _instance =
      ImageProcessingIsolateService._internal();
  factory ImageProcessingIsolateService() => _instance;
  ImageProcessingIsolateService._internal();

  final AutoCropper _autoCropper = AutoCropper();

  /// Process an image according to the supplied [job], off the UI thread.
  Future<ImageProcessingResult> processImageInBackground(
    ImageProcessingJob job,
  ) async {
    try {
      final map = await compute(_runImageJobInIsolate, job.toMap());
      return ImageProcessingResult.fromMap(map);
    } catch (e) {
      return ImageProcessingResult(
        error: 'Processing failed: $e',
        jobId: job.jobId,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Core pipeline
  // -------------------------------------------------------------------------

  Future<ImageProcessingResult> _processImage(ImageProcessingJob job) async {
    final img.Image? decoded = img.decodeImage(job.imageData);
    if (decoded == null) {
      return ImageProcessingResult(
        error: 'Failed to decode image data',
        jobId: job.jobId,
      );
    }

    img.Image image = decoded;
    final metadata = <String, dynamic>{
      'originalWidth': image.width,
      'originalHeight': image.height,
      'processedAt': DateTime.now().toIso8601String(),
    };

    List<Offset>? detectedEdges;
    Uint8List processedImageData;

    if (job.options.autoCorrectPerspective && job.detectEdges) {
      try {
        final autoCropResult = await _autoCropper.autoCrop(job.imageData);

        Uint8List finalData = autoCropResult.croppedImageData;
        if (job.options.convertToGrayscale || job.options.enhanceContrast) {
          finalData = await _applyAdditionalProcessing(finalData, job.options);
        }

        processedImageData = finalData;
        detectedEdges = autoCropResult.corners;
        metadata['perspectiveCorrected'] = true;
        metadata['autoCrop'] = {
          'applied': true,
          'durationMs': autoCropResult.durationMs,
          'confidence': autoCropResult.confidence,
          'fallbackUsed': autoCropResult.fallbackUsed,
          ...autoCropResult.metadata,
        };
      } catch (_) {
        // Fallback to legacy bounding-box method
        detectedEdges = await _detectDocumentEdges(job.imageData);
        if (detectedEdges.isNotEmpty) {
          image = await _applyBoundingBoxCrop(image, detectedEdges);
          metadata['perspectiveCorrected'] = true;
          metadata['autoCrop'] = {
            'applied': false,
            'fallback': 'legacy_method',
          };
        } else {
          metadata['autoCrop'] = {'applied': false, 'fallback': 'no_edges'};
        }

        image = _applyColorFilters(image, job.options);
        image = _applyResolution(image, job.options.pdfResolution);
        processedImageData = _encodeImage(
          image,
          job.options.outputFormat,
          job.options.compressionQuality,
        );
      }
    } else {
      detectedEdges = <Offset>[];
      metadata['autoCrop'] = {'applied': false};

      image = _applyColorFilters(image, job.options);
      image = _applyResolution(image, job.options.pdfResolution);
      processedImageData = _encodeImage(
        image,
        job.options.outputFormat,
        job.options.compressionQuality,
      );
    }

    metadata['processedWidth'] = image.width;
    metadata['processedHeight'] = image.height;
    metadata['outputFormat'] = job.options.outputFormat.toString();

    return ImageProcessingResult(
      processedImageData: processedImageData,
      detectedEdges: detectedEdges,
      jobId: job.jobId,
      metadata: metadata,
    );
  }

  // -------------------------------------------------------------------------
  // Processing steps
  // -------------------------------------------------------------------------

  Future<Uint8List> _applyAdditionalProcessing(
    Uint8List imageData,
    DocumentProcessingOptions options,
  ) async {
    img.Image? image = img.decodeImage(imageData);
    if (image == null) throw Exception('Failed to decode image data');

    if (options.convertToGrayscale) {
      image = img.grayscale(image);
    }
    if (options.enhanceContrast) {
      image = img.adjustColor(image, contrast: _contrastMultiplier);
    }

    image = _applyResolution(image, options.pdfResolution);
    return _encodeImage(
      image,
      options.outputFormat,
      options.compressionQuality,
    );
  }

  Future<List<Offset>> _detectDocumentEdges(Uint8List imageData) async {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) return [];

      final maxDimension = math.max(image.width, image.height);
      final downscaleRatio = maxDimension > _edgeDetectionMaxDimension
          ? _edgeDetectionMaxDimension / maxDimension
          : 1.0;

      img.Image workingImage = image;
      if (downscaleRatio < 1.0) {
        workingImage = img.copyResize(
          image,
          width: (image.width * downscaleRatio).round(),
          height: (image.height * downscaleRatio).round(),
        );
      }

      final grayscale = img.grayscale(workingImage);
      final blurred = img.gaussianBlur(grayscale, radius: 2);
      final edges = _edgeDetection(blurred);
      final corners = _findLargestQuadrilateral(
        edges,
        workingImage.width,
        workingImage.height,
      );

      if (downscaleRatio < 1.0) {
        final scale = 1.0 / downscaleRatio;
        return corners.map((c) => Offset(c.dx * scale, c.dy * scale)).toList();
      }

      return _orderCorners(corners);
    } catch (_) {
      return [];
    }
  }

  img.Image _edgeDetection(img.Image image) {
    final sobelX = img.sobel(image);
    final sobelY = img.sobel(image);

    // First pass: compute mean gradient magnitude for adaptive threshold
    double sumMagnitude = 0;
    final pixelCount = image.width * image.height;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final gx = img.getLuminance(sobelX.getPixel(x, y));
        final gy = img.getLuminance(sobelY.getPixel(x, y));
        sumMagnitude += math.sqrt(gx * gx + gy * gy);
      }
    }

    final adaptiveThreshold =
        (sumMagnitude / pixelCount) * _adaptiveThresholdFraction;

    // Second pass: threshold
    final edges = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final gx = img.getLuminance(sobelX.getPixel(x, y));
        final gy = img.getLuminance(sobelY.getPixel(x, y));
        final magnitude = math.sqrt(gx * gx + gy * gy);
        final v = magnitude > adaptiveThreshold ? 255 : 0;
        edges.setPixel(x, y, img.ColorRgb8(v, v, v));
      }
    }
    return edges;
  }

  List<Offset> _findLargestQuadrilateral(
    img.Image edges,
    int width,
    int height,
  ) {
    int minX = width, minY = height, maxX = 0, maxY = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (img.getLuminance(edges.getPixel(x, y)) > _edgePixelThreshold) {
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }

    minX = (minX - _boundingBoxPadding).clamp(0, width - 1);
    minY = (minY - _boundingBoxPadding).clamp(0, height - 1);
    maxX = (maxX + _boundingBoxPadding).clamp(0, width - 1);
    maxY = (maxY + _boundingBoxPadding).clamp(0, height - 1);

    return [
      Offset(minX.toDouble(), minY.toDouble()),
      Offset(maxX.toDouble(), minY.toDouble()),
      Offset(maxX.toDouble(), maxY.toDouble()),
      Offset(minX.toDouble(), maxY.toDouble()),
    ];
  }

  List<Offset> _orderCorners(List<Offset> corners) {
    if (corners.length != 4) return corners;

    final centerX = corners.map((c) => c.dx).reduce((a, b) => a + b) / 4;
    final centerY = corners.map((c) => c.dy).reduce((a, b) => a + b) / 4;

    final sorted = List<Offset>.from(corners)
      ..sort((a, b) {
        final angleA = math.atan2(a.dy - centerY, a.dx - centerX);
        final angleB = math.atan2(b.dy - centerY, b.dx - centerX);
        return angleA.compareTo(angleB);
      });

    int topLeftIndex = 0;
    double minSum = sorted[0].dx + sorted[0].dy;
    for (int i = 1; i < 4; i++) {
      final sum = sorted[i].dx + sorted[i].dy;
      if (sum < minSum) {
        minSum = sum;
        topLeftIndex = i;
      }
    }

    return [for (int i = 0; i < 4; i++) sorted[(topLeftIndex + i) % 4]];
  }

  Future<img.Image> _applyBoundingBoxCrop(
    img.Image image,
    List<Offset> corners,
  ) async {
    int minX = image.width, minY = image.height, maxX = 0, maxY = 0;

    for (final corner in corners) {
      if (corner.dx.floor() < minX) minX = corner.dx.floor();
      if (corner.dy.floor() < minY) minY = corner.dy.floor();
      if (corner.dx.ceil() > maxX) maxX = corner.dx.ceil();
      if (corner.dy.ceil() > maxY) maxY = corner.dy.ceil();
    }

    minX = minX.clamp(0, image.width - 1);
    minY = minY.clamp(0, image.height - 1);
    maxX = maxX.clamp(0, image.width - 1);
    maxY = maxY.clamp(0, image.height - 1);

    final w = maxX - minX;
    final h = maxY - minY;
    if (w <= 0 || h <= 0) return image;

    return img.copyCrop(image, x: minX, y: minY, width: w, height: h);
  }

  img.Image _applyColorFilters(
    img.Image image,
    DocumentProcessingOptions options,
  ) {
    img.Image result = image;
    if (options.convertToGrayscale) {
      result = img.grayscale(result);
    }
    if (options.enhanceContrast) {
      result = img.adjustColor(result, contrast: _contrastMultiplier);
    }
    return result;
  }

  img.Image _applyResolution(img.Image image, PdfResolution resolution) {
    if (resolution != PdfResolution.size) return image;

    final maxDimension = math.max(image.width, image.height);
    if (maxDimension <= _sizeResolutionMaxDimension) return image;

    final scale = _sizeResolutionMaxDimension / maxDimension;
    return img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
    );
  }

  Uint8List _encodeImage(img.Image image, ImageFormat format, double quality) {
    switch (format) {
      case ImageFormat.jpeg:
      case ImageFormat.webp: // WebP not reliably available; fall back to JPEG
        return img.encodeJpg(image, quality: (quality * 100).round());
      case ImageFormat.png:
        return img.encodePng(image);
    }
  }

  /// Clean up resources.
  void dispose() {
    // Reserved for future isolate cleanup.
  }
}

/// Top-level entry point for `compute`: run an image-processing job in a
/// background isolate. Receives [ImageProcessingJob.toMap] and returns
/// [ImageProcessingResult.toMap].
Future<Map<String, dynamic>> _runImageJobInIsolate(
  Map<String, dynamic> jobMap,
) async {
  final job = ImageProcessingJob.fromMap(jobMap);
  // Singleton is isolate-local; safe to construct here.
  final result = await ImageProcessingIsolateService()._processImage(job);
  return result.toMap();
}
