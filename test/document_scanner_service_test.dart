import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:document_scanner/src/services/document_scanner_service.dart';
import 'package:document_scanner/src/services/camera_service.dart';
import 'package:document_scanner/src/services/storage_helper.dart';
import 'package:document_scanner/src/services/pdf_generator.dart';
import 'package:document_scanner/src/services/qr_scanner_service.dart';
import 'package:document_scanner/src/services/image_processor.dart';
import 'package:document_scanner/src/models/scanned_document.dart';

@GenerateMocks([
  CameraService,
  StorageHelper,
  PdfGenerator,
  QRScannerService,
  ImageProcessor,
])
import 'document_scanner_service_test.mocks.dart';

void main() {
  late MockCameraService mockCameraService;
  late MockStorageHelper mockStorageHelper;
  late MockPdfGenerator mockPdfGenerator;
  late MockQRScannerService mockQRScanner;
  late MockImageProcessor mockImageProcessor;
  late DocumentScannerService scannerService;

  setUp(() {
    mockCameraService = MockCameraService();
    mockStorageHelper = MockStorageHelper();
    mockPdfGenerator = MockPdfGenerator();
    mockQRScanner = MockQRScannerService();
    mockImageProcessor = MockImageProcessor();

    scannerService = DocumentScannerService.withDependencies(
      cameraService: mockCameraService,
      storageHelper: mockStorageHelper,
      pdfGenerator: mockPdfGenerator,
      qrScanner: mockQRScanner,
      imageProcessor: mockImageProcessor,
    );
  });

  group('DocumentScannerService - scanDocument', () {
    test('returns success with document when capture succeeds', () async {
      final mockImageData = Uint8List.fromList([1, 2, 3, 4]);
      final captureResult = CaptureResult.success(
        imageData: mockImageData,
        path: '/test/image.jpg',
      );

      when(mockCameraService.captureFromCamera(imageQuality: anyNamed('imageQuality')))
          .thenAnswer((_) async => captureResult);

      final result = await scannerService.scanDocument(
        documentType: DocumentType.receipt,
      );

      expect(result.success, true);
      expect(result.document, isNotNull);
      expect(result.document!.rawImageData, equals(mockImageData));
      expect(result.document!.type, DocumentType.receipt);
    });

    test('returns cancelled result when user cancels capture', () async {
      when(mockCameraService.captureFromCamera(imageQuality: anyNamed('imageQuality')))
          .thenAnswer((_) async => CaptureResult.cancelled());

      final result = await scannerService.scanDocument(
        documentType: DocumentType.receipt,
      );

      expect(result.success, false);
      expect(result.error, contains('cancelled'));
    });

    test('returns error result when camera permission denied', () async {
      when(mockCameraService.captureFromCamera(imageQuality: anyNamed('imageQuality')))
          .thenAnswer((_) async => CaptureResult.error('Camera permission denied'));

      final result = await scannerService.scanDocument(
        documentType: DocumentType.receipt,
      );

      expect(result.success, false);
      expect(result.error, contains('Camera permission denied'));
    });

    test('processes and saves document when autoProcess is true', () async {
      final mockImageData = Uint8List.fromList([1, 2, 3, 4]);
      final processedImageData = Uint8List.fromList([5, 6, 7, 8]);
      final pdfData = Uint8List.fromList([9, 10, 11, 12]);

      when(mockCameraService.captureFromCamera(imageQuality: anyNamed('imageQuality')))
          .thenAnswer((_) async => CaptureResult.success(
                imageData: mockImageData,
                path: '/test/image.jpg',
              ));

      when(mockImageProcessor.processImage(any, any))
          .thenAnswer((_) async => processedImageData);

      when(mockPdfGenerator.generatePdf(
        imageData: anyNamed('imageData'),
        documentType: anyNamed('documentType'),
        resolution: anyNamed('resolution'),
        documentFormat: anyNamed('documentFormat'),
        metadata: anyNamed('metadata'),
      )).thenAnswer((_) async => pdfData);

      when(mockStorageHelper.getExternalStorageDirectory())
          .thenAnswer((_) async => Directory.systemTemp);

      when(mockStorageHelper.generateFilename(
        documentType: anyNamed('documentType'),
        timestamp: anyNamed('timestamp'),
        customFilename: anyNamed('customFilename'),
        metadata: anyNamed('metadata'),
      )).thenReturn('test_receipt');

      when(mockStorageHelper.savePdfFile(
        directory: anyNamed('directory'),
        filename: anyNamed('filename'),
        pdfData: anyNamed('pdfData'),
      )).thenAnswer((_) async => '/test/test_receipt.pdf');

      final result = await scannerService.scanDocument(
        documentType: DocumentType.receipt,
        autoProcess: true,
      );

      expect(result.success, true);
      expect(result.document!.pdfPath, '/test/test_receipt.pdf');
      verify(mockImageProcessor.processImage(any, any)).called(1);
      verify(mockPdfGenerator.generatePdf(
        imageData: anyNamed('imageData'),
        documentType: anyNamed('documentType'),
        resolution: anyNamed('resolution'),
        documentFormat: anyNamed('documentFormat'),
        metadata: anyNamed('metadata'),
      )).called(1);
    });
  });

  group('DocumentScannerService - importDocument', () {
    test('returns success with document when import succeeds', () async {
      final mockImageData = Uint8List.fromList([1, 2, 3, 4]);
      final captureResult = CaptureResult.success(
        imageData: mockImageData,
        path: '/test/gallery.jpg',
      );

      when(mockCameraService.importFromGallery(imageQuality: anyNamed('imageQuality')))
          .thenAnswer((_) async => captureResult);

      final result = await scannerService.importDocument(
        documentType: DocumentType.document,
      );

      expect(result.success, true);
      expect(result.document, isNotNull);
      expect(result.document!.rawImageData, equals(mockImageData));
      expect(result.document!.metadata['source'], 'gallery');
    });

    test('returns cancelled result when user cancels import', () async {
      when(mockCameraService.importFromGallery(imageQuality: anyNamed('imageQuality')))
          .thenAnswer((_) async => CaptureResult.cancelled());

      final result = await scannerService.importDocument(
        documentType: DocumentType.document,
      );

      expect(result.success, false);
      expect(result.error, contains('cancelled'));
    });
  });

  group('DocumentScannerService - scanDocumentWithProcessing', () {
    test('processes and saves document automatically', () async {
      final mockImageData = Uint8List.fromList([1, 2, 3, 4]);
      final processedImageData = Uint8List.fromList([5, 6, 7, 8]);
      final pdfData = Uint8List.fromList([9, 10, 11, 12]);

      when(mockCameraService.captureFromCamera(imageQuality: anyNamed('imageQuality')))
          .thenAnswer((_) async => CaptureResult.success(
                imageData: mockImageData,
                path: '/test/image.jpg',
              ));

      when(mockImageProcessor.processImage(any, any))
          .thenAnswer((_) async => processedImageData);

      when(mockPdfGenerator.generatePdf(
        imageData: anyNamed('imageData'),
        documentType: anyNamed('documentType'),
        resolution: anyNamed('resolution'),
        documentFormat: anyNamed('documentFormat'),
        metadata: anyNamed('metadata'),
      )).thenAnswer((_) async => pdfData);

      when(mockStorageHelper.getExternalStorageDirectory())
          .thenAnswer((_) async => Directory.systemTemp);

      when(mockStorageHelper.generateFilename(
        documentType: anyNamed('documentType'),
        timestamp: anyNamed('timestamp'),
        customFilename: anyNamed('customFilename'),
        metadata: anyNamed('metadata'),
      )).thenReturn('test_document');

      when(mockStorageHelper.savePdfFile(
        directory: anyNamed('directory'),
        filename: anyNamed('filename'),
        pdfData: anyNamed('pdfData'),
      )).thenAnswer((_) async => '/test/test_document.pdf');

      final result = await scannerService.scanDocumentWithProcessing(
        documentType: DocumentType.document,
      );

      expect(result.success, true);
      expect(result.document!.pdfPath, isNotNull);
      expect(result.document!.metadata['autoProcessed'], true);
      expect(result.document!.metadata['finalized'], true);
    });
  });

  group('DocumentScannerService - storage configuration', () {
    test('configures storage with custom directory', () {
      scannerService.configureStorage(
        customStorageDirectory: '/custom/directory',
        appName: 'TestApp',
      );

      verify(mockStorageHelper.configure(any)).called(1);
    });
  });

  group('DocumentScannerService - finalizeScanResult', () {
    test('generates PDF if not present and saves document', () async {
      final processedImageData = Uint8List.fromList([5, 6, 7, 8]);
      final pdfData = Uint8List.fromList([9, 10, 11, 12]);

      final document = ScannedDocument(
        id: '123',
        type: DocumentType.receipt,
        originalPath: '/test/image.jpg',
        scanTime: DateTime.now(),
        processingOptions: DocumentProcessingOptions.receipt,
        processedImageData: processedImageData,
      );

      when(mockPdfGenerator.generatePdf(
        imageData: anyNamed('imageData'),
        documentType: anyNamed('documentType'),
        resolution: anyNamed('resolution'),
        documentFormat: anyNamed('documentFormat'),
        metadata: anyNamed('metadata'),
      )).thenAnswer((_) async => pdfData);

      when(mockStorageHelper.getExternalStorageDirectory())
          .thenAnswer((_) async => Directory.systemTemp);

      when(mockStorageHelper.generateFilename(
        documentType: anyNamed('documentType'),
        timestamp: anyNamed('timestamp'),
        customFilename: anyNamed('customFilename'),
        metadata: anyNamed('metadata'),
      )).thenReturn('test_receipt');

      when(mockStorageHelper.savePdfFile(
        directory: anyNamed('directory'),
        filename: anyNamed('filename'),
        pdfData: anyNamed('pdfData'),
      )).thenAnswer((_) async => '/test/test_receipt.pdf');

      final result = await scannerService.finalizeScanResult(document, null);

      expect(result.success, true);
      expect(result.document!.pdfPath, '/test/test_receipt.pdf');
      expect(result.document!.metadata['finalized'], true);
      verify(mockPdfGenerator.generatePdf(
        imageData: anyNamed('imageData'),
        documentType: anyNamed('documentType'),
        resolution: anyNamed('resolution'),
        documentFormat: anyNamed('documentFormat'),
        metadata: anyNamed('metadata'),
      )).called(1);
    });
  });

  group('DocumentScannerService - finalizeMultiPageSession', () {
    test('combines pages into single PDF and saves', () async {
      final page1Data = Uint8List.fromList([1, 2, 3, 4]);
      final page2Data = Uint8List.fromList([5, 6, 7, 8]);
      final pdfData = Uint8List.fromList([9, 10, 11, 12]);

      final page1 = DocumentPage(
        id: '1',
        pageNumber: 1,
        originalPath: '/test/page1.jpg',
        scanTime: DateTime.now(),
        processedImageData: page1Data,
      );

      final page2 = DocumentPage(
        id: '2',
        pageNumber: 2,
        originalPath: '/test/page2.jpg',
        scanTime: DateTime.now(),
        processedImageData: page2Data,
      );

      final session = MultiPageScanSession(
        sessionId: 'session123',
        documentType: DocumentType.manual,
        processingOptions: DocumentProcessingOptions.manual,
        startTime: DateTime.now(),
        pages: [page1, page2],
      );

      when(mockCameraService.requestStoragePermission())
          .thenAnswer((_) async => true);

      when(mockPdfGenerator.generateMultiPagePdf(
        imageDataList: anyNamed('imageDataList'),
        documentType: anyNamed('documentType'),
        resolution: anyNamed('resolution'),
        documentFormat: anyNamed('documentFormat'),
        metadata: anyNamed('metadata'),
      )).thenAnswer((_) async => pdfData);

      when(mockStorageHelper.getExternalStorageDirectory())
          .thenAnswer((_) async => Directory.systemTemp);

      when(mockStorageHelper.generateFilename(
        documentType: anyNamed('documentType'),
        timestamp: anyNamed('timestamp'),
        customFilename: anyNamed('customFilename'),
        metadata: anyNamed('metadata'),
      )).thenReturn('test_manual');

      when(mockStorageHelper.savePdfFile(
        directory: anyNamed('directory'),
        filename: anyNamed('filename'),
        pdfData: anyNamed('pdfData'),
      )).thenAnswer((_) async => '/test/test_manual.pdf');

      final result = await scannerService.finalizeMultiPageSession(session);

      expect(result.success, true);
      expect(result.document!.pdfPath, '/test/test_manual.pdf');
      expect(result.document!.isMultiPage, true);
      expect(result.document!.pages.length, 2);
      verify(mockPdfGenerator.generateMultiPagePdf(
        imageDataList: anyNamed('imageDataList'),
        documentType: anyNamed('documentType'),
        resolution: anyNamed('resolution'),
        documentFormat: anyNamed('documentFormat'),
        metadata: anyNamed('metadata'),
      )).called(1);
    });

    test('returns error when no pages in session', () async {
      final session = MultiPageScanSession(
        sessionId: 'session123',
        documentType: DocumentType.manual,
        processingOptions: DocumentProcessingOptions.manual,
        startTime: DateTime.now(),
        pages: [],
      );

      final result = await scannerService.finalizeMultiPageSession(session);

      expect(result.success, false);
      expect(result.error, contains('No pages to finalize'));
    });

    test('returns error when storage permission denied', () async {
      final page1 = DocumentPage(
        id: '1',
        pageNumber: 1,
        originalPath: '/test/page1.jpg',
        scanTime: DateTime.now(),
        processedImageData: Uint8List.fromList([1, 2, 3, 4]),
      );

      final session = MultiPageScanSession(
        sessionId: 'session123',
        documentType: DocumentType.manual,
        processingOptions: DocumentProcessingOptions.manual,
        startTime: DateTime.now(),
        pages: [page1],
      );

      when(mockCameraService.requestStoragePermission())
          .thenAnswer((_) async => false);

      final result = await scannerService.finalizeMultiPageSession(session);

      expect(result.success, false);
      expect(result.error, contains('Storage permission denied'));
    });
  });
}
