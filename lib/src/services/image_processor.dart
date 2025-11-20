import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../models/scanned_document.dart';
import '../models/processing_options.dart';

/// Service for processing scanned document images
class ImageProcessor {
  /// Process image according to document processing options
  Future<Uint8List> processImage(
    Uint8List imageData,
    DocumentProcessingOptions options,
  ) async {
    try {
      // If no processing needed, return original JPEG bytes
      if (!options.convertToGrayscale && 
          !options.enhanceContrast && 
          !options.autoCorrectPerspective &&
          options.compressionQuality >= 0.95) {
        return imageData; // Return original JPEG bytes
      }

      // Use Flutter's UI framework for better color handling
      return await _processWithFlutterUI(imageData, options);
    } catch (e) {
      throw Exception('Failed to process image: $e');
    }
  }

  /// Process image using Flutter's UI framework to preserve color information
  Future<Uint8List> _processWithFlutterUI(
    Uint8List imageData,
    DocumentProcessingOptions options,
  ) async {
    // Decode image using Flutter's built-in decoder
    final ui.Codec codec = await ui.instantiateImageCodec(imageData);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    // Create a canvas for processing
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint();
    
    // Use the current image dimensions
    final int canvasWidth = image.width;
    final int canvasHeight = image.height;

    // Apply processing effects
    if (options.convertToGrayscale) {
      paint.colorFilter = const ui.ColorFilter.matrix([
        0.299, 0.587, 0.114, 0, 0,
        0.299, 0.587, 0.114, 0, 0,
        0.299, 0.587, 0.114, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    }

    if (options.enhanceContrast) {
      // Apply contrast enhancement
      paint.colorFilter = ui.ColorFilter.matrix([
        1.5, 0, 0, 0, -0.25,
        0, 1.5, 0, 0, -0.25,
        0, 0, 1.5, 0, -0.25,
        0, 0, 0, 1, 0,
      ]);
    }

    // Draw the image with applied effects
    canvas.drawImage(image, Offset.zero, paint);

    // Convert back to bytes
    final ui.Picture picture = recorder.endRecording();
    final ui.Image processedImage = await picture.toImage(
      canvasWidth,
      canvasHeight,
    );

    // Encode as JPEG with specified quality
    final ByteData? byteData = await processedImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );

    if (byteData == null) {
      throw Exception('Failed to convert processed image to bytes');
    }

    // Convert RGBA to JPEG using dart:typed_data
    return await _convertRgbaToJpeg(
      byteData.buffer.asUint8List(),
      image.width,
      image.height,
      options.compressionQuality,
    );
  }

  /// Convert RGBA bytes to JPEG format
  Future<Uint8List> _convertRgbaToJpeg(
    Uint8List rgbaBytes,
    int width,
    int height,
    double quality,
  ) async {
    // Create image from RGBA bytes
    final img.Image image = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgbaBytes.buffer,
      format: img.Format.uint8,
      numChannels: 4,
    );

    // Encode as JPEG
    return Uint8List.fromList(
      img.encodeJpg(image, quality: (quality * 100).round()),
    );
  }

  /// Apply image editing options (rotation, color filter, crop)
  Future<Uint8List> applyImageEditing(
    Uint8List imageData,
    ImageEditingOptions editingOptions,
  ) async {
    // Decode image using Flutter's built-in decoder
    final ui.Codec codec = await ui.instantiateImageCodec(imageData);
    final ui.FrameInfo frame = await codec.getNextFrame();
    ui.Image image = frame.image;

    // Apply rotation
    if (editingOptions.rotationDegrees != 0) {
      image = await _rotateImage(image, editingOptions.rotationDegrees);
    }

    // Apply color filter and cropping
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint();
    
    // Apply cropping with proper perspective correction and scaling first
    if (editingOptions.cropCorners != null && editingOptions.cropCorners!.length == 4) {
      // Apply perspective transformation and crop with specified format and rotation
      // Cast cropCorners to List<Offset> since they come from ui.Offset objects
      final offsets = editingOptions.cropCorners!.cast<Offset>();
      image = await _applyCropWithPerspective(
        image, 
        offsets,
        format: editingOptions.documentFormat,
        rotation: editingOptions.rotationDegrees,
      );
    }

    // Use the current image dimensions (after rotation and optional cropping)
    final int canvasWidth = image.width;
    final int canvasHeight = image.height;

    // Apply color filter
    switch (editingOptions.colorFilter) {
      case ColorFilter.none:
        // No filter
        break;
      case ColorFilter.highContrast:
        // Gentle contrast enhancement that preserves faded text
        // Increases contrast while maintaining readability of light text
        paint.colorFilter = const ui.ColorFilter.matrix([
          1.6, 0, 0, 0, -0.2,    // Red: 1.6x - 20% offset (gentler)
          0, 1.6, 0, 0, -0.2,    // Green: 1.6x - 20% offset
          0, 0, 1.6, 0, -0.2,    // Blue: 1.6x - 20% offset
          0, 0, 0, 1, 0,         // Alpha unchanged
        ]);
        break;
      case ColorFilter.blackAndWhite:
        // Document-optimized B&W that preserves faded text
        // Converts to grayscale with moderate contrast for readability
        paint.colorFilter = const ui.ColorFilter.matrix([
          0.4, 0.8, 0.2, 0, -0.1,  // Weighted grayscale with gentle contrast
          0.4, 0.8, 0.2, 0, -0.1,  // Green channel emphasized for text
          0.4, 0.8, 0.2, 0, -0.1,  // Moderate contrast preserves faded text
          0, 0, 0, 1, 0,            // Alpha unchanged
        ]);
        break;
    }

    // Draw the image with applied effects
    canvas.drawImage(image, Offset.zero, paint);

    // Convert back to bytes
    final ui.Picture picture = recorder.endRecording();
    final ui.Image processedImage = await picture.toImage(
      canvasWidth,
      canvasHeight,
    );

    // Convert to JPEG
    final ByteData? byteData = await processedImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );

