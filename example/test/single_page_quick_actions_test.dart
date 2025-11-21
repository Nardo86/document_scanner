import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/document_scanner.dart';

void main() {
  group('Single Page Quick Actions Tests', () {
    test('DocumentScannerService has showImageEditorFlow method', () {
      // Verify that new shared helper method exists on DocumentScannerService
      final service = DocumentScannerService();
      expect(service, isNotNull);
      
      // Test that method exists by checking its runtime type
      expect(service.showImageEditorFlow, isA<Function>());
    });

    test('ScanResult contains expected error for cancelled editing', () {
      // Verify that cancelled editing returns proper error
      final result = ScanResult.error(
        error: 'Editing cancelled',
        type: ScanResultType.scan,
      );
      
      expect(result.success, isFalse);
      expect(result.error, equals('Editing cancelled'));
      expect(result.type, equals(ScanResultType.scan));
    });

    test('DocumentScannerWidget can be instantiated', () {
      // Verify DocumentScannerWidget can be instantiated properly
      expect(() => DocumentScannerWidget(
        documentType: DocumentType.document,
        onScanComplete: (result) {},
      ), returnsNormally);
    });

    test('ScannedDocument can be created with rawImageData', () {
      // Verify that ScannedDocument can be created with raw image data
      // which is required for to editing flow
      final document = ScannedDocument(
        id: 'test',
        type: DocumentType.document,
        originalPath: '/test/path',
        scanTime: DateTime.now(),
        processingOptions: DocumentProcessingOptions.document,
        rawImageData: Uint8List(0),
      );
      
      expect(document.id, equals('test'));
      expect(document.type, equals(DocumentType.document));
      expect(document.rawImageData, isNotNull);
      expect(document.rawImageData, isEmpty);
    });
  });
}