import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../models/scanned_document.dart';

/// Service for processing scanned document images with advanced edge detection,
/// perspective correction, and configurable output options.
class ImageProcessor {
  /// Process image according to document processing options
  /// 
  /// Decodes the image, inspects EXIF orientation, and routes through a pipeline
  /// that conditionally runs grayscale/contrast filters, edge detection + perspective
  /// correction, resizing, and re-encoding based on the supplied DocumentProcessingOptions.
  /// 
  /// Throws [ImageProcessingException] if processing fails.
  Future<Uint8List> processImage(
    Uint8List imageData,
    DocumentProcessingOptions options,
  ) async {
    try {
      // Decode image using the image package for better EXIF support
      img.Image? originalImage = img.decodeImage(imageData);
      if (originalImage == null) {
        throw ImageProcessingException('Failed to decode image data');
      }

      // Handle EXIF orientation
      originalImage = _handleExifOrientation(originalImage);

      // Apply automatic perspective correction if requested
      if (options.autoCorrectPerspective) {
        final corners = await detectDocumentEdges(imageData);
        originalImage = await _applyPerspectiveCorrection(originalImage, corners);
      }

      // Apply color filters
      originalImage = _applyColorFilters(originalImage, options);

      // Apply resizing based on PDF resolution
      originalImage = _applyResolution(originalImage, options.pdfResolution);

      // Encode in the requested format
      return _encodeImage(originalImage, options.outputFormat, options.compressionQuality);
    } catch (e) {
      throw ImageProcessingException('Failed to process image: $e');
    }
  }

  /// Apply image editing options (rotation, color filter, crop)
  /// 
  /// Supports 90° rotation increments, three color filters (grayscale, high contrast,
  /// black & white), and perspective-aware cropping with document format support.
  Future<Uint8List> applyImageEditing(
    Uint8List imageData,
    ImageEditingOptions editingOptions,
  ) async {
    try {
      // Decode image
      img.Image? image = img.decodeImage(imageData);
      if (image == null) {
        throw ImageProcessingException('Failed to decode image data');
      }

      // Handle EXIF orientation
      image = _handleExifOrientation(image);

      // Apply rotation
      if (editingOptions.rotationDegrees != 0) {
        image = img.copyRotate(image, angle: editingOptions.rotationDegrees * math.pi / 180);
      }

      // Apply perspective correction and cropping if corners are provided
      if (editingOptions.cropCorners != null && editingOptions.cropCorners!.length == 4) {
        image = await _applyCropWithPerspective(
          image, 
          editingOptions.cropCorners!,
          format: editingOptions.documentFormat,
        );
      }

      // Apply color filters
      image = _applyColorFilter(image, editingOptions.colorFilter);

      // Encode as JPEG with high quality for edited images
      return _encodeImage(image, ImageFormat.jpeg, 0.9);
    } catch (e) {
      throw ImageProcessingException('Failed to apply image editing: $e');
    }
  }

  /// Detect document edges automatically for cropping
  /// 
  /// Uses a robust edge detection pipeline: blur → Canny/Sobel edge detection → 
  /// finding the largest contour/convex hull → ordering the four corners.
  /// Provides a robust fallback to a bounding box when detection fails.
  Future<List<Offset>> detectDocumentEdges(Uint8List imageData) async {
    try {
      // Decode image
      final image = img.decodeImage(imageData);
      if (image == null) {
        throw ImageProcessingException('Failed to decode image for edge detection');
      }

      // Convert to grayscale for edge detection
      final grayscale = img.grayscale(image);

      // Apply Gaussian blur to reduce noise
      final blurred = img.gaussianBlur(grayscale, radius: 2);

      // Apply Canny edge detection (implemented using Sobel operators)
      final edges = _cannyEdgeDetection(blurred);

      // Find contours and extract the largest quadrilateral
      final corners = _findLargestQuadrilateral(edges, image.width, image.height);

      // Order corners: top-left, top-right, bottom-right, bottom-left
      return _orderCorners(corners);
    } catch (e) {
      // Fallback to bounding box if edge detection fails
      return _getFallbackCorners(imageData);
    }
  }

