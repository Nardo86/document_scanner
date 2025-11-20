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
      test('applies rotation correctly', () async {
        final options = const ImageEditingOptions(
          rotationDegrees: 90,
        );
        final result = await imageProcessor.applyImageEditing(testImageData, options);
        
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
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
        expect(corners[1], equals(const Offset(400, 0)));
        expect(corners[2], equals(const Offset(400, 300)));
        expect(corners[3], equals(const Offset(0, 300)));
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

    group('Error handling', () {
      test('ImageProcessingException has correct properties', () {
        const exception = ImageProcessingException('Test error message');
        
        expect(exception.message, equals('Test error message'));
        expect(exception.toString(), equals('ImageProcessingException: Test error message'));
        expect(exception, isA<Exception>());
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