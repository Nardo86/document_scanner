import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/src/models/multi_page_scan_session.dart';
import 'package:document_scanner/src/models/document_page.dart';
import 'package:document_scanner/src/models/processing_options.dart';
import 'package:document_scanner/src/models/scanned_document.dart';

void main() {
  group('MultiPageScanSession', () {
    test('creates empty session with required parameters', () {
      final now = DateTime.now();
      const options = DocumentProcessingOptions();

      final session = MultiPageScanSession(
        sessionId: 'session-1',
        documentType: DocumentType.document,
        processingOptions: options,
        startTime: now,
      );

      expect(session.sessionId, 'session-1');
      expect(session.documentType, DocumentType.document);
      expect(session.processingOptions, options);
      expect(session.startTime, now);
      expect(session.pages, isEmpty);
      expect(session.customFilename, isNull);
    });

    test('creates with optional custom filename', () {
      final now = DateTime.now();
      const options = DocumentProcessingOptions();

      final session = MultiPageScanSession(
        sessionId: 'session-1',
        documentType: DocumentType.document,
        processingOptions: options,
        startTime: now,
        customFilename: 'my_document',
      );

      expect(session.customFilename, 'my_document');
    });

    test('addPage adds a page to the session', () {
      final now = DateTime.now();
      const options = DocumentProcessingOptions();
      var session = MultiPageScanSession(
        sessionId: 'session-1',
        documentType: DocumentType.document,
        processingOptions: options,
        startTime: now,
      );

      final page = DocumentPage(
        id: 'page-1',
        pageNumber: 1,
        originalPath: '/path/to/page1.jpg',
        scanTime: now,
      );

      session = session.addPage(page);

      expect(session.pages.length, 1);
      expect(session.pages[0].id, 'page-1');
      expect(session.pageCount, 1);
    });

    test('addPage maintains insertion order', () {
      final now = DateTime.now();
      const options = DocumentProcessingOptions();
      var session = MultiPageScanSession(
        sessionId: 'session-1',
        documentType: DocumentType.document,
        processingOptions: options,
        startTime: now,
      );

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
      final page3 = DocumentPage(
        id: 'page-3',
        pageNumber: 3,
        originalPath: '/path/to/page3.jpg',
        scanTime: now,
      );

      session = session.addPage(page1).addPage(page2).addPage(page3);

      expect(session.pageCount, 3);
      expect(session.pages[0].id, 'page-1');
      expect(session.pages[1].id, 'page-2');
      expect(session.pages[2].id, 'page-3');
    });

    test('removePage removes a page by id', () {
      final now = DateTime.now();
      const options = DocumentProcessingOptions();

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

      var session = MultiPageScanSession(
        sessionId: 'session-1',
        documentType: DocumentType.document,
        processingOptions: options,
        startTime: now,
        pages: [page1, page2],
      );

      session = session.removePage('page-1');

      expect(session.pageCount, 1);
      expect(session.pages[0].id, 'page-2');
    });

    test('removePage handles non-existent page id', () {
      final now = DateTime.now();
      const options = DocumentProcessingOptions();

      final page = DocumentPage(
        id: 'page-1',
        pageNumber: 1,
        originalPath: '/path/to/page1.jpg',
        scanTime: now,
      );

      var session = MultiPageScanSession(
        sessionId: 'session-1',
        documentType: DocumentType.document,
        processingOptions: options,
        startTime: now,
        pages: [page],
      );

      final updated = session.removePage('non-existent');

      expect(updated.pageCount, 1);
    });

    test('reorderPages changes page order', () {
      final now = DateTime.now();
      const options = DocumentProcessingOptions();

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
      final page3 = DocumentPage(
        id: 'page-3',
        pageNumber: 3,
        originalPath: '/path/to/page3.jpg',
        scanTime: now,
      );

      var session = MultiPageScanSession(
        sessionId: 'session-1',
        documentType: DocumentType.document,
        processingOptions: options,
        startTime: now,
        pages: [page1, page2, page3],
      );

      session = session.reorderPages([page3, page1, page2]);

      expect(session.pages[0].id, 'page-3');
      expect(session.pages[1].id, 'page-1');
      expect(session.pages[2].id, 'page-2');
    });

    test('isReadyForFinalization returns false when empty', () {
      final now = DateTime.now();
      const options = DocumentProcessingOptions();

      final session = MultiPageScanSession(
        sessionId: 'session-1',
        documentType: DocumentType.document,
        processingOptions: options,
        startTime: now,
      );

      expect(session.isReadyForFinalization, false);
    });

    test('isReadyForFinalization returns true with pages', () {
      final now = DateTime.now();
      const options = DocumentProcessingOptions();

      final page = DocumentPage(
        id: 'page-1',
        pageNumber: 1,
        originalPath: '/path/to/page1.jpg',
        scanTime: now,
      );

      final session = MultiPageScanSession(
        sessionId: 'session-1',
        documentType: DocumentType.document,
        processingOptions: options,
        startTime: now,
        pages: [page],
      );

      expect(session.isReadyForFinalization, true);
    });

    test('pageCount returns correct value', () {
      final now = DateTime.now();
      const options = DocumentProcessingOptions();

      var session = MultiPageScanSession(
        sessionId: 'session-1',
        documentType: DocumentType.document,
        processingOptions: options,
        startTime: now,
      );

      expect(session.pageCount, 0);

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

      session = session.addPage(page1).addPage(page2);
      expect(session.pageCount, 2);
    });

    test('summary returns session metadata', () {
      final now = DateTime(2024, 1, 15, 10, 30, 0);
      const options = DocumentProcessingOptions();

      final session = MultiPageScanSession(
        sessionId: 'session-1',
        documentType: DocumentType.receipt,
        processingOptions: options,
        startTime: now,
        customFilename: 'receipts',
      );

      final summary = session.summary();

      expect(summary['sessionId'], 'session-1');
      expect(summary['documentType'], 'DocumentType.receipt');
      expect(summary['pageCount'], 0);
      expect(summary['isReadyForFinalization'], false);
      expect(summary['customFilename'], 'receipts');
    });

    test('toScannedDocument creates single-page document', () {
      final now = DateTime.now();
      const options = DocumentProcessingOptions();

      final page = DocumentPage(
        id: 'page-1',
        pageNumber: 1,
        originalPath: '/path/to/page1.jpg',
        scanTime: now,
      );

      final session = MultiPageScanSession(
        sessionId: 'session-1',
        documentType: DocumentType.document,
        processingOptions: options,
        startTime: now,
        pages: [page],
      );

      final document = session.toScannedDocument();

      expect(document.id, 'session-1');
      expect(document.type, DocumentType.document);
      expect(document.originalPath, '/path/to/page1.jpg');
      expect(document.scanTime, now);
      expect(document.isMultiPage, false);
      expect(document.pages.length, 1);
    });

    test('toScannedDocument creates multi-page document', () {
      final now = DateTime.now();
      const options = DocumentProcessingOptions();

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

      final session = MultiPageScanSession(
        sessionId: 'session-1',
        documentType: DocumentType.document,
        processingOptions: options,
        startTime: now,
        pages: [page1, page2],
        customFilename: 'document',
      );

      final document = session.toScannedDocument();

      expect(document.isMultiPage, true);
      expect(document.pages.length, 2);
      expect(document.metadata['pageCount'], 2);
      expect(document.metadata['customFilename'], 'document');
    });

    test('toScannedDocument preserves session metadata', () {
      final now = DateTime(2024, 1, 15, 10, 30, 0);
      const options = DocumentProcessingOptions();

      final page = DocumentPage(
        id: 'page-1',
        pageNumber: 1,
        originalPath: '/path/to/page1.jpg',
        scanTime: now,
      );

      final session = MultiPageScanSession(
        sessionId: 'session-1',
        documentType: DocumentType.manual,
        processingOptions: options,
        startTime: now,
        pages: [page],
        customFilename: 'manual_2024',
      );

      final document = session.toScannedDocument();

      expect(document.metadata['sessionStartTime'], now.toIso8601String());
      expect(document.metadata['customFilename'], 'manual_2024');
      expect(document.metadata['pageCount'], 1);
    });

    test('operations are immutable', () {
      final now = DateTime.now();
      const options = DocumentProcessingOptions();

      var session = MultiPageScanSession(
        sessionId: 'session-1',
        documentType: DocumentType.document,
        processingOptions: options,
        startTime: now,
      );

      final page = DocumentPage(
        id: 'page-1',
        pageNumber: 1,
        originalPath: '/path/to/page1.jpg',
        scanTime: now,
      );

      final updated = session.addPage(page);

      expect(session.pages.isEmpty, true);
      expect(updated.pages.length, 1);
    });

    test('complex workflow with add, remove, and reorder', () {
      final now = DateTime.now();
      const options = DocumentProcessingOptions();

      var session = MultiPageScanSession(
        sessionId: 'session-1',
        documentType: DocumentType.document,
        processingOptions: options,
        startTime: now,
      );

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
      final page3 = DocumentPage(
        id: 'page-3',
        pageNumber: 3,
        originalPath: '/path/to/page3.jpg',
        scanTime: now,
      );

      // Add pages
      session = session.addPage(page1).addPage(page2).addPage(page3);
      expect(session.pageCount, 3);

      // Remove middle page
      session = session.removePage('page-2');
      expect(session.pageCount, 2);
      expect(session.pages[0].id, 'page-1');
      expect(session.pages[1].id, 'page-3');

      // Reorder
      session = session.reorderPages([page3, page1]);
      expect(session.pages[0].id, 'page-3');
      expect(session.pages[1].id, 'page-1');

      // Convert to document
      final document = session.toScannedDocument();
      expect(document.isMultiPage, true);
      expect(document.pages.length, 2);
    });
  });

  group('DocumentType', () {
    test('has correct enum values', () {
      expect(
        DocumentType.values,
        [DocumentType.receipt, DocumentType.manual, DocumentType.document, DocumentType.other],
      );
    });
  });
}