    if (byteData == null) {
      throw Exception('Failed to convert edited image to bytes');
    }

    return await _convertRgbaToJpeg(
      byteData.buffer.asUint8List(),
      image.width,
      image.height,
      0.9, // High quality for edited images
    );
  }

  /// Rotate image by specified degrees (90, 180, 270)
  Future<ui.Image> _rotateImage(ui.Image image, int degrees) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    
    // Calculate new dimensions after rotation
    final double radians = degrees * 3.14159265359 / 180.0;
    final bool isRotated90or270 = degrees == 90 || degrees == 270;
    
    final int newWidth = isRotated90or270 ? image.height : image.width;
    final int newHeight = isRotated90or270 ? image.width : image.height;
    
    // Apply rotation transformation
    canvas.translate(newWidth / 2, newHeight / 2);
    canvas.rotate(radians);
    canvas.translate(-image.width / 2, -image.height / 2);
    
    // Draw the rotated image
    canvas.drawImage(image, Offset.zero, Paint());
    
    // Convert to image
    final ui.Picture picture = recorder.endRecording();
    return await picture.toImage(newWidth, newHeight);
  }

  /// Apply crop with perspective correction to create a rectangular document
  Future<ui.Image> _applyCropWithPerspective(ui.Image image, List<Offset> corners, {DocumentFormat? format, int rotation = 0}) async {
    // Calculate the dimensions of the output rectangle
    final outputDimensions = _calculateOutputDimensions(corners, format: format, rotation: rotation);
    
    // Create a new image with the calculated dimensions
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    
    // Apply perspective transformation
    final transformedImage = await _applyPerspectiveTransformation(
      image, 
      corners, 
      outputDimensions.width.toInt(), 
      outputDimensions.height.toInt()
    );
    
    // Draw the transformed image
    canvas.drawImage(transformedImage, Offset.zero, Paint());
    
    // Convert to image
    final ui.Picture picture = recorder.endRecording();
    return await picture.toImage(outputDimensions.width.toInt(), outputDimensions.height.toInt());
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

  /// Detect document edges automatically for cropping
  Future<List<Offset>> detectDocumentEdges(Uint8List imageData) async {
    // Decode image for edge detection
    final ui.Codec codec = await ui.instantiateImageCodec(imageData);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    // Convert to grayscale for edge detection
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint()
      ..colorFilter = const ui.ColorFilter.matrix([
        0.299, 0.587, 0.114, 0, 0,
        0.299, 0.587, 0.114, 0, 0,
        0.299, 0.587, 0.114, 0, 0,
        0, 0, 0, 1, 0,
      ]);

    canvas.drawImage(image, Offset.zero, paint);
    final ui.Picture picture = recorder.endRecording();
    await picture.toImage(image.width, image.height); // Process for edge detection

    // Simple edge detection - return approximate document bounds
    // In a real implementation, you'd use more sophisticated edge detection
    final double margin = 0.05; // 5% margin
    final double width = image.width.toDouble();
    final double height = image.height.toDouble();
    
    return [
      Offset(width * margin, height * margin), // Top-left
      Offset(width * (1 - margin), height * margin), // Top-right
      Offset(width * (1 - margin), height * (1 - margin)), // Bottom-right
      Offset(width * margin, height * (1 - margin)), // Bottom-left
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

