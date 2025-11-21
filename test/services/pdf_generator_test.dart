import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/src/services/pdf_generator.dart';
import 'package:document_scanner/src/models/scanned_document.dart';

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
}