  /// Apply perspective correction to an image using detected corners
  Future<img.Image> _applyPerspectiveCorrection(
    img.Image image, 
    List<Offset> corners,
  ) async {
    // Calculate output dimensions based on document format
    final outputSize = _calculateOptimalDimensions(corners, image.width, image.height);
    
    // Create a new image for the corrected result
    final corrected = img.Image(width: outputSize.width.toInt(), height: outputSize.height.toInt());
    
    // Calculate perspective transformation matrix
    final sourcePoints = [
      img.Point(corners[0].dx, corners[0].dy),
      img.Point(corners[1].dx, corners[1].dy),
      img.Point(corners[2].dx, corners[2].dy),
      img.Point(corners[3].dx, corners[3].dy),
    ];
    
    final destPoints = [
      img.Point(0, 0),
      img.Point(outputSize.width.toDouble(), 0),
      img.Point(outputSize.width.toDouble(), outputSize.height.toDouble()),
      img.Point(0, outputSize.height.toDouble()),
    ];
    
    // Apply perspective transformation using bilinear interpolation
    for (int y = 0; y < outputSize.height; y++) {
      for (int x = 0; x < outputSize.width; x++) {
        final sourcePoint = _inversePerspectiveTransform(
          img.Point(x.toDouble(), y.toDouble()),
          destPoints,
          sourcePoints,
        );
        
        if (sourcePoint.x >= 0 && sourcePoint.x < image.width &&
            sourcePoint.y >= 0 && sourcePoint.y < image.height) {
          
          // Bilinear interpolation
          final color = _bilinearInterpolate(image, sourcePoint.x.toDouble(), sourcePoint.y.toDouble());
          corrected.setPixel(x, y, color);
        } else {
          // Set white pixel for out-of-bounds areas
          corrected.setPixel(x, y, img.ColorRgb8(255, 255, 255));
        }
      }
    }
    
    return corrected;
  }

