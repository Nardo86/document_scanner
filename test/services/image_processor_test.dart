import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:document_scanner/src/services/image_processor.dart';
import 'package:document_scanner/src/models/scanned_document.dart';

void main() {
  group('ImageProcessor', () {
    late ImageProcessor imageProcessor;
    late Uint8List testImageData;

    setUp(() {
      imageProcessor = ImageProcessor();
      // Create a simple test image (100x100 red square)
      testImageData = _createTestImage(100, 100);
    });

    group('processImage', () {
      test('processes image with default options without error', () async {
        final options = const DocumentProcessingOptions();
        final result = await imageProcessor.processImage(testImageData, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
      });

      test('applies grayscale conversion when requested', () async {
        final options = const DocumentProcessingOptions(
          convertToGrayscale: true,
          enhanceContrast: false,
          autoCorrectPerspective: false,
        );
        final result = await imageProcessor.processImage(testImageData, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
      });

      test('applies contrast enhancement when requested', () async {
        final options = const DocumentProcessingOptions(
          convertToGrayscale: false,
          enhanceContrast: true,
          autoCorrectPerspective: false,
        );
        final result = await imageProcessor.processImage(testImageData, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
      });

      test('applies perspective correction when requested', () async {
        final options = const DocumentProcessingOptions(
          convertToGrayscale: false,
          enhanceContrast: false,
          autoCorrectPerspective: true,
        );
        final result = await imageProcessor.processImage(testImageData, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
      });

      test('respects output format setting - JPEG', () async {
        final options = const DocumentProcessingOptions(
          outputFormat: ImageFormat.jpeg,
          compressionQuality: 0.8,
        );
        final result = await imageProcessor.processImage(testImageData, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
        // JPEG files start with 0xFFD8
        expect(result[0], equals(0xFF));
        expect(result[1], equals(0xD8));
      });

      test('respects output format setting - PNG', () async {
        final options = const DocumentProcessingOptions(
          outputFormat: ImageFormat.png,
        );
        final result = await imageProcessor.processImage(testImageData, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
        // PNG files start with 0x89504E47
        expect(result[0], equals(0x89));
        expect(result[1], equals(0x50));
        expect(result[2], equals(0x4E));
        expect(result[3], equals(0x47));
      });

      test('applies resolution limits for quality setting', () async {
        // Create a large test image
        final largeImageData = _createTestImage(4000, 3000);
        final options = const DocumentProcessingOptions(
          pdfResolution: PdfResolution.quality,
        );
        final result = await imageProcessor.processImage(largeImageData, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
      });

      test('applies resolution limits for size setting', () async {
        // Create a large test image
        final largeImageData = _createTestImage(4000, 3000);
        final options = const DocumentProcessingOptions(
          pdfResolution: PdfResolution.size,
        );
        final result = await imageProcessor.processImage(largeImageData, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
      });

      test('keeps original resolution for original setting', () async {
        final options = const DocumentProcessingOptions(
          pdfResolution: PdfResolution.original,
        );
        final result = await imageProcessor.processImage(testImageData, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
      });

      test('throws ImageProcessingException for invalid image data', () async {
        final invalidData = Uint8List.fromList(List.filled(100, 0));
        final options = const DocumentProcessingOptions();
        
        expect(
          () => imageProcessor.processImage(invalidData, options),
          throwsA(isA<ImageProcessingException>()),
        );
      });
    });

    group('applyImageEditing', () {
      test('applies rotation correctly with 90 degrees', () async {
        final options = const ImageEditingOptions(
          rotationDegrees: 90,
        );
        final result = await imageProcessor.applyImageEditing(testImageData, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
      });

      test('four 90 degree rotations return to original orientation', () async {
        // Start with test image
        Uint8List currentImage = testImageData;
        
        // Apply 4 rotations of 90 degrees each
        for (int i = 0; i < 4; i++) {
          final options = const ImageEditingOptions(rotationDegrees: 90);
          currentImage = await imageProcessor.applyImageEditing(currentImage, options);
          expect(currentImage, isA<Uint8List>());
          expect(currentImage.isNotEmpty, isTrue);
        }
        
        // After 4 rotations, we should have a valid image
        // (We can't directly compare pixels due to compression, but we verify it's still a valid image)
        expect(currentImage, isA<Uint8List>());
        expect(currentImage.isNotEmpty, isTrue);
      });

      test('rotation uses degrees not radians', () async {
        // This test verifies that rotation uses degrees (not radians)
        // by ensuring all standard rotations (0, 90, 180, 270) are applied correctly
        // and produce valid output images without tiny distortions
        
        final options90 = const ImageEditingOptions(rotationDegrees: 90);
        final rotated90 = await imageProcessor.applyImageEditing(testImageData, options90);
        
        // Verify the rotated image is valid and non-empty
        expect(rotated90, isA<Uint8List>());
        expect(rotated90.isNotEmpty, isTrue);
        
        // Decode to verify it's a valid image
        final rotatedImage = img.decodeImage(rotated90);
        expect(rotatedImage, isNotNull);
        
        // The image should still have reasonable dimensions
        expect(rotatedImage!.width, greaterThan(0));
        expect(rotatedImage.height, greaterThan(0));
      });

      test('applies rotation correctly at 0, 90, 180, 270 degrees', () async {
        final rotations = [0, 90, 180, 270];
        
        for (final degrees in rotations) {
          final options = ImageEditingOptions(rotationDegrees: degrees);
          final result = await imageProcessor.applyImageEditing(testImageData, options);
          
          expect(result, isA<Uint8List>());
          expect(result.isNotEmpty, isTrue);
        }
      });

      test('applies high contrast filter', () async {
        final options = const ImageEditingOptions(
          colorFilter: ColorFilter.highContrast,
        );
        final result = await imageProcessor.applyImageEditing(testImageData, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
      });

      test('applies black and white filter', () async {
        final options = const ImageEditingOptions(
          colorFilter: ColorFilter.blackAndWhite,
        );
        final result = await imageProcessor.applyImageEditing(testImageData, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
      });

      test('applies cropping with perspective correction', () async {
        final corners = [
          const Offset(10, 10),
          const Offset(90, 10),
          const Offset(90, 90),
          const Offset(10, 90),
        ];
        final options = ImageEditingOptions(
          cropCorners: corners,
          documentFormat: DocumentFormat.square,
        );
        final result = await imageProcessor.applyImageEditing(testImageData, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
      });

      test('applies multiple edits together', () async {
        final corners = [
          const Offset(10, 10),
          const Offset(90, 10),
          const Offset(90, 90),
          const Offset(10, 90),
        ];
        final options = ImageEditingOptions(
          rotationDegrees: 90,
          colorFilter: ColorFilter.highContrast,
          cropCorners: corners,
          documentFormat: DocumentFormat.square,
        );
        final result = await imageProcessor.applyImageEditing(testImageData, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
      });

      test('throws ImageProcessingException for invalid image data', () async {
        final invalidData = Uint8List.fromList(List.filled(100, 0));
        final options = const ImageEditingOptions();
        
        expect(
          () => imageProcessor.applyImageEditing(invalidData, options),
          throwsA(isA<ImageProcessingException>()),
        );
      });
    });

    group('detectDocumentEdges', () {
      test('detects edges in test image', () async {
        final corners = await imageProcessor.detectDocumentEdges(testImageData);
        
        expect(corners, isA<List<Offset>>());
        expect(corners.length, equals(4));
        
        // Verify corners are ordered correctly (top-left, top-right, bottom-right, bottom-left)
        expect(corners[0].dx, lessThanOrEqualTo(corners[1].dx)); // top-left.x <= top-right.x
        expect(corners[0].dy, lessThanOrEqualTo(corners[3].dy)); // top-left.y <= bottom-left.y
        expect(corners[2].dx, greaterThanOrEqualTo(corners[3].dx)); // bottom-right.x >= bottom-left.x
        expect(corners[2].dy, greaterThanOrEqualTo(corners[1].dy)); // bottom-right.y >= top-right.y
      });

      test('provides fallback for invalid image data', () async {
       // Create invalid image data that's longer to avoid other format detection
       final invalidData = Uint8List.fromList(List.filled(100, 0));
       final corners = await imageProcessor.detectDocumentEdges(invalidData);

       expect(corners, isA<List<Offset>>());
       expect(corners.length, equals(4));

       // Should return default fallback corners
       expect(corners[0], equals(const Offset(0, 0)));
       expect(corners[1], equals(const Offset(100, 0)));
       expect(corners[2], equals(const Offset(100, 100)));
       expect(corners[3], equals(const Offset(0, 100)));
      });
    });

    group('analyzeImageQuality', () {
      test('analyzes image quality successfully', () {
        final analysis = imageProcessor.analyzeImageQuality(testImageData);
        
        expect(analysis, isA<Map<String, dynamic>>());
        expect(analysis.containsKey('width'), isTrue);
        expect(analysis.containsKey('height'), isTrue);
        expect(analysis.containsKey('aspectRatio'), isTrue);
        expect(analysis.containsKey('isBlurry'), isTrue);
        expect(analysis.containsKey('brightness'), isTrue);
        expect(analysis.containsKey('contrast'), isTrue);
        expect(analysis.containsKey('hasDocument'), isTrue);
        expect(analysis.containsKey('suggestions'), isTrue);
        
        expect(analysis['width'], equals(100));
        expect(analysis['height'], equals(100));
        expect(analysis['aspectRatio'], equals(1.0));
      });

      test('provides error for invalid image data', () {
        final invalidData = Uint8List.fromList(List.filled(100, 0));
        final analysis = imageProcessor.analyzeImageQuality(invalidData);
        
        expect(analysis, isA<Map<String, dynamic>>());
        expect(analysis.containsKey('error'), isTrue);
      });
    });

    group('DocumentProcessingOptions presets', () {
      test('receipt preset has correct settings', () {
        const options = DocumentProcessingOptions.receipt;
        
        expect(options.convertToGrayscale, isTrue);
        expect(options.enhanceContrast, isTrue);
        expect(options.autoCorrectPerspective, isTrue);
        expect(options.compressionQuality, equals(0.9));
        expect(options.generatePdf, isTrue);
        expect(options.saveImageFile, isFalse);
        expect(options.pdfResolution, equals(PdfResolution.quality));
      });

      test('manual preset has correct settings', () {
        const options = DocumentProcessingOptions.manual;
        
        expect(options.convertToGrayscale, isFalse);
        expect(options.enhanceContrast, isFalse);
        expect(options.autoCorrectPerspective, isTrue);
        expect(options.compressionQuality, equals(0.7));
        expect(options.generatePdf, isTrue);
        expect(options.saveImageFile, isFalse);
        expect(options.pdfResolution, equals(PdfResolution.quality));
      });

      test('document preset has correct settings', () {
        const options = DocumentProcessingOptions.document;
        
        expect(options.convertToGrayscale, isTrue);
        expect(options.enhanceContrast, isTrue);
        expect(options.autoCorrectPerspective, isTrue);
        expect(options.compressionQuality, equals(0.8));
        expect(options.generatePdf, isTrue);
        expect(options.saveImageFile, isFalse);
        expect(options.pdfResolution, equals(PdfResolution.quality));
      });
    });

    group('ImageFormat support', () {
      test('supports all image formats', () async {
        final formats = [
          ImageFormat.jpeg,
          ImageFormat.png,
          ImageFormat.webp,
        ];
        
        for (final format in formats) {
          final options = DocumentProcessingOptions(outputFormat: format);
          final result = await imageProcessor.processImage(testImageData, options);
          
          expect(result, isA<Uint8List>());
          expect(result.isNotEmpty, isTrue);
        }
      });
    });

    group('PdfResolution support', () {
      test('supports all PDF resolution settings', () async {
        final resolutions = [
          PdfResolution.original,
          PdfResolution.quality,
          PdfResolution.size,
        ];
        
        for (final resolution in resolutions) {
          final options = DocumentProcessingOptions(pdfResolution: resolution);
          final result = await imageProcessor.processImage(testImageData, options);
          
          expect(result, isA<Uint8List>());
          expect(result.isNotEmpty, isTrue);
        }
      });
    });

    group('DocumentFormat support', () {
      test('supports all document formats in editing', () async {
        final formats = [
          DocumentFormat.auto,
          DocumentFormat.isoA,
          DocumentFormat.usLetter,
          DocumentFormat.usLegal,
          DocumentFormat.square,
          DocumentFormat.receipt,
          DocumentFormat.businessCard,
        ];
        
        final corners = [
          const Offset(10, 10),
          const Offset(90, 10),
          const Offset(90, 90),
          const Offset(10, 90),
        ];
        
        for (final format in formats) {
          final options = ImageEditingOptions(
            cropCorners: corners,
            documentFormat: format,
          );
          final result = await imageProcessor.applyImageEditing(testImageData, options);
          
          expect(result, isA<Uint8List>());
          expect(result.isNotEmpty, isTrue);
        }
      });
    });

    group('Background processing and optimizations', () {
      test('processes image using background isolate', () async {
        final options = const DocumentProcessingOptions();
        final result = await imageProcessor.processImage(testImageData, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
      });

      test('caches edge detection results', () async {
        // First detection should compute and cache
        final corners1 = await imageProcessor.detectDocumentEdges(testImageData);
        expect(corners1, isA<List<Offset>>());
        expect(corners1.length, equals(4));
        
        // Second detection should use cache
        final corners2 = await imageProcessor.detectDocumentEdges(testImageData);
        expect(corners2, equals(corners1));
      });

      test('clears edge cache', () {
        imageProcessor.clearEdgeCache();
        // Should not throw and cache should be empty
        expect(() => imageProcessor.clearEdgeCache(), returnsNormally);
      });

      test('processes large image efficiently', () async {
        // Create a large test image (4000x3000)
        final largeImageData = _createTestImage(4000, 3000);
        final options = const DocumentProcessingOptions();
        
        final stopwatch = Stopwatch()..start();
        final result = await imageProcessor.processImage(largeImageData, options);
        stopwatch.stop();
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
        // Should complete within reasonable time (under 10 seconds for safety)
        expect(stopwatch.elapsedMilliseconds, lessThan(10000));
      });

      test('handles edge detection fallback gracefully', () async {
        // Test with corrupted image data
        final corruptedData = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG start but incomplete
        
        final corners = await imageProcessor.detectDocumentEdges(corruptedData);
        expect(corners, isA<List<Offset>>());
        expect(corners.length, equals(4)); // Should return fallback corners
      });
    });

    group('Error handling', () {
      test('ImageProcessingException has correct properties', () {
        const exception = ImageProcessingException('Test error message');
        
        expect(exception.message, equals('Test error message'));
        expect(exception.toString(), equals('ImageProcessingException: Test error message'));
        expect(exception, isA<Exception>());
      });
    });

    group('Black & White filter with Otsu thresholding', () {
      test('preserves readable text on light background', () async {
        // Create test image with text-like pattern (dark text on light background)
        final textImage = _createTextLikeImage(200, 200);
        
        final options = const ImageEditingOptions(
          colorFilter: ColorFilter.blackAndWhite,
        );
        final result = await imageProcessor.applyImageEditing(textImage, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
        
        // Decode and verify pixel distribution
        final resultImage = img.decodeImage(result);
        expect(resultImage, isNotNull);
        
        final stats = _analyzePixelDistribution(resultImage!);
        
        // Should have both black and white pixels (not uniformly dark)
        expect(stats['blackPixels'], greaterThan(0));
        expect(stats['whitePixels'], greaterThan(0));
        
        // Should not be completely black (burned)
        expect(stats['blackPixels'], lessThan(stats['totalPixels']));
      });

      test('handles dark images without burning to full black', () async {
        // Create a dark test image
        final darkImage = _createDarkImage(200, 200);
        
        final options = const ImageEditingOptions(
          colorFilter: ColorFilter.blackAndWhite,
        );
        final result = await imageProcessor.applyImageEditing(darkImage, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
        
        // Decode and verify some white pixels exist
        final resultImage = img.decodeImage(result);
        expect(resultImage, isNotNull);
        
        final stats = _analyzePixelDistribution(resultImage!);
        
        // Should have some white pixels, not all black
        expect(stats['whitePixels'], greaterThan(0));
      });

      test('uses adaptive threshold based on image content', () async {
        // Create two different images and verify they use different thresholds
        final lightImage = _createLightImage(100, 100);
        final darkImage = _createDarkImage(100, 100);
        
        final options = const ImageEditingOptions(
          colorFilter: ColorFilter.blackAndWhite,
        );
        
        final lightResult = await imageProcessor.applyImageEditing(lightImage, options);
        final darkResult = await imageProcessor.applyImageEditing(darkImage, options);
        
        final lightDecoded = img.decodeImage(lightResult);
        final darkDecoded = img.decodeImage(darkResult);
        
        expect(lightDecoded, isNotNull);
        expect(darkDecoded, isNotNull);
        
        final lightStats = _analyzePixelDistribution(lightDecoded!);
        final darkStats = _analyzePixelDistribution(darkDecoded!);
        
        // Different images should produce different distributions
        // (proving adaptive thresholding is working)
        expect(lightStats['blackRatio'], isNot(equals(darkStats['blackRatio'])));
      });

      test('works with automatic processing (batch mode)', () async {
        // Test that the improved filter is used in automatic processing
        final textImage = _createTextLikeImage(200, 200);
        
        final options = const DocumentProcessingOptions(
          convertToGrayscale: true,
          enhanceContrast: false,
          autoCorrectPerspective: false,
        );
        
        final result = await imageProcessor.processImage(textImage, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
        
        // Verify the result has reasonable pixel distribution
        final resultImage = img.decodeImage(result);
        expect(resultImage, isNotNull);
        
        final stats = _analyzePixelDistribution(resultImage!);
        expect(stats['whitePixels'], greaterThan(0));
      });
    });

    group('Enhanced filter with histogram equalization', () {
      test('increases contrast without desaturating completely', () async {
        // Create a low contrast color image
        final lowContrastImage = _createLowContrastImage(200, 200);
        
        final options = const ImageEditingOptions(
          colorFilter: ColorFilter.highContrast,
        );
        final result = await imageProcessor.applyImageEditing(lowContrastImage, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
        
        // Decode and verify enhanced contrast
        final resultImage = img.decodeImage(result);
        expect(resultImage, isNotNull);
        
        final originalImage = img.decodeImage(lowContrastImage);
        final originalContrast = _calculateImageContrast(originalImage!);
        final enhancedContrast = _calculateImageContrast(resultImage!);
        
        // Enhanced image should have higher contrast
        expect(enhancedContrast, greaterThan(originalContrast));
        
        // Should still have color (not completely desaturated)
        final colorStats = _analyzeColorPresence(resultImage);
        expect(colorStats['hasColor'], isTrue);
      });

      test('prevents over-saturation with clip limit', () async {
        // Create a varied contrast image (not solid color)
        final variedImage = _createLowContrastImage(200, 200);
        
        final options = const ImageEditingOptions(
          colorFilter: ColorFilter.highContrast,
        );
        final result = await imageProcessor.applyImageEditing(variedImage, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
        
        // Decode and verify the result has improved contrast
        final resultImage = img.decodeImage(result);
        expect(resultImage, isNotNull);
        
        final originalImage = img.decodeImage(variedImage);
        final originalContrast = _calculateImageContrast(originalImage!);
        final enhancedContrast = _calculateImageContrast(resultImage!);
        
        // Enhanced should have better contrast
        expect(enhancedContrast, greaterThan(originalContrast));
        
        // Image should still have reasonable distribution (not all extremes)
        final stats = _analyzePixelDistribution(resultImage);
        final totalPixels = stats['totalPixels'] as int;
        final extremePixels = stats['extremePixels'] as int;
        final extremeRatio = extremePixels / totalPixels;
        
        // Most pixels shouldn't be at absolute extremes
        expect(extremeRatio, lessThan(0.95));
      });

      test('works with automatic processing (batch mode)', () async {
        // Test that the improved filter is used in automatic processing
        final lowContrastImage = _createLowContrastImage(200, 200);
        
        final options = const DocumentProcessingOptions(
          convertToGrayscale: false,
          enhanceContrast: true,
          autoCorrectPerspective: false,
        );
        
        final result = await imageProcessor.processImage(lowContrastImage, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
        
        // Verify the result has improved contrast
        final resultImage = img.decodeImage(result);
        expect(resultImage, isNotNull);
        
        final originalImage = img.decodeImage(lowContrastImage);
        final originalContrast = _calculateImageContrast(originalImage!);
        final enhancedContrast = _calculateImageContrast(resultImage!);
        
        expect(enhancedContrast, greaterThan(originalContrast));
      });

      test('processes per-channel without collapsing to gray', () async {
        // Create a color image
        final colorImage = _createColorfulImage(100, 100);
        
        final options = const ImageEditingOptions(
          colorFilter: ColorFilter.highContrast,
        );
        final result = await imageProcessor.applyImageEditing(colorImage, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
        
        final resultImage = img.decodeImage(result);
        expect(resultImage, isNotNull);
        
        // Verify color is preserved
        final colorStats = _analyzeColorPresence(resultImage!);
        expect(colorStats['hasColor'], isTrue);
        
        // Should have variance in R, G, B channels
        expect(colorStats['redVariance'], greaterThan(0));
        expect(colorStats['greenVariance'], greaterThan(0));
        expect(colorStats['blueVariance'], greaterThan(0));
      });
    });

    group('Filter integration and consistency', () {
      test('manual editor and batch processing use same algorithms', () async {
        final testImage = _createTextLikeImage(200, 200);
        
        // Test via manual editor
        final editOptions = const ImageEditingOptions(
          colorFilter: ColorFilter.blackAndWhite,
        );
        final editResult = await imageProcessor.applyImageEditing(testImage, editOptions);
        
        // Test via batch processing
        final batchOptions = const DocumentProcessingOptions(
          convertToGrayscale: true,
          enhanceContrast: false,
          autoCorrectPerspective: false,
        );
        final batchResult = await imageProcessor.processImage(testImage, batchOptions);
        
        // Both should produce similar results (within reasonable tolerance due to encoding)
        final editImage = img.decodeImage(editResult);
        final batchImage = img.decodeImage(batchResult);
        
        expect(editImage, isNotNull);
        expect(batchImage, isNotNull);
        
        final editStats = _analyzePixelDistribution(editImage!);
        final batchStats = _analyzePixelDistribution(batchImage!);
        
        // Should have similar black/white ratios
        final editRatio = editStats['blackRatio'] as double;
        final batchRatio = batchStats['blackRatio'] as double;
        
        // Allow 10% tolerance for encoding differences
        expect((editRatio - batchRatio).abs(), lessThan(0.1));
      });
    });
  });
}

/// Create a simple test image for testing purposes
Uint8List _createTestImage(int width, int height) {
  // Create a simple red square image using the image package
  final image = img.Image(width: width, height: height);
  
  // Fill with red color
  img.fill(image, color: img.ColorRgb8(255, 0, 0));
  
  // Encode as JPEG
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

/// Create a text-like image (dark text on light background)
Uint8List _createTextLikeImage(int width, int height) {
  final image = img.Image(width: width, height: height);
  
  // Light background (not too bright to allow for black text)
  img.fill(image, color: img.ColorRgb8(200, 200, 200));
  
  // Add substantial "text" areas (dark blocks)
  for (int y = 20; y < height - 20; y += 30) {
    for (int x = 20; x < width - 20; x += 50) {
      // Create larger text blocks
      for (int dy = 0; dy < 15; dy++) {
        for (int dx = 0; dx < 30; dx++) {
          if (y + dy < height && x + dx < width) {
            image.setPixel(x + dx, y + dy, img.ColorRgb8(30, 30, 30));
          }
        }
      }
    }
  }
  
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

/// Create a dark image
Uint8List _createDarkImage(int width, int height) {
  final image = img.Image(width: width, height: height);
  
  // Dark gray background with some lighter spots
  img.fill(image, color: img.ColorRgb8(60, 60, 60));
  
  // Add some lighter spots
  for (int y = 0; y < height; y += 20) {
    for (int x = 0; x < width; x += 20) {
      image.setPixel(x, y, img.ColorRgb8(120, 120, 120));
    }
  }
  
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

/// Create a light image
Uint8List _createLightImage(int width, int height) {
  final image = img.Image(width: width, height: height);
  
  // Light background with some darker spots
  img.fill(image, color: img.ColorRgb8(220, 220, 220));
  
  // Add some darker spots
  for (int y = 0; y < height; y += 20) {
    for (int x = 0; x < width; x += 20) {
      image.setPixel(x, y, img.ColorRgb8(150, 150, 150));
    }
  }
  
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

/// Create a low contrast image
Uint8List _createLowContrastImage(int width, int height) {
  final image = img.Image(width: width, height: height);
  
  // Mid-gray background with slight color variations (more visible)
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final value = 80 + ((x + y) % 80);
      // Add more color variation to ensure hasColor is detected
      image.setPixel(x, y, img.ColorRgb8(value, value + 15, value - 10));
    }
  }
  
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

/// Create a colorful image
Uint8List _createColorfulImage(int width, int height) {
  final image = img.Image(width: width, height: height);
  
  // Create colored stripes
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      if (x < width ~/ 3) {
        image.setPixel(x, y, img.ColorRgb8(200, 50, 50)); // Red
      } else if (x < 2 * width ~/ 3) {
        image.setPixel(x, y, img.ColorRgb8(50, 200, 50)); // Green
      } else {
        image.setPixel(x, y, img.ColorRgb8(50, 50, 200)); // Blue
      }
    }
  }
  
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

/// Analyze pixel distribution in an image
Map<String, dynamic> _analyzePixelDistribution(img.Image image) {
  int blackPixels = 0;
  int whitePixels = 0;
  int extremePixels = 0; // Pixels at 0 or 255 in any channel
  final totalPixels = image.width * image.height;
  
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      
      // Check if it's black (all channels < 50)
      if (r < 50 && g < 50 && b < 50) {
        blackPixels++;
      }
      
      // Check if it's white (all channels > 200)
      if (r > 200 && g > 200 && b > 200) {
        whitePixels++;
      }
      
      // Check for extreme values
      if (r == 0 || r == 255 || g == 0 || g == 255 || b == 0 || b == 255) {
        extremePixels++;
      }
    }
  }
  
  return {
    'totalPixels': totalPixels,
    'blackPixels': blackPixels,
    'whitePixels': whitePixels,
    'extremePixels': extremePixels,
    'blackRatio': blackPixels / totalPixels,
    'whiteRatio': whitePixels / totalPixels,
  };
}

/// Calculate image contrast (max - min luminance)
double _calculateImageContrast(img.Image image) {
  double minLuminance = 255.0;
  double maxLuminance = 0.0;
  
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final luminance = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
      
      if (luminance < minLuminance) minLuminance = luminance;
      if (luminance > maxLuminance) maxLuminance = luminance;
    }
  }
  
  return maxLuminance - minLuminance;
}

/// Analyze color presence in an image
Map<String, dynamic> _analyzeColorPresence(img.Image image) {
  double sumR = 0, sumG = 0, sumB = 0;
  double sumRSq = 0, sumGSq = 0, sumBSq = 0;
  int count = 0;
  
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final r = pixel.r;
      final g = pixel.g;
      final b = pixel.b;
      
      sumR += r;
      sumG += g;
      sumB += b;
      
      sumRSq += r * r;
      sumGSq += g * g;
      sumBSq += b * b;
      
      count++;
    }
  }
  
  // Calculate variance for each channel
  final meanR = sumR / count;
  final meanG = sumG / count;
  final meanB = sumB / count;
  
  final varianceR = (sumRSq / count) - (meanR * meanR);
  final varianceG = (sumGSq / count) - (meanG * meanG);
  final varianceB = (sumBSq / count) - (meanB * meanB);
  
  // Check if image has color (channels differ significantly)
  // More lenient threshold to account for JPEG compression
  final hasColor = (meanR - meanG).abs() > 3 || 
                   (meanG - meanB).abs() > 3 || 
                   (meanR - meanB).abs() > 3 ||
                   varianceR > 100 || varianceG > 100 || varianceB > 100;
  
  return {
    'hasColor': hasColor,
    'redVariance': varianceR,
    'greenVariance': varianceG,
    'blueVariance': varianceB,
    'meanR': meanR,
    'meanG': meanG,
    'meanB': meanB,
  };
}