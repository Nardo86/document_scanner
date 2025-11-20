import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/src/models/scan_result.dart';
import 'package:document_scanner/src/models/scanned_document.dart';
import 'package:document_scanner/src/models/processing_options.dart';

void main() {
  group('ScanResult', () {
    late ScannedDocument mockDocument;

    setUp(() {
      final now = DateTime.now();
      mockDocument = ScannedDocument(
        id: 'doc-1',
        type: DocumentType.document,
        originalPath: '/path/to/image.jpg',
        scanTime: now,
        processingOptions: DocumentProcessingOptions.document,
      );
    });

    test('creates success result with factory constructor', () {
      final result = ScanResult.success(document: mockDocument);

      expect(result.success, true);
      expect(result.document, mockDocument);
      expect(result.error, isNull);
      expect(result.type, ScanResultType.scan);
      expect(result.metadata, isEmpty);
    });

    test('creates error result with factory constructor', () {
      final result = ScanResult.error(error: 'Failed to scan');

      expect(result.success, false);
      expect(result.document, isNull);
      expect(result.error, 'Failed to scan');
      expect(result.type, ScanResultType.scan);
    });

    test('creates cancelled result', () {
      final result = ScanResult.cancelled();

      expect(result.success, false);
      expect(result.error, 'User cancelled operation');
      expect(result.type, ScanResultType.scan);
    });

    test('success factory with custom type and metadata', () {
      final metadata = {'source': 'gallery'};
      final result = ScanResult.success(
        document: mockDocument,
        type: ScanResultType.import,
        metadata: metadata,
      );

      expect(result.type, ScanResultType.import);
      expect(result.metadata, metadata);
    });

    test('error factory with custom type', () {
      final result = ScanResult.error(
        error: 'Download failed',
        type: ScanResultType.download,
      );

      expect(result.type, ScanResultType.download);
      expect(result.error, 'Download failed');
    });

    test('toJson serializes success result', () {
      final now = DateTime(2024, 1, 15, 10, 30, 0);
      final doc = ScannedDocument(
        id: 'doc-1',
        type: DocumentType.receipt,
        originalPath: '/path/to/image.jpg',
        scanTime: now,
        processingOptions: DocumentProcessingOptions.receipt,
      );

      final result = ScanResult.success(
        document: doc,
        type: ScanResultType.scan,
        metadata: {'pages': 1},
      );

      final json = result.toJson();

      expect(json['success'], true);
      expect(json['error'], isNull);
      expect(json['type'], 'ScanResultType.scan');
      expect(json['document'], isNotNull);
      expect(json['metadata'], {'pages': 1});
    });

    test('toJson serializes error result', () {
      final result = ScanResult.error(
        error: 'Camera not available',
        type: ScanResultType.scan,
      );

      final json = result.toJson();

      expect(json['success'], false);
      expect(json['error'], 'Camera not available');
      expect(json['document'], isNull);
    });

    test('fromJson deserializes success result', () {
      final json = {
        'success': true,
        'document': {
          'id': 'doc-1',
          'type': 'DocumentType.receipt',
          'originalPath': '/path/to/image.jpg',
          'scanTime': '2024-01-15T10:30:00.000Z',
          'processingOptions': {},
        },
        'error': null,
        'type': 'ScanResultType.scan',
        'metadata': {'source': 'camera'},
      };

      final result = ScanResult.fromJson(json);

      expect(result.success, true);
      expect(result.document, isNotNull);
      expect(result.error, isNull);
      expect(result.metadata, {'source': 'camera'});
    });

    test('fromJson deserializes error result', () {
      final json = {
        'success': false,
        'document': null,
        'error': 'Permission denied',
        'type': 'ScanResultType.scan',
        'metadata': {},
      };

      final result = ScanResult.fromJson(json);

      expect(result.success, false);
      expect(result.document, isNull);
      expect(result.error, 'Permission denied');
    });

    test('roundtrip serialization preserves success data', () {
      final original = ScanResult.success(
        document: mockDocument,
        type: ScanResultType.import,
        metadata: {'source': 'gallery', 'filesize': 1024000},
      );

      final json = original.toJson();
      final restored = ScanResult.fromJson(json);

      expect(restored.success, original.success);
      expect(restored.document?.id, original.document?.id);
      expect(restored.type, original.type);
      expect(restored.metadata, original.metadata);
    });

    test('roundtrip serialization preserves error data', () {
      final original = ScanResult.error(
        error: 'Network timeout',
        type: ScanResultType.download,
      );

      final json = original.toJson();
      final restored = ScanResult.fromJson(json);

      expect(restored.success, original.success);
      expect(restored.error, original.error);
      expect(restored.type, original.type);
    });
  });

  group('QRScanResult', () {
    test('creates success QR result', () {
      final result = QRScanResult.success(
        qrData: 'https://example.com/manual.pdf',
        contentType: QRContentType.pdfLink,
      );

      expect(result.success, true);
      expect(result.qrData, 'https://example.com/manual.pdf');
      expect(result.contentType, QRContentType.pdfLink);
      expect(result.type, ScanResultType.qrScan);
    });

    test('creates error QR result', () {
      final result = QRScanResult.error(
        error: 'Invalid QR code',
        qrData: 'corrupted_data',
      );

      expect(result.success, false);
      expect(result.error, 'Invalid QR code');
      expect(result.qrData, 'corrupted_data');
      expect(result.contentType, QRContentType.unknown);
    });

    test('success factory with document', () {
      final now = DateTime.now();
      final doc = ScannedDocument(
        id: 'doc-1',
        type: DocumentType.manual,
        originalPath: '/path/to/manual.pdf',
        scanTime: now,
        processingOptions: DocumentProcessingOptions.manual,
      );

      final result = QRScanResult.success(
        qrData: 'https://example.com/manual.pdf',
        contentType: QRContentType.manualLink,
        document: doc,
      );

      expect(result.document, doc);
      expect(result.qrData, 'https://example.com/manual.pdf');
    });

    test('toJson serializes QR result', () {
      final result = QRScanResult.success(
        qrData: 'https://example.com/data',
        contentType: QRContentType.url,
        metadata: {'scanned_at': 'camera'},
      );

      final json = result.toJson();

      expect(json['success'], true);
      expect(json['type'], 'ScanResultType.qrScan');
      expect(json['qrData'], 'https://example.com/data');
      expect(json['contentType'], 'QRContentType.url');
      expect(json['metadata'], {'scanned_at': 'camera'});
    });

    test('fromJson deserializes QR result', () {
      final json = {
        'success': true,
        'qrData': 'https://example.com/manual.pdf',
        'contentType': 'QRContentType.pdfLink',
        'document': null,
        'error': null,
        'type': 'ScanResultType.qrScan',
        'metadata': {},
      };

      final result = QRScanResult.fromJson(json);

      expect(result.success, true);
      expect(result.qrData, 'https://example.com/manual.pdf');
      expect(result.contentType, QRContentType.pdfLink);
    });

    test('roundtrip serialization preserves QR data', () {
      final original = QRScanResult.success(
        qrData: 'https://manual.example.com/guide.pdf',
        contentType: QRContentType.manualLink,
        metadata: {'scanner': 'mobile_scanner', 'version': '1.0'},
      );

      final json = original.toJson();
      final restored = QRScanResult.fromJson(json);

      expect(restored.qrData, original.qrData);
      expect(restored.contentType, original.contentType);
      expect(restored.metadata, original.metadata);
    });

    test('extends ScanResult correctly', () {
      final result = QRScanResult.success(
        qrData: 'test_data',
        contentType: QRContentType.text,
      );

      expect(result, isA<ScanResult>());
      expect(result.type, ScanResultType.qrScan);
    });
  });

  group('ScanResultType enum', () {
    test('has correct values', () {
      expect(
        ScanResultType.values,
        [ScanResultType.scan, ScanResultType.import, ScanResultType.download, ScanResultType.qrScan],
      );
    });
  });

  group('QRContentType enum', () {
    test('has correct values', () {
      expect(
        QRContentType.values,
        [
          QRContentType.url,
          QRContentType.pdfLink,
          QRContentType.manualLink,
          QRContentType.text,
          QRContentType.unknown,
        ],
      );
    });
  });
}
