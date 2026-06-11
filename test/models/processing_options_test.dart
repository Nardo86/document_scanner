import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/src/models/scanned_document.dart';

void main() {
  group('DocumentProcessingOptions JSON round-trip', () {
    test('preserves documentFormat (regression)', () {
      const options = DocumentProcessingOptions(
        convertToGrayscale: false,
        enhanceContrast: true,
        autoCorrectPerspective: false,
        compressionQuality: 0.6,
        outputFormat: ImageFormat.png,
        generatePdf: false,
        saveImageFile: true,
        pdfResolution: PdfResolution.original,
        documentFormat: DocumentFormat.usLegal,
        customFilename: 'invoice',
      );

      final restored = DocumentProcessingOptions.fromJson(options.toJson());

      expect(restored.documentFormat, DocumentFormat.usLegal);
      expect(restored.outputFormat, ImageFormat.png);
      expect(restored.pdfResolution, PdfResolution.original);
      expect(restored.convertToGrayscale, false);
      expect(restored.enhanceContrast, true);
      expect(restored.autoCorrectPerspective, false);
      expect(restored.generatePdf, false);
      expect(restored.saveImageFile, true);
      expect(restored.customFilename, 'invoice');
    });

    test('null documentFormat survives round-trip', () {
      const options = DocumentProcessingOptions();
      final restored = DocumentProcessingOptions.fromJson(options.toJson());
      expect(restored.documentFormat, isNull);
    });
  });

  group('ImageEditingOptions.copyWith', () {
    test('can clear crop corners with clearCropCorners', () {
      final withCrop = const ImageEditingOptions().copyWith(
        cropCorners: const [
          Offset(0, 0),
          Offset(10, 0),
          Offset(10, 10),
          Offset(0, 10),
        ],
      );
      expect(withCrop.cropCorners, isNotNull);

      final cleared = withCrop.copyWith(clearCropCorners: true);
      expect(cleared.cropCorners, isNull);
    });

    test('keeps crop corners when not clearing', () {
      final withCrop = const ImageEditingOptions().copyWith(
        cropCorners: const [Offset(1, 1), Offset(2, 2), Offset(3, 3), Offset(4, 4)],
      );
      final rotated = withCrop.copyWith(rotationDegrees: 90);
      expect(rotated.cropCorners, hasLength(4));
      expect(rotated.rotationDegrees, 90);
    });
  });
}
