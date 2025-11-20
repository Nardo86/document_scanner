import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/src/models/processing_options.dart';

void main() {
  group('DocumentProcessingOptions', () {
    test('creates with default options', () {
      const options = DocumentProcessingOptions();

      expect(options.convertToGrayscale, true);
      expect(options.enhanceContrast, true);
      expect(options.autoCorrectPerspective, true);
      expect(options.compressionQuality, 0.8);
      expect(options.outputFormat, ImageFormat.jpeg);
      expect(options.generatePdf, true);
      expect(options.saveImageFile, false);
      expect(options.pdfResolution, PdfResolution.quality);
      expect(options.documentFormat, isNull);
      expect(options.customFilename, isNull);
    });

    test('creates with custom options', () {
      const options = DocumentProcessingOptions(
        convertToGrayscale: false,
        enhanceContrast: false,
        compressionQuality: 0.9,
        outputFormat: ImageFormat.png,
        pdfResolution: PdfResolution.size,
        documentFormat: DocumentFormat.isoA,
        customFilename: 'my_doc',
      );

      expect(options.convertToGrayscale, false);
      expect(options.enhanceContrast, false);
      expect(options.compressionQuality, 0.9);
      expect(options.outputFormat, ImageFormat.png);
      expect(options.pdfResolution, PdfResolution.size);
      expect(options.documentFormat, DocumentFormat.isoA);
      expect(options.customFilename, 'my_doc');
    });

    test('receipt preset has correct values', () {
      const receipt = DocumentProcessingOptions.receipt;

      expect(receipt.convertToGrayscale, true);
      expect(receipt.enhanceContrast, true);
      expect(receipt.compressionQuality, 0.9);
      expect(receipt.generatePdf, true);
      expect(receipt.saveImageFile, false);
      expect(receipt.pdfResolution, PdfResolution.quality);
    });

    test('manual preset has correct values', () {
      const manual = DocumentProcessingOptions.manual;

      expect(manual.convertToGrayscale, false);
      expect(manual.enhanceContrast, false);
      expect(manual.compressionQuality, 0.7);
      expect(manual.generatePdf, true);
    });

    test('document preset has correct values', () {
      const document = DocumentProcessingOptions.document;

      expect(document.convertToGrayscale, true);
      expect(document.enhanceContrast, true);
      expect(document.compressionQuality, 0.8);
      expect(document.generatePdf, true);
    });

    test('copyWith creates new instance with updated fields', () {
      const original = DocumentProcessingOptions.receipt;
      final updated = original.copyWith(
        compressionQuality: 0.95,
        customFilename: 'special_receipt',
      );

      expect(updated.compressionQuality, 0.95);
      expect(updated.customFilename, 'special_receipt');
      expect(updated.convertToGrayscale, original.convertToGrayscale);
      expect(updated.enhanceContrast, original.enhanceContrast);
    });

    test('toJson serializes all fields correctly', () {
      const options = DocumentProcessingOptions(
        convertToGrayscale: true,
        enhanceContrast: false,
        compressionQuality: 0.85,
        outputFormat: ImageFormat.webp,
        pdfResolution: PdfResolution.size,
        documentFormat: DocumentFormat.usLetter,
        customFilename: 'test_doc',
      );

      final json = options.toJson();

      expect(json['convertToGrayscale'], true);
      expect(json['enhanceContrast'], false);
      expect(json['compressionQuality'], 0.85);
      expect(json['outputFormat'], 'ImageFormat.webp');
      expect(json['pdfResolution'], 'PdfResolution.size');
      expect(json['documentFormat'], 'DocumentFormat.usLetter');
      expect(json['customFilename'], 'test_doc');
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'convertToGrayscale': false,
        'enhanceContrast': true,
        'autoCorrectPerspective': false,
        'compressionQuality': 0.75,
        'outputFormat': 'ImageFormat.png',
        'generatePdf': false,
        'saveImageFile': true,
        'pdfResolution': 'PdfResolution.original',
        'documentFormat': 'DocumentFormat.square',
        'customFilename': 'restored_doc',
      };

      final options = DocumentProcessingOptions.fromJson(json);

      expect(options.convertToGrayscale, false);
      expect(options.enhanceContrast, true);
      expect(options.autoCorrectPerspective, false);
      expect(options.compressionQuality, 0.75);
      expect(options.outputFormat, ImageFormat.png);
      expect(options.generatePdf, false);
      expect(options.saveImageFile, true);
      expect(options.pdfResolution, PdfResolution.original);
      expect(options.documentFormat, DocumentFormat.square);
      expect(options.customFilename, 'restored_doc');
    });

    test('fromJson handles missing fields with defaults', () {
      final json = {
        'compressionQuality': 0.9,
      };

      final options = DocumentProcessingOptions.fromJson(json);

      expect(options.compressionQuality, 0.9);
      expect(options.convertToGrayscale, true);
      expect(options.enhanceContrast, true);
      expect(options.generatePdf, true);
    });

    test('roundtrip serialization preserves data', () {
      const original = DocumentProcessingOptions(
        convertToGrayscale: false,
        enhanceContrast: true,
        compressionQuality: 0.88,
        outputFormat: ImageFormat.webp,
        pdfResolution: PdfResolution.size,
        documentFormat: DocumentFormat.businessCard,
        customFilename: 'my_document',
      );

      final json = original.toJson();
      final restored = DocumentProcessingOptions.fromJson(json);

      expect(restored.convertToGrayscale, original.convertToGrayscale);
      expect(restored.enhanceContrast, original.enhanceContrast);
      expect(restored.compressionQuality, original.compressionQuality);
      expect(restored.outputFormat, original.outputFormat);
      expect(restored.pdfResolution, original.pdfResolution);
      expect(restored.documentFormat, original.documentFormat);
      expect(restored.customFilename, original.customFilename);
    });

    test('ImageFormat enum values are correct', () {
      expect(ImageFormat.values, [ImageFormat.jpeg, ImageFormat.png, ImageFormat.webp]);
    });

    test('DocumentFormat enum values are correct', () {
      expect(
        DocumentFormat.values,
        [
          DocumentFormat.auto,
          DocumentFormat.isoA,
          DocumentFormat.usLetter,
          DocumentFormat.usLegal,
          DocumentFormat.square,
          DocumentFormat.receipt,
          DocumentFormat.businessCard,
        ],
      );
    });

    test('PdfResolution enum values are correct', () {
      expect(
        PdfResolution.values,
        [PdfResolution.original, PdfResolution.quality, PdfResolution.size],
      );
    });
  });
}
