import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Result of auto-crop operation
class AutoCropResult {
  final Uint8List croppedImageData;
  final List<Offset> corners;
  final int durationMs;
  final double confidence;
  final bool fallbackUsed;
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

/// Auto-crop service that implements Canny→dilate→largest contour→warp pipeline
class AutoCropper {
  static const int _maxProcessingDimension = 800;
  static const int _minContourArea = 10000;
  static const double _minConfidence = 0.3;
  static const int _maxProcessingTimeMs = 100;

  /// Perform auto-crop on the given image data
  /// 
  /// Returns [AutoCropResult] with cropped image, detected corners, and metadata.
  /// Falls back to bounding box crop if confidence is low or processing takes too long.
  Future<AutoCropResult> autoCrop(Uint8List imageData) async {
    final stopwatch = Stopwatch()..start();
    final metadata = <String, dynamic>{};

    try {
      // Decode original image
      final originalImage = img.decodeImage(imageData);
      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }

      metadata['originalWidth'] = originalImage.width;
      metadata['originalHeight'] = originalImage.height;

      // Downscale for processing
      final processingResult = _prepareProcessingImage(originalImage);
      final workingImage = processingResult.image;
      final scale = processingResult.scale;

      // Run the detection pipeline
      final detectionResult = await _runDetectionPipeline(workingImage, stopwatch);
      
      if (stopwatch.elapsedMilliseconds > _maxProcessingTimeMs) {
        return _createBoundingBoxFallback(originalImage, stopwatch, metadata, 'timeout');
      }

      if (detectionResult.confidence < _minConfidence) {
        return _createBoundingBoxFallback(originalImage, stopwatch, metadata, 'low_confidence');
      }

      // Scale corners back to original image dimensions
      final originalCorners = detectionResult.corners.map((corner) => 
        Offset(corner.dx * scale, corner.dy * scale)
      ).toList();

      // Apply perspective transform
      final croppedImage = await _applyPerspectiveTransform(originalImage, originalCorners);

      final duration = stopwatch.elapsedMilliseconds;
      metadata['detectionTimeMs'] = duration;
      metadata['detectionMethod'] = 'contour_warp';
      metadata['contourArea'] = detectionResult.contourArea;

      return AutoCropResult(
        croppedImageData: Uint8List.fromList(img.encodeJpg(croppedImage, quality: 95)),
        corners: originalCorners,
        durationMs: duration,
        confidence: detectionResult.confidence,
        fallbackUsed: false,
        metadata: metadata,
      );

    } catch (e) {
      // Fallback to bounding box on any error
      final originalImage = img.decodeImage(imageData);
      if (originalImage != null) {
        return _createBoundingBoxFallback(originalImage, stopwatch, metadata, 'error: $e');
      }
      rethrow;
    }
  }

  /// Prepare downscaled image for processing
  _ProcessingImage _prepareProcessingImage(img.Image originalImage) {
    final maxDimension = math.max(originalImage.width, originalImage.height);
    final scale = maxDimension > _maxProcessingDimension 
        ? _maxProcessingDimension / maxDimension 
        : 1.0;

    if (scale < 1.0) {
      final newWidth = (originalImage.width * scale).round();
      final newHeight = (originalImage.height * scale).round();
      final resizedImage = img.copyResize(originalImage, width: newWidth, height: newHeight);
      return _ProcessingImage(resizedImage, 1.0 / scale);
    }

    return _ProcessingImage(originalImage, 1.0);
  }

  /// Run the complete detection pipeline
  Future<_DetectionResult> _runDetectionPipeline(img.Image image, Stopwatch stopwatch) async {
    // Convert to grayscale
    final grayscale = img.grayscale(image);

    // Apply Gaussian blur to reduce noise
    final blurred = img.gaussianBlur(grayscale, radius: 2);

    // Canny edge detection
    final edges = _cannyEdgeDetection(blurred);

    // Morphological dilation to connect edge fragments
    final dilated = _morphologicalDilation(edges);

    // Find contours and extract largest quadrilateral
    final contourResult = _findLargestContour(dilated, image.width, image.height);

    return contourResult;
  }

