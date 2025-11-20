import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/src/services/image_processor.dart';
import 'package:document_scanner/src/models/scanned_document.dart';
import '../../test_utils.dart';

void main() {
  group('ImageProcessor Tests', () {
    late ImageProcessor imageProcessor;
    late Uint8List testImageData;

    setUpAll(() async {
      imageProcessor = ImageProcessor();
      testImageData = TestUtils.createTestPngImage();
    });

    group('Image Processing Tests', () {
      test('should process image with receipt options', () async {
        const options = DocumentProcessingOptions(
          convertToGrayscale: true,
          enhanceContrast: true,
          autoCorrectPerspective: true,
          compressionQuality: 0.9,
          generatePdf: true,
          saveImageFile: false,
          pdfResolution: PdfResolution.quality,
        );
        
        final result = await imageProcessor.processImage(
          testImageData,
          options,
        );
        
        expect(result, isNotNull);
        expect(result!.isNotEmpty, isTrue);
      });

      test('should process image with manual options', () async {
        const options = DocumentProcessingOptions(
          convertToGrayscale: false,
          enhanceContrast: false,
          autoCorrectPerspective: true,
          compressionQuality: 0.7,
          generatePdf: true,
          saveImageFile: false,
          pdfResolution: PdfResolution.quality,
        );
        
        final result = await imageProcessor.processImage(
          testImageData,
          options,
        );
        
        expect(result, isNotNull);
        expect(result!.isNotEmpty, isTrue);
      });

      test('should process image with custom options', () async {
        const options = DocumentProcessingOptions(
          convertToGrayscale: true,
          enhanceContrast: true,
          autoCorrectPerspective: false,
          compressionQuality: 0.8,
          generatePdf: true,
          saveImageFile: false,
          pdfResolution: PdfResolution.size,
        );
        
        final result = await imageProcessor.processImage(
          testImageData,
          options,
        );
        
        expect(result, isNotNull);
        expect(result!.isNotEmpty, isTrue);
      });

      test('should return original image when no processing needed', () async {
        const options = DocumentProcessingOptions(
          convertToGrayscale: false,
          enhanceContrast: false,
          autoCorrectPerspective: false,
          compressionQuality: 0.95, // High quality, no processing needed
          generatePdf: true,
          saveImageFile: false,
          pdfResolution: PdfResolution.original,
        );
        
        final result = await imageProcessor.processImage(
          testImageData,
          options,
        );
        
        expect(result, isNotNull);
        expect(result!.isNotEmpty, isTrue);
      });
    });

    group('Image Editing Tests', () {
      test('should apply rotation with image editing', () async {
        const editingOptions = ImageEditingOptions(
          rotationDegrees: 90,
          colorFilter: ColorFilter.none,
        );
        
        final result = await imageProcessor.applyImageEditing(
          testImageData,
          editingOptions,
        );
        
        expect(result, isNotNull);
        expect(result!.isNotEmpty, isTrue);
      });

      test('should apply high contrast filter', () async {
        const editingOptions = ImageEditingOptions(
          rotationDegrees: 0,
          colorFilter: ColorFilter.highContrast,
        );
        
        final result = await imageProcessor.applyImageEditing(
          testImageData,
          editingOptions,
        );
        
        expect(result, isNotNull);
        expect(result!.isNotEmpty, isTrue);
      });

      test('should apply black and white filter', () async {
        const editingOptions = ImageEditingOptions(
          rotationDegrees: 0,
          colorFilter: ColorFilter.blackAndWhite,
        );
        
        final result = await imageProcessor.applyImageEditing(
          testImageData,
          editingOptions,
        );
        
        expect(result, isNotNull);
        expect(result!.isNotEmpty, isTrue);
      });

      test('should apply cropping with corner points', () async {
        final editingOptions = ImageEditingOptions(
          rotationDegrees: 0,
          colorFilter: ColorFilter.none,
          cropCorners: TestUtils.createTestCorners(),
          documentFormat: DocumentFormat.isoA,
        );
        
        final result = await imageProcessor.applyImageEditing(
          testImageData,
          editingOptions,
        );
        
        expect(result, isNotNull);
        expect(result!.isNotEmpty, isTrue);
      });

      test('should apply combined editing options', () async {
        final editingOptions = ImageEditingOptions(
          rotationDegrees: 90,
          colorFilter: ColorFilter.highContrast,
          cropCorners: TestUtils.createTestCorners(),
          documentFormat: DocumentFormat.usLetter,
        );
        
        final result = await imageProcessor.applyImageEditing(
          testImageData,
          editingOptions,
        );
        
        expect(result, isNotNull);
        expect(result!.isNotEmpty, isTrue);
      });

      test('should handle invalid rotation gracefully', () async {
        const editingOptions = ImageEditingOptions(
          rotationDegrees: 45, // Invalid rotation
          colorFilter: ColorFilter.none,
        );
        
        // Should handle invalid rotation or default to 0
        final result = await imageProcessor.applyImageEditing(
          testImageData,
          editingOptions,
        );
        
        expect(result, isNotNull);
        expect(result!.isNotEmpty, isTrue);
      });

      test('should handle incomplete corner points', () async {
        final incompleteCorners = [
          const Offset(10, 10),
          const Offset(110, 10),
          const Offset(110, 160),
          // Missing 4th corner
        ];
        
        final editingOptions = ImageEditingOptions(
          rotationDegrees: 0,
          colorFilter: ColorFilter.none,
          cropCorners: incompleteCorners,
        );
        
        // Should handle incomplete corners gracefully
        final result = await imageProcessor.applyImageEditing(
          testImageData,
          editingOptions,
        );
        
        expect(result, isNotNull);
        expect(result!.isNotEmpty, isTrue);
      });
    });

    group('Document Format Tests', () {
      test('should handle different document formats in editing', () async {
        const formats = [
          DocumentFormat.isoA,
          DocumentFormat.usLetter,
          DocumentFormat.usLegal,
          DocumentFormat.square,
          DocumentFormat.receipt,
          DocumentFormat.businessCard,
        ];
        
        for (final format in formats) {
          final editingOptions = ImageEditingOptions(
            rotationDegrees: 0,
            colorFilter: ColorFilter.none,
            cropCorners: TestUtils.createTestCorners(),
            documentFormat: format,
          );
          
          final result = await imageProcessor.applyImageEditing(
            testImageData,
            editingOptions,
          );
          
          expect(result, isNotNull);
          expect(result!.isNotEmpty, isTrue);
        }
      });
    });

    group('Error Handling Tests', () {
      test('should handle empty image data gracefully', () async {
        const options = DocumentProcessingOptions();
        final emptyData = Uint8List(0);
        
        expect(
          () async => await imageProcessor.processImage(emptyData, options),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle corrupted image data gracefully', () async {
        const options = DocumentProcessingOptions();
        final corruptedData = TestUtils.createInvalidImageData();
        
        expect(
          () async => await imageProcessor.processImage(corruptedData, options),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle invalid editing options gracefully', () async {
        const editingOptions = ImageEditingOptions(
          rotationDegrees: 0,
          colorFilter: ColorFilter.none,
        );
        
        // Test with empty image data
        final emptyData = Uint8List(0);
        
        expect(
          () async => await imageProcessor.applyImageEditing(emptyData, editingOptions),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Performance Tests', () {
      test('should complete image processing within reasonable time', () async {
        const options = DocumentProcessingOptions(
          convertToGrayscale: true,
          enhanceContrast: true,
          autoCorrectPerspective: true,
          compressionQuality: 0.8,
          generatePdf: true,
          saveImageFile: false,
          pdfResolution: PdfResolution.quality,
        );
        
        final stopwatch = Stopwatch()..start();
        
        await imageProcessor.processImage(testImageData, options);
        
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(10000)); // 10 seconds max
      });

      test('should complete image editing within reasonable time', () async {
        final editingOptions = ImageEditingOptions(
          rotationDegrees: 90,
          colorFilter: ColorFilter.highContrast,
          cropCorners: TestUtils.createTestCorners(),
        );
        
        final stopwatch = Stopwatch()..start();
        
        await imageProcessor.applyImageEditing(testImageData, editingOptions);
        
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // 5 seconds max
      });
    });

    group('Integration Tests', () {
      test('should handle complete processing pipeline', () async {
        // First apply editing
        final editingOptions = ImageEditingOptions(
          rotationDegrees: 90,
          colorFilter: ColorFilter.highContrast,
          cropCorners: TestUtils.createTestCorners(),
        );
        
        final editedImage = await imageProcessor.applyImageEditing(
          testImageData,
          editingOptions,
        );
        
        expect(editedImage, isNotNull);
        expect(editedImage!.isNotEmpty, isTrue);
        
        // Then process with document options
        const processingOptions = DocumentProcessingOptions(
          convertToGrayscale: true,
          enhanceContrast: true,
          autoCorrectPerspective: false, // Already cropped
          compressionQuality: 0.8,
          generatePdf: true,
          saveImageFile: false,
          pdfResolution: PdfResolution.quality,
        );
        
        final finalImage = await imageProcessor.processImage(
          editedImage,
          processingOptions,
        );
        
        expect(finalImage, isNotNull);
        expect(finalImage!.isNotEmpty, isTrue);
      });

      test('should process different image types', () async {
        final pngImage = TestUtils.createTestPngImage();
        final jpegImage = TestUtils.createTestJpegImage();
        
        const options = DocumentProcessingOptions(
          convertToGrayscale: true,
          enhanceContrast: true,
          autoCorrectPerspective: true,
          compressionQuality: 0.8,
          generatePdf: true,
          saveImageFile: false,
          pdfResolution: PdfResolution.quality,
        );
        
        // Test PNG
        final pngResult = await imageProcessor.processImage(pngImage, options);
        expect(pngResult, isNotNull);
        expect(pngResult!.isNotEmpty, isTrue);
        
        // Test JPEG
        final jpegResult = await imageProcessor.processImage(jpegImage, options);
        expect(jpegResult, isNotNull);
        expect(jpegResult!.isNotEmpty, isTrue);
      });
    });
  });
}