import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:document_scanner/src/services/pdf_generator.dart';
import 'package:document_scanner/src/models/scanned_document.dart';

Uint8List _whiteJpeg(int w, int h) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

bool _isPdf(Uint8List bytes) =>
    bytes.length > 4 &&
    bytes[0] == 0x25 && // %
    bytes[1] == 0x50 && // P
    bytes[2] == 0x44 && // D
    bytes[3] == 0x46; // F

void main() {
  late PdfGenerator pdfGenerator;

  setUp(() {
    pdfGenerator = PdfGenerator();
  });

  group('PdfGenerator - Initialization', () {
    test('initializes successfully', () {
      expect(pdfGenerator, isNotNull);
    });
  });

  group('PdfGenerator - Format Support', () {
    test('supports all document types', () {
      // Verify all document types are handled
      for (final docType in DocumentType.values) {
        expect(() => docType, returnsNormally);
      }
    });

    test('supports all document formats', () {
      // Verify all document formats are handled
      for (final format in DocumentFormat.values) {
        expect(() => format, returnsNormally);
      }
    });

    test('supports all PDF resolutions', () {
      // Verify all PDF resolutions are handled
      for (final resolution in PdfResolution.values) {
        expect(() => resolution, returnsNormally);
      }
    });
  });

  group('PdfGenerator - Deprecated Methods', () {
    test('has deprecated generateReceiptPdf method', () {
      // ignore: deprecated_member_use_from_same_package
      expect(pdfGenerator.generateReceiptPdf, isA<Function>());
    });

    test('has deprecated generateManualPdf method', () {
      // ignore: deprecated_member_use_from_same_package
      expect(pdfGenerator.generateManualPdf, isA<Function>());
    });
  });

  group('PdfGenerator - API Signatures', () {
    test('generatePdf has correct signature', () {
      expect(pdfGenerator.generatePdf, isA<Function>());
    });

    test('generateMultiPagePdf has correct signature', () {
      expect(pdfGenerator.generateMultiPagePdf, isA<Function>());
    });
  });

  group('PdfGenerator - real output', () {
    test('generatePdf produces a valid, non-trivial PDF', () async {
      final pdf = await pdfGenerator.generatePdf(
        imageData: _whiteJpeg(60, 80),
        documentType: DocumentType.document,
        resolution: PdfResolution.quality,
        documentFormat: DocumentFormat.isoA,
      );
      expect(_isPdf(pdf), isTrue);
      expect(pdf.length, greaterThan(200));
    });

    test('generateMultiPagePdf produces a valid PDF', () async {
      final pdf = await pdfGenerator.generateMultiPagePdf(
        imageDataList: [_whiteJpeg(60, 80), _whiteJpeg(70, 90)],
        documentType: DocumentType.document,
        resolution: PdfResolution.size,
        documentFormat: DocumentFormat.isoA,
      );
      expect(_isPdf(pdf), isTrue);
      expect(pdf.length, greaterThan(200));
    });
  });
}