  /// Canny edge detection implementation
  img.Image _cannyEdgeDetection(img.Image image) {
    // Apply Sobel operators
    final sobelX = _sobelX(image);
    final sobelY = _sobelY(image);
    
    // Calculate gradient magnitude and direction
    final magnitude = img.Image(width: image.width, height: image.height);
    final direction = List<List<double>>.filled(
      image.height, 
      List<double>.filled(image.width, 0.0)
    );
    
    double maxMagnitude = 0.0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final gx = img.getLuminance(sobelX.getPixel(x, y));
        final gy = img.getLuminance(sobelY.getPixel(x, y));
        final mag = math.sqrt(gx * gx + gy * gy);
        final angle = math.atan2(gy, gx);
        
        magnitude.setPixel(x, y, img.ColorRgb8(mag.round(), mag.round(), mag.round()));
        direction[y][x] = angle;
        maxMagnitude = math.max(maxMagnitude, mag);
      }
    }
    
    // Non-maximum suppression
    final suppressed = _nonMaximumSuppression(magnitude, direction);
    
    // Hysteresis thresholding
    final highThreshold = maxMagnitude * 0.15;
    final lowThreshold = highThreshold * 0.5;
    
    return _hysteresisThresholding(suppressed, lowThreshold, highThreshold);
  }

  /// Sobel X operator
  img.Image _sobelX(img.Image image) {
    final kernel = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1],
    ];
    return _convolution(image, kernel);
  }

  /// Sobel Y operator
  img.Image _sobelY(img.Image image) {
    final kernel = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1],
    ];
    return _convolution(image, kernel);
  }

  /// Apply convolution kernel to image
  img.Image _convolution(img.Image image, List<List<int>> kernel) {
    final result = img.Image(width: image.width, height: image.height);
    final kernelSize = kernel.length;
    final offset = kernelSize ~/ 2;
    
    for (int y = offset; y < image.height - offset; y++) {
      for (int x = offset; x < image.width - offset; x++) {
        double sum = 0.0;
        
        for (int ky = 0; ky < kernelSize; ky++) {
          for (int kx = 0; kx < kernelSize; kx++) {
            final pixel = img.getLuminance(image.getPixel(
              x + kx - offset, 
              y + ky - offset
            ));
            sum += pixel * kernel[ky][kx];
          }
        }
        
        final value = sum.abs().clamp(0, 255).round();
        result.setPixel(x, y, img.ColorRgb8(value, value, value));
      }
    }
    
    return result;
  }

  /// Non-maximum suppression
  img.Image _nonMaximumSuppression(img.Image magnitude, List<List<double>> direction) {
    final result = img.Image(width: magnitude.width, height: magnitude.height);
    
    for (int y = 1; y < magnitude.height - 1; y++) {
      for (int x = 1; x < magnitude.width - 1; x++) {
        final angle = direction[y][x];
        final currentMag = img.getLuminance(magnitude.getPixel(x, y));
        
        // Quantize angle to 4 directions
        double q = 255, r = 255;
        
        if ((angle >= -math.pi/8 && angle < math.pi/8) || 
            (angle >= 7*math.pi/8 || angle < -7*math.pi/8)) {
          // Horizontal edge
          q = img.getLuminance(magnitude.getPixel(x + 1, y)).toDouble();
          r = img.getLuminance(magnitude.getPixel(x - 1, y)).toDouble();
        } else if ((angle >= math.pi/8 && angle < 3*math.pi/8) || 
                   (angle >= -7*math.pi/8 && angle < -5*math.pi/8)) {
          // 45-degree edge
          q = img.getLuminance(magnitude.getPixel(x + 1, y + 1)).toDouble();
          r = img.getLuminance(magnitude.getPixel(x - 1, y - 1)).toDouble();
        } else if ((angle >= 3*math.pi/8 && angle < 5*math.pi/8) || 
                   (angle >= -5*math.pi/8 && angle < -3*math.pi/8)) {
          // Vertical edge
          q = img.getLuminance(magnitude.getPixel(x, y + 1)).toDouble();
          r = img.getLuminance(magnitude.getPixel(x, y - 1)).toDouble();
        } else if ((angle >= 5*math.pi/8 && angle < 7*math.pi/8) || 
                   (angle >= -3*math.pi/8 && angle < -math.pi/8)) {
          // 135-degree edge
          q = img.getLuminance(magnitude.getPixel(x + 1, y - 1)).toDouble();
          r = img.getLuminance(magnitude.getPixel(x - 1, y + 1)).toDouble();
        }
        
        final value = (currentMag >= q && currentMag >= r) ? currentMag.round() : 0;
        result.setPixel(x, y, img.ColorRgb8(value, value, value));
      }
    }
    
    return result;
  }

  /// Hysteresis thresholding
  img.Image _hysteresisThresholding(img.Image image, double lowThreshold, double highThreshold) {
    final result = img.Image(width: image.width, height: image.height);
    final visited = List<List<bool>>.filled(
      image.height, 
      List<bool>.filled(image.width, false)
    );
    
    // First pass: mark strong edges
    final strongEdges = <Point>[];
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final value = img.getLuminance(image.getPixel(x, y));
        if (value >= highThreshold) {
          strongEdges.add(Point(x, y));
        }
      }
    }
    
    // Second pass: trace edges from strong pixels
    for (final point in strongEdges) {
      _traceEdge(image, result, visited, point.x, point.y, lowThreshold);
    }
    
    return result;
  }

  /// Trace edge from a starting point
  void _traceEdge(img.Image image, img.Image result, List<List<bool>> visited, 
                  int x, int y, double lowThreshold) {
    if (x < 0 || x >= image.width || y < 0 || y >= image.height || visited[y][x]) {
      return;
    }
    
    visited[y][x] = true;
    final value = img.getLuminance(image.getPixel(x, y));
    
    if (value >= lowThreshold) {
      result.setPixel(x, y, img.ColorRgb8(255, 255, 255));
      
      // Check 8-connected neighbors
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          _traceEdge(image, result, visited, x + dx, y + dy, lowThreshold);
        }
      }
    }
  }

  /// Morphological dilation to connect edge fragments
  img.Image _morphologicalDilation(img.Image image) {
    final kernel = [
      [1, 1, 1],
      [1, 1, 1],
      [1, 1, 1],
    ];
    final convolved = _convolution(image, kernel);
    final result = img.Image(width: image.width, height: image.height);
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = convolved.getPixel(x, y);
        final value = pixel.r > 128 ? 255 : 0;
        result.setPixel(x, y, img.ColorRgb8(value, value, value));
      }
    }
    
    return result;
  }

  /// Find largest contour and extract quadrilateral
  _DetectionResult _findLargestContour(img.Image image, int width, int height) {
    final contours = _findContours(image);
    
    if (contours.isEmpty) {
      return _DetectionResult([], 0.0, 0.0);
    }
    
    // Find largest contour by area
    var largestContour = contours.first;
    var maxArea = _calculateContourArea(largestContour);
    
    for (final contour in contours.skip(1)) {
      final area = _calculateContourArea(contour);
      if (area > maxArea) {
        maxArea = area;
        largestContour = contour;
      }
    }
    
    if (maxArea < _minContourArea) {
      return _DetectionResult([], 0.0, maxArea);
    }
    
    // Approximate contour to quadrilateral
    final corners = _approximateContourToQuad(largestContour, width, height);
    final confidence = _calculateConfidence(corners, maxArea, (width * height).toDouble());
    
    return _DetectionResult(corners, confidence, maxArea);
  }

  /// Find contours in binary image
  List<List<Point>> _findContours(img.Image image) {
    final contours = <List<Point>>[];
    final visited = List<List<bool>>.filled(
      image.height, 
      List<bool>.filled(image.width, false)
    );
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = img.getLuminance(image.getPixel(x, y));
        if (pixel > 128 && !visited[y][x]) {
          final contour = _traceContour(image, visited, x, y);
          if (contour.length > 10) { // Filter small contours
            contours.add(contour);
          }
        }
      }
    }
    
    return contours;
  }

  /// Trace a single contour
  List<Point> _traceContour(img.Image image, List<List<bool>> visited, int startX, int startY) {
    final contour = <Point>[];
    final stack = <Point>[Point(startX, startY)];
    
    while (stack.isNotEmpty) {
      final point = stack.removeLast();
      final x = point.x;
      final y = point.y;
      
      if (x < 0 || x >= image.width || y < 0 || y >= image.height || visited[y][x]) {
        continue;
      }
      
      final pixel = img.getLuminance(image.getPixel(x, y));
      if (pixel <= 128) {
        continue;
      }
      
      visited[y][x] = true;
      contour.add(point);
      
      // Add 8-connected neighbors
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          stack.add(Point(x + dx, y + dy));
        }
      }
    }
    
    return contour;
  }

  /// Calculate contour area using shoelace formula
  double _calculateContourArea(List<Point> contour) {
    if (contour.length < 3) return 0.0;
    
    double area = 0.0;
    for (int i = 0; i < contour.length; i++) {
      final p1 = contour[i];
      final p2 = contour[(i + 1) % contour.length];
      area += (p1.x * p2.y - p2.x * p1.y);
    }
    
    return area.abs() / 2.0;
  }

  /// Approximate contour to quadrilateral using Douglas-Peucker algorithm
  List<Offset> _approximateContourToQuad(List<Point> contour, int width, int height) {
    if (contour.length <= 4) {
      return contour.map((p) => Offset(p.x.toDouble(), p.y.toDouble())).toList();
    }
    
    // Simplified approximation: find extreme points
    double minX = width.toDouble(), minY = height.toDouble();
    double maxX = 0.0, maxY = 0.0;
    
    for (final point in contour) {
      minX = math.min(minX, point.x.toDouble());
      minY = math.min(minY, point.y.toDouble());
      maxX = math.max(maxX, point.x.toDouble());
      maxY = math.max(maxY, point.y.toDouble());
    }
    
    // Find corners more precisely
    final corners = <Offset>[];
    const margin = 0.1; // 10% margin from edges
    
    // Top-left corner
    Point? topLeft;
    double minDist = double.infinity;
    for (final point in contour) {
      final dist = math.sqrt(
        math.pow(point.x - minX, 2) + math.pow(point.y - minY, 2)
      );
      if (dist < minDist && 
          point.x < minX + (maxX - minX) * margin && 
          point.y < minY + (maxY - minY) * margin) {
        minDist = dist;
        topLeft = point;
      }
    }
    if (topLeft != null) corners.add(Offset(topLeft.x.toDouble(), topLeft.y.toDouble()));
    
    // Top-right corner
    Point? topRight;
    minDist = double.infinity;
    for (final point in contour) {
      final dist = math.sqrt(
        math.pow(point.x - maxX, 2) + math.pow(point.y - minY, 2)
      );
      if (dist < minDist && 
          point.x > maxX - (maxX - minX) * margin && 
          point.y < minY + (maxY - minY) * margin) {
        minDist = dist;
        topRight = point;
      }
    }
    if (topRight != null) corners.add(Offset(topRight.x.toDouble(), topRight.y.toDouble()));
    
    // Bottom-right corner
    Point? bottomRight;
    minDist = double.infinity;
    for (final point in contour) {
      final dist = math.sqrt(
        math.pow(point.x - maxX, 2) + math.pow(point.y - maxY, 2)
      );
      if (dist < minDist && 
          point.x > maxX - (maxX - minX) * margin && 
          point.y > maxY - (maxY - minY) * margin) {
        minDist = dist;
        bottomRight = point;
      }
    }
    if (bottomRight != null) corners.add(Offset(bottomRight.x.toDouble(), bottomRight.y.toDouble()));
    
    // Bottom-left corner
    Point? bottomLeft;
    minDist = double.infinity;
    for (final point in contour) {
      final dist = math.sqrt(
        math.pow(point.x - minX, 2) + math.pow(point.y - maxY, 2)
      );
      if (dist < minDist && 
          point.x < minX + (maxX - minX) * margin && 
          point.y > maxY - (maxY - minY) * margin) {
        minDist = dist;
        bottomLeft = point;
      }
    }
    if (bottomLeft != null) corners.add(Offset(bottomLeft.x.toDouble(), bottomLeft.y.toDouble()));
    
    return corners.length == 4 ? _orderCorners(corners) : [];
  }

  /// Order corners in clockwise direction starting from top-left
  List<Offset> _orderCorners(List<Offset> corners) {
    if (corners.length != 4) return corners;
    
    // Calculate center point
    final centerX = corners.map((c) => c.dx).reduce((a, b) => a + b) / 4;
    final centerY = corners.map((c) => c.dy).reduce((a, b) => a + b) / 4;
    
    // Sort corners by angle from center
    final sortedCorners = List<Offset>.from(corners);
    sortedCorners.sort((a, b) {
      final angleA = math.atan2(a.dy - centerY, a.dx - centerX);
      final angleB = math.atan2(b.dy - centerY, b.dx - centerX);
      return angleA.compareTo(angleB);
    });
    
    // Find top-left corner (minimum x + y)
    int topLeftIndex = 0;
    double minSum = sortedCorners[0].dx + sortedCorners[0].dy;
    for (int i = 1; i < 4; i++) {
      final sum = sortedCorners[i].dx + sortedCorners[i].dy;
      if (sum < minSum) {
        minSum = sum;
        topLeftIndex = i;
      }
    }
    
    // Reorder to start from top-left and go clockwise
    final ordered = <Offset>[];
    for (int i = 0; i < 4; i++) {
      ordered.add(sortedCorners[(topLeftIndex + i) % 4]);
    }
    
    return ordered;
  }

  /// Calculate confidence score for detected quadrilateral
  double _calculateConfidence(List<Offset> corners, double contourArea, double imageArea) {
    if (corners.length != 4) return 0.0;
    
    // Calculate quadrilateral area
    final quadArea = _calculateQuadrilateralArea(corners);
    
    // Area ratio confidence
    final areaRatio = quadArea / imageArea;
    final areaConfidence = math.min(areaRatio / 0.5, 1.0); // Ideal is 50% of image
    
    // Shape confidence (how close to a rectangle)
    final shapeConfidence = _calculateShapeConfidence(corners);
    
    return (areaConfidence + shapeConfidence) / 2.0;
  }

  /// Calculate quadrilateral area
  double _calculateQuadrilateralArea(List<Offset> corners) {
    if (corners.length != 4) return 0.0;
    
    double area = 0.0;
    for (int i = 0; i < 4; i++) {
      final p1 = corners[i];
      final p2 = corners[(i + 1) % 4];
      area += (p1.dx * p2.dy - p2.dx * p1.dy);
    }
    
    return area.abs() / 2.0;
  }

  /// Calculate shape confidence (how rectangular the quadrilateral is)
  double _calculateShapeConfidence(List<Offset> corners) {
    if (corners.length != 4) return 0.0;
    
    // Calculate angles
    final angles = <double>[];
    for (int i = 0; i < 4; i++) {
      final p1 = corners[i];
      final p2 = corners[(i + 1) % 4];
      final p3 = corners[(i + 2) % 4];
      
      final v1 = Offset(p1.dx - p2.dx, p1.dy - p2.dy);
      final v2 = Offset(p3.dx - p2.dx, p3.dy - p2.dy);
      
      final angle = (v1.dx * v2.dx + v1.dy * v2.dy) / 
                   (math.sqrt(v1.dx * v1.dx + v1.dy * v1.dy) * 
                    math.sqrt(v2.dx * v2.dx + v2.dy * v2.dy));
      angles.add(math.acos(angle.clamp(-1.0, 1.0)));
    }
    
    // Calculate how close angles are to 90 degrees
    double angleDeviation = 0.0;
    for (final angle in angles) {
      angleDeviation += (angle - math.pi / 2).abs();
    }
    
    final avgDeviation = angleDeviation / 4.0;
    return math.max(0.0, 1.0 - (avgDeviation / (math.pi / 4))); // Normalize to 0-1
  }

  /// Apply perspective transform to crop the image
  Future<img.Image> _applyPerspectiveTransform(img.Image image, List<Offset> corners) async {
    if (corners.length != 4) {
      // Fallback to bounding box
      return _cropToBoundingBox(image);
    }
    
    // Calculate output dimensions
    final outputSize = _calculateOutputSize(corners);
    final outputWidth = outputSize.width.toInt();
    final outputHeight = outputSize.height.toInt();
    
    final result = img.Image(width: outputWidth, height: outputHeight);
    
    // Calculate perspective transform matrix
    final matrix = _calculatePerspectiveMatrix(corners, outputWidth, outputHeight);
    
    // Apply transform
    for (int y = 0; y < outputHeight; y++) {
      for (int x = 0; x < outputWidth; x++) {
        final sourcePoint = _inverseTransform(x.toDouble(), y.toDouble(), matrix);
        
        final srcX = sourcePoint.dx.clamp(0.0, image.width - 1.0).round();
        final srcY = sourcePoint.dy.clamp(0.0, image.height - 1.0).round();
        
        final pixel = image.getPixel(srcX, srcY);
        result.setPixel(x, y, pixel);
      }
    }
    
    return result;
  }

  /// Calculate output size for perspective transform
  Size _calculateOutputSize(List<Offset> corners) {
    if (corners.length != 4) {
      return const Size(400, 300);
    }
    
    // Calculate distances between corners
    final topWidth = (corners[1] - corners[0]).distance;
    final bottomWidth = (corners[2] - corners[3]).distance;
    final leftHeight = (corners[3] - corners[0]).distance;
    final rightHeight = (corners[2] - corners[1]).distance;
    
    final width = (topWidth + bottomWidth) / 2.0;
    final height = (leftHeight + rightHeight) / 2.0;
    
    return Size(width, height);
  }

  /// Calculate perspective transform matrix
  List<double> _calculatePerspectiveMatrix(List<Offset> corners, int width, int height) {
    // Simplified perspective transform calculation
    // In a full implementation, this would calculate the proper 3x3 homography matrix
    final src = [
      corners[0].dx, corners[0].dy,
      corners[1].dx, corners[1].dy,
      corners[2].dx, corners[2].dy,
      corners[3].dx, corners[3].dy,
    ];
    
    final dst = [
      0.0, 0.0,
      width.toDouble(), 0.0,
      width.toDouble(), height.toDouble(),
      0.0, height.toDouble(),
    ];
    
    // For simplicity, using affine approximation
    // In production, you'd want a full perspective transform
    return [
      (dst[2] - dst[0]) / (src[2] - src[0]), 0, dst[0] - src[0] * (dst[2] - dst[0]) / (src[2] - src[0]),
      0, (dst[7] - dst[1]) / (src[7] - src[1]), dst[1] - src[1] * (dst[7] - dst[1]) / (src[7] - src[1]),
      0, 0, 1,
    ];
  }

  /// Apply inverse perspective transform
  Offset _inverseTransform(double x, double y, List<double> matrix) {
    // Simplified inverse transform for affine approximation
    final srcX = (x - matrix[2]) / matrix[0];
    final srcY = (y - matrix[5]) / matrix[4];
    return Offset(srcX, srcY);
  }

  /// Create bounding box fallback
  AutoCropResult _createBoundingBoxFallback(img.Image image, Stopwatch stopwatch,
                                          Map<String, dynamic> metadata, String reason) {
    final croppedImage = _cropToBoundingBox(image);
    final corners = [
      const Offset(0, 0),
      Offset(image.width - 1.0, 0),
      Offset(image.width - 1.0, image.height - 1.0),
      Offset(0, image.height - 1.0),
    ];

    final duration = stopwatch.elapsedMilliseconds;
    metadata['detectionTimeMs'] = duration;
    metadata['detectionMethod'] = 'bounding_box';
    metadata['fallbackReason'] = reason;

    return AutoCropResult(
      croppedImageData: Uint8List.fromList(img.encodeJpg(croppedImage, quality: 95)),
      corners: corners,
      durationMs: duration,
      confidence: 0.1,
      fallbackUsed: true,
      metadata: metadata,
    );
  }

  /// Crop to bounding box (simple rectangular crop)
  img.Image _cropToBoundingBox(img.Image image) {
    // For now, return the original image
    // In a more sophisticated implementation, you could detect content bounds
    return image;
  }
}

/// Helper class for processing image with scale information
class _ProcessingImage {
  final img.Image image;
  final double scale;
  
  _ProcessingImage(this.image, this.scale);
}

/// Helper class for detection result
class _DetectionResult {
  final List<Offset> corners;
  final double confidence;
  final double contourArea;
  
  _DetectionResult(this.corners, this.confidence, this.contourArea);
}

/// Simple point class for contour detection
class Point {
  final int x;
  final int y;
  
  Point(this.x, this.y);
}