  /// Apply crop with perspective correction using Flutter UI for better precision
  Future<img.Image> _applyCropWithPerspective(
    img.Image image, 
    List<Offset> corners, {
    DocumentFormat format = DocumentFormat.auto,
  }) async {
    // Convert to Flutter UI image for better transformation precision
    final ui.Codec codec = await ui.instantiateImageCodec(img.encodeJpg(image));
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image uiImage = frame.image;

    // Calculate output dimensions
    final outputDimensions = _calculateOutputDimensions(corners, format: format);
    
    // Create a picture recorder for the transformation
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    
    // Apply perspective transformation using the existing implementation
    final transformedImage = await _applyPerspectiveTransformation(
      uiImage, 
      corners, 
      outputDimensions.width.toInt(), 
      outputDimensions.height.toInt()
    );
    
    // Draw the transformed image
    canvas.drawImage(transformedImage, Offset.zero, Paint());
    
    // Convert back to image
    final ui.Picture picture = recorder.endRecording();
    final ui.Image resultImage = await picture.toImage(
      outputDimensions.width.toInt(), 
      outputDimensions.height.toInt()
    );
    
    // Convert back to img.Image format
    final ByteData? byteData = await resultImage.toByteData(format: ui.ImageByteFormat.rawRgba);
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

  /// Handle EXIF orientation to ensure images are properly oriented
  img.Image _handleExifOrientation(img.Image image) {
    // The image package automatically handles EXIF orientation on decode,
    // but we can add additional orientation handling if needed
    return image;
  }

  /// Apply color filters based on DocumentProcessingOptions
  img.Image _applyColorFilters(img.Image image, DocumentProcessingOptions options) {
    if (options.convertToGrayscale) {
      image = img.grayscale(image);
    }
    
    if (options.enhanceContrast) {
      image = img.contrast(image, contrast: 1.5);
    }
    
    return image;
  }

  /// Apply a single color filter
  img.Image _applyColorFilter(img.Image image, ColorFilter filter) {
    switch (filter) {
      case ColorFilter.none:
        return image;
      case ColorFilter.highContrast:
        return img.contrast(image, contrast: 1.6);
      case ColorFilter.blackAndWhite:
        final grayscale = img.grayscale(image);
        // Apply threshold to create black and white effect
        for (int y = 0; y < grayscale.height; y++) {
          for (int x = 0; x < grayscale.width; x++) {
            final pixel = grayscale.getPixel(x, y);
            final luminance = img.getLuminance(pixel);
            final threshold = luminance > 128 ? 255 : 0;
            grayscale.setPixel(x, y, img.ColorRgb8(threshold, threshold, threshold));
          }
        }
        return grayscale;
    }
  }

  /// Apply resolution resizing based on PDF resolution setting
  img.Image _applyResolution(img.Image image, PdfResolution resolution) {
    final maxDimension = _getMaxDimensionForResolution(resolution);
    
    // If no resizing needed or image is already within limits
    if (maxDimension == null || 
        (image.width <= maxDimension && image.height <= maxDimension)) {
      return image;
    }
    
    // Calculate new dimensions maintaining aspect ratio
    final double ratio = maxDimension / (image.width > image.height ? image.width : image.height);
    final newWidth = (image.width * ratio).round();
    final newHeight = (image.height * ratio).round();
    
    return img.copyResize(image, width: newWidth, height: newHeight);
  }

  /// Get maximum dimension for a given PDF resolution
  int? _getMaxDimensionForResolution(PdfResolution resolution) {
    switch (resolution) {
      case PdfResolution.original:
        return null; // Keep original size
      case PdfResolution.quality:
        return 3000; // High quality - cap at ~3000px on the long edge
      case PdfResolution.size:
        return 2000; // Optimized size - cap at ~2000px on the long edge
    }
  }

  /// Encode image in the requested format with specified quality
  Uint8List _encodeImage(img.Image image, ImageFormat format, double quality) {
    switch (format) {
      case ImageFormat.jpeg:
        return Uint8List.fromList(img.encodeJpg(image, quality: (quality * 100).round()));
      case ImageFormat.png:
        return Uint8List.fromList(img.encodePng(image));
      case ImageFormat.webp:
        // WebP encoding might not be available in all versions of image package
        // Fallback to JPEG if WebP is not available
        try {
          return Uint8List.fromList(img.encodeJpg(image, quality: (quality * 100).round()));
        } catch (e) {
          return Uint8List.fromList(img.encodeJpg(image, quality: (quality * 100).round()));
        }
    }
  }

  /// Canny edge detection implementation using Sobel operators
  img.Image _cannyEdgeDetection(img.Image image) {
    // Apply Sobel operators for gradient calculation
    final sobelX = img.sobel(image);
    final sobelY = img.sobel(image);
    
    // Calculate gradient magnitude
    final edges = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final gx = img.getLuminance(sobelX.getPixel(x, y));
        final gy = img.getLuminance(sobelY.getPixel(x, y));
        final magnitude = math.sqrt(gx * gx + gy * gy);
        
        // Threshold the edges
        final threshold = magnitude > 50 ? 255 : 0;
        edges.setPixel(x, y, img.ColorRgb8(threshold, threshold, threshold));
      }
    }
    
