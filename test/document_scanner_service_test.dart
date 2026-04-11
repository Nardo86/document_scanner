import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
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

  // ---------------------------------------------------------------------------
  // Helper: stub processImageWithAutoCrop to return a valid result map
  // ---------------------------------------------------------------------------
  void stubAutoCrop(Uint8List processedData) {
    when(mockImageProcessor.processImageWithAutoCrop(any, any))
        .thenAnswer((_) async => <String, dynamic>{
              'processedImageData': processedData,
              'detectedEdges': <Offset>[],
              'metadata': <String, dynamic>{
                'autoCrop': {'applied': false},
              },
            });
  }

  // Helper: stub the full save pipeline
  void stubSavePipeline({
    required Uint8List pdfData,
    required String savedPdfPath,
  }) {
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
    )).thenReturn('test_filename');

    when(mockStorageHelper.savePdfFile(
      directory: anyNamed('directory'),
      filename: anyNamed('filename'),
      pdfData: anyNamed('pdfData'),
    )).thenAnswer((_) async => savedPdfPath);
  }

  // ---------------------------------------------------------------------------
  // scanDocument
  // ---------------------------------------------------------------------------

  group('DocumentScannerService - scanDocument', () {
    test('returns success with document when capture succeeds', () async {
      final mockImageData = Uint8List.fromList([1, 2, 3, 4]);
      final captureResult = CaptureResult.success(
        imageData: mockImageData,
        path: '/test/image.jpg',
      );

      when(mockCameraService.captureFromCamera(
              imageQuality: anyNamed('imageQuality')))
          .thenAnswer((_) async => captureResult);

      // processImageWithAutoCrop is called for auto-crop in editor path;
      // it may throw (caught silently), so stub it to avoid noise.
      stubAutoCrop(mockImageData);

      final result = await scannerService.scanDocument(
        documentType: DocumentType.receipt,
      );

      expect(result.success, true);
      expect(result.document, isNotNull);
      expect(result.document!.rawImageData, equals(mockImageData));
      expect(result.document!.type, DocumentType.receipt);
    });

    test('returns cancelled result when user cancels capture', () async {
      when(mockCameraService.captureFromCamera(
              imageQuality: anyNamed('imageQuality')))
          .thenAnswer((_) async => CaptureResult.cancelled());

      final result = await scannerService.scanDocument(
        documentType: DocumentType.receipt,
      );

      expect(result.success, false);
      expect(result.error, contains('cancelled'));
    });

    test('returns error result when camera permission denied', () async {
      when(mockCameraService.captureFromCamera(
              imageQuality: anyNamed('imageQuality')))
          .thenAnswer((_) async =>
              CaptureResult.error('Camera permission denied'));

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

      when(mockCameraService.captureFromCamera(
              imageQuality: anyNamed('imageQuality')))
          .thenAnswer((_) async => CaptureResult.success(
                imageData: mockImageData,
                path: '/test/image.jpg',
              ));

      stubAutoCrop(processedImageData);
      stubSavePipeline(pdfData: pdfData, savedPdfPath: '/test/test_receipt.pdf');

      final result = await scannerService.scanDocument(
        documentType: DocumentType.receipt,
        autoProcess: true,
      );

      expect(result.success, true);
      expect(result.document!.pdfPath, '/test/test_receipt.pdf');
      verify(mockImageProcessor.processImageWithAutoCrop(any, any)).called(1);
      verify(mockPdfGenerator.generatePdf(
        imageData: anyNamed('imageData'),
        documentType: anyNamed('documentType'),
        resolution: anyNamed('resolution'),
        documentFormat: anyNamed('documentFormat'),
        metadata: anyNamed('metadata'),
      )).called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // importDocument
  // ---------------------------------------------------------------------------

  group('DocumentScannerService - importDocument', () {
    test('returns success with document when import succeeds', () async {
      final mockImageData = Uint8List.fromList([1, 2, 3, 4]);
      final captureResult = CaptureResult.success(
        imageData: mockImageData,
        path: '/test/gallery.jpg',
      );

      when(mockCameraService.importFromGallery(
              imageQuality: anyNamed('imageQuality')))
          .thenAnswer((_) async => captureResult);

      stubAutoCrop(mockImageData);

      final result = await scannerService.importDocument(
        documentType: DocumentType.document,
      );

      expect(result.success, true);
      expect(result.document, isNotNull);
      expect(result.document!.rawImageData, equals(mockImageData));
      expect(result.document!.metadata['source'], 'gallery');
    });

    test('returns cancelled result when user cancels import', () async {
      when(mockCameraService.importFromGallery(
              imageQuality: anyNamed('imageQuality')))
          .thenAnswer((_) async => CaptureResult.cancelled());

      final result = await scannerService.importDocument(
        documentType: DocumentType.document,
      );

      expect(result.success, false);
      expect(result.error, contains('cancelled'));
    });
  });

  // ---------------------------------------------------------------------------
  // scanDocumentWithProcessing
  // ---------------------------------------------------------------------------

  group('DocumentScannerService - scanDocumentWithProcessing', () {
    test('processes and saves document automatically', () async {
      final mockImageData = Uint8List.fromList([1, 2, 3, 4]);
      final processedImageData = Uint8List.fromList([5, 6, 7, 8]);
      final pdfData = Uint8List.fromList([9, 10, 11, 12]);

      when(mockCameraService.captureFromCamera(
              imageQuality: anyNamed('imageQuality')))
          .thenAnswer((_) async => CaptureResult.success(
                imageData: mockImageData,
                path: '/test/image.jpg',
              ));

      stubAutoCrop(processedImageData);
      stubSavePipeline(
          pdfData: pdfData, savedPdfPath: '/test/test_document.pdf');

      final result = await scannerService.scanDocumentWithProcessing(
        documentType: DocumentType.document,
      );

      expect(result.success, true);
      expect(result.document!.pdfPath, isNotNull);
      expect(result.document!.metadata['autoProcessed'], true);
      expect(result.document!.metadata['finalized'], true);
    });
  });

  // ---------------------------------------------------------------------------
  // importDocumentWithProcessing
  // ---------------------------------------------------------------------------

  group('DocumentScannerService - importDocumentWithProcessing', () {
    test('imports and processes document automatically', () async {
      final mockImageData = Uint8List.fromList([1, 2, 3, 4]);
      final processedImageData = Uint8List.fromList([5, 6, 7, 8]);
      final pdfData = Uint8List.fromList([9, 10, 11, 12]);

      when(mockCameraService.importFromGallery(
              imageQuality: anyNamed('imageQuality')))
          .thenAnswer((_) async => CaptureResult.success(
                imageData: mockImageData,
                path: '/test/gallery.jpg',
              ));

      stubAutoCrop(processedImageData);
      stubSavePipeline(
          pdfData: pdfData, savedPdfPath: '/test/test_import.pdf');

      final result = await scannerService.importDocumentWithProcessing(
        documentType: DocumentType.document,
      );

      expect(result.success, true);
      expect(result.document!.pdfPath, '/test/test_import.pdf');
      expect(result.document!.metadata['autoProcessed'], true);
      expect(result.document!.metadata['source'], 'gallery');
    });
  });

  // ---------------------------------------------------------------------------
  // Storage configuration
  // ---------------------------------------------------------------------------

  group('DocumentScannerService - storage configuration', () {
    test('configures storage with custom directory', () {
      scannerService.configureStorage(
        customStorageDirectory: '/custom/directory',
        appName: 'TestApp',
      );

      verify(mockStorageHelper.configure(any)).called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // finalizeScanResult
  // ---------------------------------------------------------------------------

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

      stubSavePipeline(
          pdfData: pdfData, savedPdfPath: '/test/test_receipt.pdf');

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

  // ---------------------------------------------------------------------------
  // finalizeMultiPageSession
  // ---------------------------------------------------------------------------

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
