import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/src/models/document_page.dart';

void main() {
  group('DocumentPage', () {
    test('creates with required parameters', () {
      final now = DateTime.now();
      final page = DocumentPage(
        id: 'page-1',
        pageNumber: 1,
        originalPath: '/path/to/original.jpg',
        scanTime: now,
      );

      expect(page.id, 'page-1');
      expect(page.pageNumber, 1);
      expect(page.originalPath, '/path/to/original.jpg');
      expect(page.scanTime, now);
      expect(page.processedPath, isNull);
      expect(page.metadata, isEmpty);
    });

    test('creates with optional parameters', () {
      final now = DateTime.now();
      final metadata = {'quality': 'high'};
      final page = DocumentPage(
        id: 'page-1',
        pageNumber: 1,
        originalPath: '/path/to/original.jpg',
        scanTime: now,
        processedPath: '/path/to/processed.jpg',
        metadata: metadata,
      );

      expect(page.processedPath, '/path/to/processed.jpg');
      expect(page.metadata, metadata);
    });

    test('copyWith creates new instance with updated fields', () {
      final now = DateTime.now();
      final page = DocumentPage(
        id: 'page-1',
        pageNumber: 1,
        originalPath: '/path/to/original.jpg',
        scanTime: now,
      );

      final updated = page.copyWith(
        processedPath: '/path/to/processed.jpg',
      );

      expect(updated.id, page.id);
      expect(updated.pageNumber, page.pageNumber);
      expect(updated.originalPath, page.originalPath);
      expect(updated.scanTime, page.scanTime);
      expect(updated.processedPath, '/path/to/processed.jpg');
      expect(page.processedPath, isNull);
    });

    test('copyWith preserves original fields not specified', () {
      final now = DateTime.now();
      final metadata = {'original': 'data'};
      final page = DocumentPage(
        id: 'page-1',
        pageNumber: 1,
        originalPath: '/path/to/original.jpg',
        scanTime: now,
        metadata: metadata,
      );

      final updated = page.copyWith(
        processedPath: '/new/path.jpg',
      );

      expect(updated.metadata, metadata);
      expect(updated.processedPath, '/new/path.jpg');
    });

    test('toJson serializes all fields correctly', () {
      final now = DateTime(2024, 1, 15, 10, 30, 0);
      final page = DocumentPage(
        id: 'page-1',
        pageNumber: 1,
        originalPath: '/path/to/original.jpg',
        scanTime: now,
        processedPath: '/path/to/processed.jpg',
        metadata: {'quality': 'high'},
      );

      final json = page.toJson();

      expect(json['id'], 'page-1');
      expect(json['pageNumber'], 1);
      expect(json['originalPath'], '/path/to/original.jpg');
      expect(json['processedPath'], '/path/to/processed.jpg');
      expect(json['scanTime'], '2024-01-15T10:30:00.000');
      expect(json['metadata'], {'quality': 'high'});
    });

    test('toJson excludes binary data', () {
      final now = DateTime.now();
      final page = DocumentPage(
        id: 'page-1',
        pageNumber: 1,
        originalPath: '/path/to/original.jpg',
        scanTime: now,
        rawImageData: null,
        processedImageData: null,
      );

      final json = page.toJson();

      expect(json.containsKey('rawImageData'), false);
      expect(json.containsKey('processedImageData'), false);
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'id': 'page-1',
        'pageNumber': 1,
        'originalPath': '/path/to/original.jpg',
        'processedPath': '/path/to/processed.jpg',
        'scanTime': '2024-01-15T10:30:00.000Z',
        'metadata': {'quality': 'high'},
      };

      final page = DocumentPage.fromJson(json);

      expect(page.id, 'page-1');
      expect(page.pageNumber, 1);
      expect(page.originalPath, '/path/to/original.jpg');
      expect(page.processedPath, '/path/to/processed.jpg');
      expect(page.metadata, {'quality': 'high'});
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'page-1',
        'pageNumber': 1,
        'originalPath': '/path/to/original.jpg',
        'scanTime': '2024-01-15T10:30:00.000Z',
      };

      final page = DocumentPage.fromJson(json);

      expect(page.id, 'page-1');
      expect(page.processedPath, isNull);
      expect(page.metadata, isEmpty);
    });

    test('roundtrip serialization preserves data', () {
      final now = DateTime.now();
      final original = DocumentPage(
        id: 'page-1',
        pageNumber: 2,
        originalPath: '/path/to/original.jpg',
        scanTime: now,
        processedPath: '/path/to/processed.jpg',
        metadata: {'resolution': 300, 'format': 'jpeg'},
      );

      final json = original.toJson();
      final restored = DocumentPage.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.pageNumber, original.pageNumber);
      expect(restored.originalPath, original.originalPath);
      expect(restored.processedPath, original.processedPath);
      expect(restored.metadata, original.metadata);
    });
  });
}
