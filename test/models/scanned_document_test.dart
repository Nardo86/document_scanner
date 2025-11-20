import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/src/models/scanned_document.dart';
import 'package:document_scanner/src/models/document_page.dart';
import 'package:document_scanner/src/models/processing_options.dart';

void main() {
  group('ScannedDocument', () {
    test('creates single-page document with required parameters', () {
      final now = DateTime.now();
      const options = DocumentProcessingOptions();

      final doc = ScannedDocument(
        id: 'doc-1',
        type: DocumentType.document,
        originalPath: '/path/to/image.jpg',
        scanTime: now,
        processingOptions: options,
      );

      expect(doc.id, 'doc-1');
      expect(doc.type, DocumentType.document);
      expect(doc.originalPath, '/path/to/image.jpg');
      expect(doc.scanTime, now);
      expect(doc.processingOptions, options);
      expect(doc.isMultiPage, false);
      expect(doc.pages, isEmpty);
      expect(doc.metadata, isEmpty);
    });

    test('creates multi-page document', () {
      final now = DateTime.now();
      final page1 = DocumentPage(
        id: 'page-1',
        pageNumber: 1,
        originalPath: '/path/to/page1.jpg',
        scanTime: now,
      );
      final page2 = DocumentPage(
        id: 'page-2',
        pageNumber: 2,
        originalPath: '/path/to/page2.jpg',
        scanTime: now,
      );

      final doc = ScannedDocument(
        id: 'doc-1',
        type: DocumentType.document,
        originalPath: '/path/to/page1.jpg',
        scanTime: now,
        processingOptions: DocumentProcessingOptions.document,
        pages: [page1, page2],
        isMultiPage: true,
      );

      expect(doc.isMultiPage, true);
      expect(doc.pages.length, 2);
      expect(doc.pageCount, 2);
    });

    test('copyWith creates new instance with updated fields', () {
      final now = DateTime.now();
      final doc = ScannedDocument(
        id: 'doc-1',
        type: DocumentType.receipt,
        originalPath: '/path/to/original.jpg',
        scanTime: now,
        processingOptions: DocumentProcessingOptions.receipt,
      );

      final updated = doc.copyWith(
        processedPath: '/path/to/processed.jpg',
        pdfPath: '/path/to/doc.pdf',
        metadata: {'pages': 1},
      );

      expect(updated.id, doc.id);
      expect(updated.type, doc.type);
      expect(updated.originalPath, doc.originalPath);
      expect(updated.processedPath, '/path/to/processed.jpg');
      expect(updated.pdfPath, '/path/to/doc.pdf');
      expect(updated.metadata, {'pages': 1});
      expect(doc.processedPath, isNull);
    });

    test('pageCount returns correct value', () {
      final now = DateTime.now();
      final page = DocumentPage(
        id: 'page-1',
        pageNumber: 1,
        originalPath: '/path/to/page.jpg',
        scanTime: now,
      );

      final singlePage = ScannedDocument(
        id: 'doc-1',
        type: DocumentType.document,
        originalPath: '/path/to/page.jpg',
        scanTime: now,
        processingOptions: DocumentProcessingOptions.document,
      );
      expect(singlePage.pageCount, 1);

      final multiPage = ScannedDocument(
        id: 'doc-1',
        type: DocumentType.document,
        originalPath: '/path/to/page.jpg',
        scanTime: now,
        processingOptions: DocumentProcessingOptions.document,
        pages: [page],
        isMultiPage: true,
      );
      expect(multiPage.pageCount, 1);
    });

    test('isProcessed returns correct value', () {
      final now = DateTime.now();
      final doc = ScannedDocument(
        id: 'doc-1',
        type: DocumentType.document,
        originalPath: '/path/to/original.jpg',
        scanTime: now,
        processingOptions: DocumentProcessingOptions.document,
      );

      expect(doc.isProcessed, false);

      final processed = doc.copyWith(
        processedPath: '/path/to/processed.jpg',
      );
      expect(processed.isProcessed, true);
    });

    test('hasPdfOutput returns correct value', () {
      final now = DateTime.now();
      final doc = ScannedDocument(
        id: 'doc-1',
        type: DocumentType.document,
        originalPath: '/path/to/image.jpg',
        scanTime: now,
        processingOptions: DocumentProcessingOptions.document,
      );

      expect(doc.hasPdfOutput, false);

      final withPdf = doc.copyWith(
        pdfPath: '/path/to/doc.pdf',
      );
      expect(withPdf.hasPdfOutput, true);
    });

    test('toJson serializes all fields', () {
      final now = DateTime(2024, 1, 15, 10, 30, 0);
      final doc = ScannedDocument(
        id: 'doc-1',
        type: DocumentType.receipt,
        originalPath: '/path/to/image.jpg',
        scanTime: now,
        processingOptions: DocumentProcessingOptions.receipt,
        processedPath: '/path/to/processed.jpg',
        pdfPath: '/path/to/doc.pdf',
        metadata: {'source': 'camera'},
      );

      final json = doc.toJson();

      expect(json['id'], 'doc-1');
      expect(json['type'], 'DocumentType.receipt');
      expect(json['originalPath'], '/path/to/image.jpg');
      expect(json['processedPath'], '/path/to/processed.jpg');
      expect(json['pdfPath'], '/path/to/doc.pdf');
      expect(json['scanTime'], '2024-01-15T10:30:00.000');
      expect(json['metadata'], {'source': 'camera'});
      expect(json['isMultiPage'], false);
    });

    test('toJson excludes binary data', () {
      final now = DateTime.now();
      final doc = ScannedDocument(
        id: 'doc-1',
        type: DocumentType.document,
        originalPath: '/path/to/image.jpg',
        scanTime: now,
        processingOptions: DocumentProcessingOptions.document,
        rawImageData: null,
        processedImageData: null,
        pdfData: null,
      );

      final json = doc.toJson();

      expect(json.containsKey('rawImageData'), false);
      expect(json.containsKey('processedImageData'), false);
      expect(json.containsKey('pdfData'), false);
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'id': 'doc-1',
        'type': 'DocumentType.receipt',
        'originalPath': '/path/to/image.jpg',
        'processedPath': '/path/to/processed.jpg',
        'pdfPath': '/path/to/doc.pdf',
        'scanTime': '2024-01-15T10:30:00.000Z',
        'processingOptions': {
          'convertToGrayscale': true,
          'enhanceContrast': true,
        },
        'metadata': {'source': 'camera'},
        'isMultiPage': false,
      };

      final doc = ScannedDocument.fromJson(json);

      expect(doc.id, 'doc-1');
      expect(doc.type, DocumentType.receipt);
      expect(doc.originalPath, '/path/to/image.jpg');
      expect(doc.processedPath, '/path/to/processed.jpg');
      expect(doc.pdfPath, '/path/to/doc.pdf');
      expect(doc.metadata, {'source': 'camera'});
      expect(doc.isMultiPage, false);
    });

    test('fromJson handles multi-page documents', () {
      final json = {
        'id': 'doc-1',
        'type': 'DocumentType.document',
        'originalPath': '/path/to/page1.jpg',
        'scanTime': '2024-01-15T10:30:00.000Z',
        'processingOptions': {},
        'pages': [
          {
            'id': 'page-1',
            'pageNumber': 1,
            'originalPath': '/path/to/page1.jpg',
            'scanTime': '2024-01-15T10:30:00.000Z',
          },
          {
            'id': 'page-2',
            'pageNumber': 2,
            'originalPath': '/path/to/page2.jpg',
            'scanTime': '2024-01-15T10:35:00.000Z',
          },
        ],
        'isMultiPage': true,
      };

      final doc = ScannedDocument.fromJson(json);

      expect(doc.isMultiPage, true);
      expect(doc.pages.length, 2);
      expect(doc.pages[0].id, 'page-1');
      expect(doc.pages[1].id, 'page-2');
    });

    test('toMap is alias for toJson', () {
      final now = DateTime.now();
      final doc = ScannedDocument(
        id: 'doc-1',
        type: DocumentType.document,
        originalPath: '/path/to/image.jpg',
        scanTime: now,
        processingOptions: DocumentProcessingOptions.document,
      );

      expect(doc.toMap(), doc.toJson());
    });

    test('roundtrip serialization preserves data', () {
      final now = DateTime(2024, 1, 15, 10, 30, 0);
      final original = ScannedDocument(
        id: 'doc-1',
        type: DocumentType.receipt,
        originalPath: '/path/to/image.jpg',
        scanTime: now,
        processingOptions: DocumentProcessingOptions.receipt,
        processedPath: '/path/to/processed.jpg',
        metadata: {'resolution': 300, 'source': 'camera'},
      );

      final json = original.toJson();
      final restored = ScannedDocument.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.type, original.type);
      expect(restored.originalPath, original.originalPath);
      expect(restored.processedPath, original.processedPath);
      expect(restored.metadata, original.metadata);
    });

    test('metadata propagation from session', () {
      final now = DateTime.now();
      final doc = ScannedDocument(
        id: 'doc-1',
        type: DocumentType.document,
        originalPath: '/path/to/image.jpg',
        scanTime: now,
        processingOptions: DocumentProcessingOptions.document,
        metadata: {
          'pageCount': 5,
          'sessionStartTime': now.toIso8601String(),
          'customFilename': 'my_document',
        },
      );

      expect(doc.metadata['pageCount'], 5);
      expect(doc.metadata['customFilename'], 'my_document');
      expect(doc.metadata.containsKey('sessionStartTime'), true);
    });
  });

  group('ColorFilter', () {
    test('has correct enum values', () {
      expect(
        ColorFilter.values,
        [ColorFilter.none, ColorFilter.highContrast, ColorFilter.blackAndWhite],
      );
    });
  });

  group('ImageEditingOptions', () {
    test('creates with defaults', () {
      const options = ImageEditingOptions();

      expect(options.rotationDegrees, 0);
      expect(options.colorFilter, ColorFilter.none);
      expect(options.cropCorners, isNull);
      expect(options.documentFormat, DocumentFormat.auto);
    });

    test('creates with custom values', () {
      const options = ImageEditingOptions(
        rotationDegrees: 90,
        colorFilter: ColorFilter.highContrast,
        documentFormat: DocumentFormat.isoA,
      );

      expect(options.rotationDegrees, 90);
      expect(options.colorFilter, ColorFilter.highContrast);
      expect(options.documentFormat, DocumentFormat.isoA);
    });

    test('copyWith creates new instance', () {
      const original = ImageEditingOptions(
        rotationDegrees: 0,
        colorFilter: ColorFilter.none,
      );

      final updated = original.copyWith(
        rotationDegrees: 180,
        colorFilter: ColorFilter.blackAndWhite,
      );

      expect(updated.rotationDegrees, 180);
      expect(updated.colorFilter, ColorFilter.blackAndWhite);
      expect(original.rotationDegrees, 0);
    });
  });
}
