import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/src/services/storage_helper.dart';
import 'package:document_scanner/src/models/scanned_document.dart';
import 'package:path/path.dart' as path;

void main() {
  late StorageHelper storageHelper;
  late Directory tempDir;

  setUp(() async {
    storageHelper = StorageHelper();
    tempDir = await Directory.systemTemp.createTemp('storage_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('StorageHelper - filename generation', () {
    test('generates filename with custom name', () {
      final filename = storageHelper.generateFilename(
        documentType: DocumentType.receipt,
        timestamp: DateTime(2024, 1, 15),
        customFilename: 'my_custom_receipt',
      );

      expect(filename, 'my_custom_receipt');
    });

    test('generates filename from metadata suggestedFilename', () {
      final filename = storageHelper.generateFilename(
        documentType: DocumentType.receipt,
        timestamp: DateTime(2024, 1, 15),
        metadata: {
          'suggestedFilename': 'suggested_name',
        },
      );

      expect(filename, 'suggested_name');
    });

    test('generates filename from product brand and model', () {
      final filename = storageHelper.generateFilename(
        documentType: DocumentType.manual,
        timestamp: DateTime(2024, 1, 15),
        metadata: {
          'productBrand': 'Samsung',
          'productModel': 'Galaxy S23',
        },
      );

      expect(filename, contains('Samsung'));
      expect(filename, contains('Galaxy_S23'));
      expect(filename, contains('Manual'));
    });

    test('generates timestamp-based filename as fallback', () {
      final filename = storageHelper.generateFilename(
        documentType: DocumentType.receipt,
        timestamp: DateTime(2024, 1, 15),
      );

      expect(filename, '20240115_Receipt');
    });

    test('cleans invalid characters from filename', () {
      final filename = storageHelper.generateFilename(
        documentType: DocumentType.manual,
        timestamp: DateTime(2024, 1, 15),
        metadata: {
          'productBrand': 'Test<>Brand',
          'productModel': 'Model/With:Invalid*Chars',
        },
      );

      expect(filename, isNot(contains('<')));
      expect(filename, isNot(contains('>')));
      expect(filename, isNot(contains('/')));
      expect(filename, isNot(contains(':')));
      expect(filename, isNot(contains('*')));
    });

    test('generates correct suffix for each document type', () {
      final receiptFilename = storageHelper.generateFilename(
        documentType: DocumentType.receipt,
        timestamp: DateTime(2024, 1, 15),
      );
      expect(receiptFilename, contains('Receipt'));

      final manualFilename = storageHelper.generateFilename(
        documentType: DocumentType.manual,
        timestamp: DateTime(2024, 1, 15),
      );
      expect(manualFilename, contains('Manual'));

      final documentFilename = storageHelper.generateFilename(
        documentType: DocumentType.document,
        timestamp: DateTime(2024, 1, 15),
      );
      expect(documentFilename, contains('Document'));

      final otherFilename = storageHelper.generateFilename(
        documentType: DocumentType.other,
        timestamp: DateTime(2024, 1, 15),
      );
      expect(otherFilename, contains('Scan'));
    });
  });

  group('StorageHelper - file saving', () {
    test('saves image file successfully', () async {
      final imageData = Uint8List.fromList([1, 2, 3, 4, 5]);
      final filename = 'test_image';

      final savedPath = await storageHelper.saveImageFile(
        directory: tempDir,
        filename: filename,
        imageData: imageData,
      );

      expect(savedPath, endsWith('.jpg'));
      expect(File(savedPath).existsSync(), true);

      final savedData = await File(savedPath).readAsBytes();
      expect(savedData, equals(imageData));
    });

    test('saves PDF file successfully', () async {
      final pdfData = Uint8List.fromList([1, 2, 3, 4, 5]);
      final filename = 'test_pdf';

      final savedPath = await storageHelper.savePdfFile(
        directory: tempDir,
        filename: filename,
        pdfData: pdfData,
      );

      expect(savedPath, endsWith('.pdf'));
      expect(File(savedPath).existsSync(), true);

      final savedData = await File(savedPath).readAsBytes();
      expect(savedData, equals(pdfData));
    });

    test('saves both image and PDF files', () async {
      final imageData = Uint8List.fromList([1, 2, 3, 4, 5]);
      final pdfData = Uint8List.fromList([6, 7, 8, 9, 10]);
      final filename = 'test_both';

      final paths = await storageHelper.saveFiles(
        directory: tempDir,
        filename: filename,
        imageData: imageData,
        pdfData: pdfData,
      );

      expect(paths.containsKey('image'), true);
      expect(paths.containsKey('pdf'), true);
      expect(paths['image'], endsWith('.jpg'));
      expect(paths['pdf'], endsWith('.pdf'));
      expect(File(paths['image']!).existsSync(), true);
      expect(File(paths['pdf']!).existsSync(), true);
    });

    test('saves only image when PDF is null', () async {
      final imageData = Uint8List.fromList([1, 2, 3, 4, 5]);
      final filename = 'test_image_only';

      final paths = await storageHelper.saveFiles(
        directory: tempDir,
        filename: filename,
        imageData: imageData,
      );

      expect(paths.containsKey('image'), true);
      expect(paths.containsKey('pdf'), false);
    });

    test('saves only PDF when image is null', () async {
      final pdfData = Uint8List.fromList([1, 2, 3, 4, 5]);
      final filename = 'test_pdf_only';

      final paths = await storageHelper.saveFiles(
        directory: tempDir,
        filename: filename,
        pdfData: pdfData,
      );

      expect(paths.containsKey('image'), false);
      expect(paths.containsKey('pdf'), true);
    });
  });

  group('StorageHelper - storage configuration', () {
    test('uses custom directory when configured', () async {
      final customDir = path.join(tempDir.path, 'custom_storage');
      storageHelper.configure(StorageConfig(
        customDirectory: customDir,
      ));

      final directory = await storageHelper.getExternalStorageDirectory();

      expect(directory.path, customDir);
      expect(directory.existsSync(), true);
    });

    test('creates directory if it does not exist', () async {
      final customDir = path.join(tempDir.path, 'new_directory');
      storageHelper.configure(StorageConfig(
        customDirectory: customDir,
      ));

      expect(Directory(customDir).existsSync(), false);

      final directory = await storageHelper.getExternalStorageDirectory();

      expect(directory.existsSync(), true);
    });
  });
}