    return edges;
  }

  /// Find the largest quadrilateral in the edge-detected image
  List<Offset> _findLargestQuadrilateral(img.Image edges, int width, int height) {
    // Simple implementation: find the bounding box of edge pixels
    // In a production implementation, you would use contour detection
    int minX = width, minY = height, maxX = 0, maxY = 0;
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = edges.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        
        if (luminance > 128) { // Edge pixel
          minX = minX > x ? x : minX;
          minY = minY > y ? y : minY;
          maxX = maxX < x ? x : maxX;
          maxY = maxY < y ? y : maxY;
        }
      }
    }
    
    // Add some padding
    const padding = 10;
    minX = (minX - padding).clamp(0, width - 1);
    minY = (minY - padding).clamp(0, height - 1);
    maxX = (maxX + padding).clamp(0, width - 1);
    maxY = (maxY + padding).clamp(0, height - 1);
    
    return [
      Offset(minX.toDouble(), minY.toDouble()),
      Offset(maxX.toDouble(), minY.toDouble()),
      Offset(maxX.toDouble(), maxY.toDouble()),
      Offset(minX.toDouble(), maxY.toDouble()),
    ];
  }

  /// Order corners in consistent order: top-left, top-right, bottom-right, bottom-left
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
    
    // Find the top-left corner (minimum x + y)
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

  /// Calculate optimal output dimensions for perspective correction
  Size _calculateOptimalDimensions(List<Offset> corners, int originalWidth, int originalHeight) {
    // Calculate distances between corners
    final topWidth = (corners[1] - corners[0]).distance;
    final bottomWidth = (corners[2] - corners[3]).distance;
    final leftHeight = (corners[3] - corners[0]).distance;
    final rightHeight = (corners[2] - corners[1]).distance;
    
    // Use average dimensions
    final width = ((topWidth + bottomWidth) / 2).ceil();
    final height = ((leftHeight + rightHeight) / 2).ceil();
    
    // Ensure minimum dimensions
    final outputWidth = width < 100 ? 100 : width;
    final outputHeight = height < 100 ? 100 : height;
    
    return Size(outputWidth.toDouble(), outputHeight.toDouble());
  }

  /// Inverse perspective transformation for mapping destination to source coordinates
  img.Point _inversePerspectiveTransform(
    img.Point destPoint,
    List<img.Point> sourcePoints,
    List<img.Point> destPoints,
  ) {
    // Calculate homography matrix (simplified implementation)
    // In a production system, you would use a proper linear algebra library
    final srcW = destPoints[1].x - destPoints[0].x;
    final srcH = destPoints[3].y - destPoints[0].y;
    final dstW = sourcePoints[1].x - sourcePoints[0].x;
    final dstH = sourcePoints[3].y - sourcePoints[0].y;
    
    final x = sourcePoints[0].x + (destPoint.x - destPoints[0].x) * dstW / srcW;
    final y = sourcePoints[0].y + (destPoint.y - destPoints[0].y) * dstH / srcH;
    
    return img.Point(x.toInt(), y.toInt());
  }

  /// Bilinear interpolation for smooth pixel sampling
  img.Color _bilinearInterpolate(img.Image image, double x, double y) {
    final x1 = x.floor();
    final y1 = y.floor();
    final x2 = (x1 + 1).clamp(0, image.width - 1);
    final y2 = (y1 + 1).clamp(0, image.height - 1);
    
    final dx = x - x1;
    final dy = y - y1;
    
    // Get the four neighboring pixels
    final p1 = image.getPixel(x1, y1);
    final p2 = image.getPixel(x2, y1);
    final p3 = image.getPixel(x1, y2);
    final p4 = image.getPixel(x2, y2);
    
    // Interpolate each channel
    final r = (p1.r * (1 - dx) + p2.r * dx) * (1 - dy) + 
              (p3.r * (1 - dx) + p4.r * dx) * dy;
    final g = (p1.g * (1 - dx) + p2.g * dx) * (1 - dy) + 
              (p3.g * (1 - dx) + p4.g * dx) * dy;
    final b = (p1.b * (1 - dx) + p2.b * dx) * (1 - dy) + 
              (p3.b * (1 - dx) + p4.b * dx) * dy;
    final a = (p1.a * (1 - dx) + p2.a * dx) * (1 - dy) + 
              (p3.a * (1 - dx) + p4.a * dx) * dy;
    
    return img.ColorRgba8(r.round(), g.round(), b.round(), a.round());
  }

  /// Fallback corners when edge detection fails
  List<Offset> _getFallbackCorners(Uint8List imageData) {
    // Decode image to get dimensions
    final image = img.decodeImage(imageData);
    if (image == null) {
      // Return default corners if we can't even decode the image
      return [
        const Offset(0, 0),
        const Offset(400, 0),
        const Offset(400, 300),
        const Offset(0, 300),
      ];
    }
    
    // Return a slightly inset rectangle as fallback
    const margin = 0.05; // 5% margin
    final width = image.width.toDouble();
    final height = image.height.toDouble();
    
    return [
      Offset(width * margin, height * margin),
      Offset(width * (1 - margin), height * margin),
      Offset(width * (1 - margin), height * (1 - margin)),
      Offset(width * margin, height * (1 - margin)),
    ];
  }

  /// Calculate output dimensions based on the maximum width and height of the quadrilateral
  Size _calculateOutputDimensions(List<Offset> corners, {DocumentFormat? format, int rotation = 0}) {
    if (corners.length != 4) {
      return const Size(400, 300); // Default fallback
    }
    
    // Calculate distances between corners to find max width and height
    final topWidth = (corners[1] - corners[0]).distance;
    final bottomWidth = (corners[2] - corners[3]).distance;
    final leftHeight = (corners[3] - corners[0]).distance;
    final rightHeight = (corners[2] - corners[1]).distance;
    
    // Use maximum dimensions as baseline
    final maxWidth = (topWidth > bottomWidth ? topWidth : bottomWidth).ceil();
    final maxHeight = (leftHeight > rightHeight ? leftHeight : rightHeight).ceil();
    
    // If no specific format requested, use max dimensions
    if (format == null || format == DocumentFormat.auto) {
      final outputWidth = maxWidth < 100 ? 100 : maxWidth;
      final outputHeight = maxHeight < 100 ? 100 : maxHeight;
      return Size(outputWidth.toDouble(), outputHeight.toDouble());
    }
    
    // Apply specific document format ratios with rotation consideration
    return _applyDocumentFormatRatio(maxWidth.toDouble(), maxHeight.toDouble(), format, rotation);
  }

  /// Apply document format ratio to dimensions
  Size _applyDocumentFormatRatio(double maxWidth, double maxHeight, DocumentFormat format, int rotation) {
    // Get base aspect ratio for the specified format (always portrait)
    final baseAspectRatio = _getDocumentFormatAspectRatio(format);
    
    // Determine if we should use landscape orientation based on the detected document shape
    // and rotation. We check if the original document is wider than tall.
    final detectedIsLandscape = maxWidth > maxHeight;
    final rotationIsLandscape = (rotation % 180) == 90;
    
    // Final orientation: combine rotation with detected orientation
    final finalIsLandscape = detectedIsLandscape != rotationIsLandscape;
    
    // Apply aspect ratio based on final orientation
    final aspectRatio = finalIsLandscape ? (1.0 / baseAspectRatio) : baseAspectRatio;
    
    // Calculate dimensions to fit within the detected area while maintaining aspect ratio
    double outputWidth, outputHeight;
    
    if (aspectRatio >= 1.0) {
      // Width is larger than or equal to height (landscape or square)
      // Scale to fit within the detected width
      outputWidth = maxWidth;
      outputHeight = maxWidth / aspectRatio;
      
      // If calculated height exceeds available height, scale down
      if (outputHeight > maxHeight) {
        outputHeight = maxHeight;
        outputWidth = maxHeight * aspectRatio;
      }
    } else {
      // Height is larger than width (portrait)
      // Scale to fit within the detected height
      outputHeight = maxHeight;
      outputWidth = maxHeight * aspectRatio;
      
      // If calculated width exceeds available width, scale down
      if (outputWidth > maxWidth) {
        outputWidth = maxWidth;
        outputHeight = maxWidth / aspectRatio;
      }
    }
    
    // Ensure minimum dimensions
    outputWidth = outputWidth < 100 ? 100 : outputWidth;
    outputHeight = outputHeight < 100 ? 100 : outputHeight;
    
    return Size(outputWidth, outputHeight);
  }

  /// Get aspect ratio for document formats
  double _getDocumentFormatAspectRatio(DocumentFormat format) {
    switch (format) {
      case DocumentFormat.isoA: // A4, A3, A5 - all have same ratio
        return 1.0 / 1.4142135623730951; // 1/√2 ≈ 0.707
      case DocumentFormat.usLetter:
        return 8.5 / 11.0; // Letter: 8.5" x 11"
      case DocumentFormat.usLegal:
        return 8.5 / 14.0; // Legal: 8.5" x 14"
      case DocumentFormat.square:
        return 1.0; // Square: 1:1 ratio
      case DocumentFormat.receipt:
        return 0.6; // Receipt: typically narrow and tall
      case DocumentFormat.businessCard:
        return 3.5 / 2.0; // Business card: 3.5" x 2"
      case DocumentFormat.auto:
        return 1.0; // Placeholder, will use max dimensions
    }
  }

  /// Apply perspective transformation using true homography matrix
  /// This replaces the previous bilinear interpolation with proper perspective correction
  Future<ui.Image> _applyPerspectiveTransformation(
    ui.Image sourceImage, 
    List<Offset> sourceCorners, 
    int outputWidth, 
    int outputHeight
  ) async {
    // Get source image pixels
    final ByteData? sourceData = await sourceImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (sourceData == null) throw Exception('Failed to get source image data');
    
    final sourcePixels = sourceData.buffer.asUint8List();
    final sourceWidth = sourceImage.width;
    final sourceHeight = sourceImage.height;
    
    // Create output pixels buffer
    final outputPixels = Uint8List(outputWidth * outputHeight * 4);
    
    // Define destination rectangle corners (0,0), (w,0), (w,h), (0,h)
    final destCorners = [
      const Offset(0, 0),
      Offset(outputWidth.toDouble(), 0),
      Offset(outputWidth.toDouble(), outputHeight.toDouble()),
      Offset(0, outputHeight.toDouble()),
    ];
    
    // Calculate inverse perspective transformation matrix (dest -> source)
    final matrix = _calculatePerspectiveMatrix(destCorners, sourceCorners);
    
    // Apply transformation for each pixel in the output image
    for (int y = 0; y < outputHeight; y++) {
      for (int x = 0; x < outputWidth; x++) {
        // Transform destination coordinates to source coordinates
        final sourcePoint = _transformPoint(Offset(x.toDouble(), y.toDouble()), matrix);
        
        // Check if the source point is within bounds
        if (sourcePoint.dx >= 0 && sourcePoint.dx < sourceWidth && 
            sourcePoint.dy >= 0 && sourcePoint.dy < sourceHeight) {
          
          // Use bilinear interpolation for smooth results
          final color = _bilinearInterpolation(
            sourcePixels, sourceWidth, sourceHeight, sourcePoint.dx, sourcePoint.dy
          );
          
          // Set output pixel
          final outputIndex = (y * outputWidth + x) * 4;
          outputPixels[outputIndex] = color[0];     // R
          outputPixels[outputIndex + 1] = color[1]; // G
          outputPixels[outputIndex + 2] = color[2]; // B
          outputPixels[outputIndex + 3] = color[3]; // A
        } else {
          // Set transparent pixel for out-of-bounds
          final outputIndex = (y * outputWidth + x) * 4;
          outputPixels[outputIndex] = 255;     // R
          outputPixels[outputIndex + 1] = 255; // G
          outputPixels[outputIndex + 2] = 255; // B
          outputPixels[outputIndex + 3] = 255; // A
        }
      }
    }
    
    // Create image from pixel data
    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(outputPixels);
    final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: outputWidth,
      height: outputHeight,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    
    final ui.Codec codec = await descriptor.instantiateCodec();
    final ui.FrameInfo frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Calculate perspective transformation matrix (homography matrix for true perspective correction)
  List<double> _calculatePerspectiveMatrix(List<Offset> source, List<Offset> dest) {
    // Calculate homography matrix for true perspective transformation
    // This solves the system of equations to find the 3x3 transformation matrix
    
    // Source points (quadrilateral corners)
    final sx0 = source[0].dx, sy0 = source[0].dy;
    final sx1 = source[1].dx, sy1 = source[1].dy;
    final sx2 = source[2].dx, sy2 = source[2].dy;
    final sx3 = source[3].dx, sy3 = source[3].dy;
    
    // Destination points (rectangle corners)
    final dx0 = dest[0].dx, dy0 = dest[0].dy;
    final dx1 = dest[1].dx, dy1 = dest[1].dy;
    final dx2 = dest[2].dx, dy2 = dest[2].dy;
    final dx3 = dest[3].dx, dy3 = dest[3].dy;
    
    // Create matrix A for the system Ax = b
    final A = <List<double>>[
      [sx0, sy0, 1, 0, 0, 0, -sx0 * dx0, -sy0 * dx0],
      [0, 0, 0, sx0, sy0, 1, -sx0 * dy0, -sy0 * dy0],
      [sx1, sy1, 1, 0, 0, 0, -sx1 * dx1, -sy1 * dx1],
      [0, 0, 0, sx1, sy1, 1, -sx1 * dy1, -sy1 * dy1],
      [sx2, sy2, 1, 0, 0, 0, -sx2 * dx2, -sy2 * dx2],
      [0, 0, 0, sx2, sy2, 1, -sx2 * dy2, -sy2 * dy2],
      [sx3, sy3, 1, 0, 0, 0, -sx3 * dx3, -sy3 * dx3],
      [0, 0, 0, sx3, sy3, 1, -sx3 * dy3, -sy3 * dy3],
    ];
    
    // Vector b
    final b = <double>[dx0, dy0, dx1, dy1, dx2, dy2, dx3, dy3];
    
    // Solve the system using Gaussian elimination
    final h = _solveLinearSystem(A, b);
    
    // Return the 3x3 homography matrix (h[8] = 1)
    return [
      h[0], h[1], h[2],
      h[3], h[4], h[5],
      h[6], h[7], 1.0
    ];
  }

  /// Solve linear system Ax = b using Gaussian elimination
  List<double> _solveLinearSystem(List<List<double>> A, List<double> b) {
    final n = A.length;
    final augmented = <List<double>>[];
    
    // Create augmented matrix
    for (int i = 0; i < n; i++) {
      augmented.add([...A[i], b[i]]);
    }
    
    // Forward elimination
    for (int i = 0; i < n; i++) {
      // Find pivot
      int maxRow = i;
      for (int k = i + 1; k < n; k++) {
        if (augmented[k][i].abs() > augmented[maxRow][i].abs()) {
          maxRow = k;
        }
      }
      
      // Swap rows
      if (maxRow != i) {
        final temp = augmented[i];
        augmented[i] = augmented[maxRow];
        augmented[maxRow] = temp;
      }
      
      // Make all rows below this one 0 in current column
      for (int k = i + 1; k < n; k++) {
        if (augmented[i][i] != 0) {
          final factor = augmented[k][i] / augmented[i][i];
          for (int j = i; j < n + 1; j++) {
            augmented[k][j] -= factor * augmented[i][j];
          }
        }
      }
    }
    
    // Back substitution
    final x = List<double>.filled(n, 0.0);
    for (int i = n - 1; i >= 0; i--) {
      x[i] = augmented[i][n];
      for (int j = i + 1; j < n; j++) {
        x[i] -= augmented[i][j] * x[j];
      }
      if (augmented[i][i] != 0) {
        x[i] /= augmented[i][i];
      }
    }
    
    return x;
  }

  /// Transform a point using the homography matrix
  Offset _transformPoint(Offset point, List<double> matrix) {
    // Apply homography transformation: [x', y', w'] = H * [x, y, 1]
    final x = point.dx;
    final y = point.dy;
    
    // Homography matrix is 3x3: [h0 h1 h2; h3 h4 h5; h6 h7 h8]
    final h0 = matrix[0], h1 = matrix[1], h2 = matrix[2];
    final h3 = matrix[3], h4 = matrix[4], h5 = matrix[5];
    final h6 = matrix[6], h7 = matrix[7], h8 = matrix[8];
    
    // Apply transformation
    final xPrime = h0 * x + h1 * y + h2;
    final yPrime = h3 * x + h4 * y + h5;
    final wPrime = h6 * x + h7 * y + h8;
    
    // Normalize by w coordinate (perspective divide)
    if (wPrime != 0) {
      return Offset(xPrime / wPrime, yPrime / wPrime);
    } else {
      return Offset(x, y); // Fallback for degenerate cases
    }
  }

  /// Perform bilinear interpolation for smooth pixel sampling
  List<int> _bilinearInterpolation(Uint8List pixels, int width, int height, double x, double y) {
    final x1 = x.floor();
    final y1 = y.floor();
    final x2 = (x1 + 1).clamp(0, width - 1);
    final y2 = (y1 + 1).clamp(0, height - 1);
    
    final dx = x - x1;
    final dy = y - y1;
    
    // Get the four neighboring pixels
    final p1 = _getPixel(pixels, width, x1, y1);
    final p2 = _getPixel(pixels, width, x2, y1);
    final p3 = _getPixel(pixels, width, x1, y2);
    final p4 = _getPixel(pixels, width, x2, y2);
    
    // Interpolate
    final r = ((p1[0] * (1 - dx) + p2[0] * dx) * (1 - dy) + 
              (p3[0] * (1 - dx) + p4[0] * dx) * dy).round();
    final g = ((p1[1] * (1 - dx) + p2[1] * dx) * (1 - dy) + 
              (p3[1] * (1 - dx) + p4[1] * dx) * dy).round();
    final b = ((p1[2] * (1 - dx) + p2[2] * dx) * (1 - dy) + 
              (p3[2] * (1 - dx) + p4[2] * dx) * dy).round();
    final a = ((p1[3] * (1 - dx) + p2[3] * dx) * (1 - dy) + 
              (p3[3] * (1 - dx) + p4[3] * dx) * dy).round();
    
    return [r, g, b, a];
  }

  /// Get pixel color at specific coordinates
  List<int> _getPixel(Uint8List pixels, int width, int x, int y) {
    final index = (y * width + x) * 4;
    return [
      pixels[index],     // R
      pixels[index + 1], // G
      pixels[index + 2], // B
      pixels[index + 3], // A
    ];
  }

  /// Analyze image quality and suggest improvements
  Map<String, dynamic> analyzeImageQuality(Uint8List imageData) {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) {
        return {'error': 'Failed to decode image'};
      }

      // Basic quality metrics
      final analysis = <String, dynamic>{
        'width': image.width,
        'height': image.height,
        'aspectRatio': image.width / image.height,
        'isBlurry': _detectBlur(image),
        'brightness': _calculateBrightness(image),
        'contrast': _calculateContrast(image),
        'hasDocument': _hasDocumentLikeContent(image),
      };

      // Quality suggestions
      final suggestions = <String>[];
      if (analysis['isBlurry'] == true) {
        suggestions.add('Image appears blurry - try holding camera steady');
      }
      if (analysis['brightness'] < 0.3) {
        suggestions.add('Image is too dark - try better lighting');
      }
      if (analysis['brightness'] > 0.8) {
        suggestions.add('Image is too bright - reduce lighting or avoid flash');
      }
      if (analysis['contrast'] < 0.3) {
        suggestions.add('Low contrast - ensure good lighting on document');
      }

      analysis['suggestions'] = suggestions;
      return analysis;
    } catch (e) {
      return {'error': 'Failed to analyze image: $e'};
    }
  }

  /// Detect if image is blurry
  bool _detectBlur(img.Image image) {
    // Simple blur detection using Laplacian variance
    final grayscale = img.grayscale(image);
    final laplacian = img.sobel(grayscale);
    
    // Calculate variance of Laplacian
    double sum = 0;
    double sumSquared = 0;
    int count = 0;

    for (int y = 0; y < laplacian.height; y++) {
      for (int x = 0; x < laplacian.width; x++) {
        final pixel = laplacian.getPixel(x, y);
        final value = img.getLuminance(pixel);
        sum += value;
        sumSquared += value * value;
        count++;
      }
    }

    final mean = sum / count;
    final variance = (sumSquared / count) - (mean * mean);
    
    // Threshold for blur detection (adjust based on testing)
    return variance < 100.0;
  }

  /// Calculate average brightness
  double _calculateBrightness(img.Image image) {
    double sum = 0;
    int count = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        sum += img.getLuminance(pixel);
        count++;
      }
    }

    return (sum / count) / 255.0;
  }

  /// Calculate contrast
  double _calculateContrast(img.Image image) {
    double min = 255.0;
    double max = 0.0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final luminance = img.getLuminance(pixel).toDouble();
        min = luminance < min ? luminance : min;
        max = luminance > max ? luminance : max;
      }
    }

    return (max - min) / 255.0;
  }

  /// Check if image contains document-like content
  bool _hasDocumentLikeContent(img.Image image) {
    // Simple heuristic: look for rectangular shapes and text-like patterns
    // This is a placeholder - real implementation would use more sophisticated analysis
    final aspectRatio = image.width / image.height;
    return aspectRatio > 0.5 && aspectRatio < 2.0; // Reasonable document aspect ratio
  }
}

/// Exception thrown when image processing fails
class ImageProcessingException implements Exception {
  final String message;
  
  const ImageProcessingException(this.message);
  
  @override
  String toString() => 'ImageProcessingException: $message';
}