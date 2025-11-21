import 'dart:typed_data';

import '../models/scanned_document.dart';
import '../models/scan_result.dart';
import 'camera_service.dart';
import 'storage_helper.dart';
import 'pdf_generator.dart';
import 'qr_scanner_service.dart';
import 'image_processor.dart';

/// Main orchestrator service for document scanning operations
/// Delegates capture/import to CameraService, uses StorageHelper for file operations,
/// and pipes data through ImageProcessor/PdfGenerator
class DocumentScannerService {
  factory DocumentScannerService() => _instance;

  DocumentScannerService._internal({
    CameraService? cameraService,
    StorageHelper? storageHelper,
    PdfGenerator? pdfGenerator,
    QRScannerService? qrScanner,
    ImageProcessor? imageProcessor,
  })  : _cameraService = cameraService ?? CameraService(),
        _storageHelper = storageHelper ?? StorageHelper(),
        _pdfGenerator = pdfGenerator ?? PdfGenerator(),
        _qrScanner = qrScanner ?? QRScannerService(),
        _imageProcessor = imageProcessor ?? ImageProcessor();

  static final DocumentScannerService _instance = DocumentScannerService._internal();

  DocumentScannerService.withDependencies({
    required CameraService cameraService,
    required StorageHelper storageHelper,
    required PdfGenerator pdfGenerator,
    required QRScannerService qrScanner,
    required ImageProcessor imageProcessor,
  }) : this._internal(
          cameraService: cameraService,
          storageHelper: storageHelper,
          pdfGenerator: pdfGenerator,
          qrScanner: qrScanner,
          imageProcessor: imageProcessor,
        );

  final CameraService _cameraService;
  final StorageHelper _storageHelper;
  final PdfGenerator _pdfGenerator;
  final QRScannerService _qrScanner;
  final ImageProcessor _imageProcessor;

  /// Configure storage directory and app name for file operations
  /// This must be called before any scanning operations to avoid hardcoded paths
  void configureStorage({
    String? customStorageDirectory,
    String? appName,
    String? pdfBrandingText,
  }) {
    _storageHelper.configure(StorageConfig(
      customDirectory: customStorageDirectory,
      appName: appName,
    ));
  }

  /// Scan a document using camera
  Future<ScanResult> scanDocument({
    required DocumentType documentType,
    DocumentProcessingOptions? processingOptions,
    String? customFilename,
    bool autoProcess = false,
  }) async {
    try {
      final captureResult = await _cameraService.captureFromCamera();

      if (!captureResult.success) {
        if (captureResult.cancelled) {
          return ScanResult.cancelled();
        }
        return ScanResult.error(error: captureResult.error ?? 'Camera capture failed');
      }

      final options = processingOptions ?? _getDefaultOptions(documentType);

      if (autoProcess) {
        return await _processAndSaveDocument(
          rawImageData: captureResult.imageData!,
          originalPath: captureResult.path!,
          documentType: documentType,
          processingOptions: options,
          customFilename: customFilename,
          source: 'camera',
          resizeInfo: captureResult.resizeInfo,
        );
      }

      final metadata = <String, dynamic>{
        'source': 'camera',
        'originalSize': captureResult.imageData!.length,
      };
      
      // Add resize information if available
      if (captureResult.resizeInfo != null) {
        metadata.addAll(captureResult.resizeInfo!.toMetadata());
      }

      final document = ScannedDocument(
        id: _generateId(),
        type: documentType,
        originalPath: captureResult.path!,
        scanTime: DateTime.now(),
        processingOptions: options,
        rawImageData: captureResult.imageData,
        metadata: metadata,
      );

      return ScanResult.success(document: document);
    } catch (e) {
      return ScanResult.error(error: 'Failed to scan document: $e');
    }
  }

  /// Import document from gallery
  Future<ScanResult> importDocument({
    required DocumentType documentType,
    DocumentProcessingOptions? processingOptions,
    String? customFilename,
  }) async {
    try {
      final captureResult = await _cameraService.importFromGallery();

      if (!captureResult.success) {
        if (captureResult.cancelled) {
          return ScanResult.cancelled();
        }
        return ScanResult.error(error: captureResult.error ?? 'Gallery import failed');
      }

      final options = processingOptions ?? _getDefaultOptions(documentType);

      final metadata = <String, dynamic>{
        'source': 'gallery',
        'originalSize': captureResult.imageData!.length,
      };
      
      // Add resize information if available
      if (captureResult.resizeInfo != null) {
        metadata.addAll(captureResult.resizeInfo!.toMetadata());
      }

      final document = ScannedDocument(
        id: _generateId(),
        type: documentType,
        originalPath: captureResult.path!,
        scanTime: DateTime.now(),
        processingOptions: options,
        rawImageData: captureResult.imageData,
        metadata: metadata,
      );

      return ScanResult.success(document: document);
    } catch (e) {
      return ScanResult.error(error: 'Failed to import document: $e');
    }
  }

  /// Scan document with automatic processing and file saving (bypasses image editor)
  /// Returns ScannedDocument with populated pdfPath and processedPath
  Future<ScanResult> scanDocumentWithProcessing({
    required DocumentType documentType,
    DocumentProcessingOptions? processingOptions,
    String? customFilename,
  }) async {
    try {
      final captureResult = await _cameraService.captureFromCamera();

      if (!captureResult.success) {
        if (captureResult.cancelled) {
          return ScanResult.cancelled();
        }
        return ScanResult.error(error: captureResult.error ?? 'Camera capture failed');
      }

      final options = processingOptions ?? _getDefaultOptions(documentType);

      return await _processAndSaveDocument(
        rawImageData: captureResult.imageData!,
        originalPath: captureResult.path!,
        documentType: documentType,
        processingOptions: options,
        customFilename: customFilename,
        source: 'camera',
        resizeInfo: captureResult.resizeInfo,
      );
    } catch (e) {
      return ScanResult.error(error: 'Failed to scan and process document: $e');
    }
  }

  /// Import document with automatic processing and file saving (bypasses image editor)
  /// Returns ScannedDocument with populated pdfPath and processedPath
  Future<ScanResult> importDocumentWithProcessing({
    required DocumentType documentType,
    DocumentProcessingOptions? processingOptions,
    String? customFilename,
  }) async {
    try {
      final captureResult = await _cameraService.importFromGallery();

      if (!captureResult.success) {
        if (captureResult.cancelled) {
          return ScanResult.cancelled();
        }
        return ScanResult.error(error: captureResult.error ?? 'Gallery import failed');
      }

      final options = processingOptions ?? _getDefaultOptions(documentType);

      return await _processAndSaveDocument(
        rawImageData: captureResult.imageData!,
        originalPath: captureResult.path!,
        documentType: documentType,
        processingOptions: options,
        customFilename: customFilename,
        source: 'gallery',
        resizeInfo: captureResult.resizeInfo,
      );
    } catch (e) {
      return ScanResult.error(error: 'Failed to import and process document: $e');
    }
  }

  /// Scan QR code for manual download
  Future<QRScanResult> scanQRCode() async {
    try {
      final hasPermission = await _cameraService.requestCameraPermission();
      if (!hasPermission) {
        return QRScanResult.error(
          error: 'Camera permission denied',
          qrData: '',
        );
      }

      return await _qrScanner.scanQRCode();
    } catch (e) {
      return QRScanResult.error(
        error: 'Failed to scan QR code: $e',
        qrData: '',
      );
    }
  }

  /// Scan QR code and automatically download document if URL is detected
  Future<ScanResult> scanQRCodeAndDownload({
    String? customFilename,
  }) async {
    try {
      final hasCameraPermission = await _cameraService.requestCameraPermission();
      if (!hasCameraPermission) {
        return ScanResult.error(error: 'Camera permission denied');
      }

      final hasStoragePermission = await _cameraService.requestStoragePermission();
      if (!hasStoragePermission) {
        return ScanResult.error(error: 'Storage permission denied');
      }

      final qrResult = await _qrScanner.scanQRCode();

      if (!qrResult.success) {
        return ScanResult.error(error: qrResult.error ?? 'QR scan failed');
      }

      if (qrResult.contentType == QRContentType.pdfLink ||
          qrResult.contentType == QRContentType.manualLink) {
        try {
          final downloadResult = await downloadManualFromUrl(
            url: qrResult.qrData,
            customFilename: customFilename,
          );

          return downloadResult;
        } catch (e) {
          return ScanResult.error(
            error: 'Failed to download from QR URL: $e',
            metadata: {
              'qrData': qrResult.qrData,
              'qrContentType': qrResult.contentType.toString(),
            },
          );
        }
      } else {
        return ScanResult.error(
          error: 'QR code does not contain a downloadable document link.\nContent: ${qrResult.qrData}\nType: ${qrResult.contentType}',
          metadata: {
            'qrData': qrResult.qrData,
            'qrContentType': qrResult.contentType.toString(),
          },
        );
      }
    } catch (e) {
      return ScanResult.error(error: 'Failed to scan QR code and download: $e');
    }
  }

  /// Download manual from URL (from QR code)
  Future<ScanResult> downloadManualFromUrl({
    required String url,
    String? customFilename,
  }) async {
    try {
      final hasStoragePermission = await _cameraService.requestStoragePermission();
      if (!hasStoragePermission) {
        return ScanResult.error(error: 'Storage permission denied');
      }

      final document = await _qrScanner.downloadManualFromUrl(url);
      if (document == null) {
        return ScanResult.error(error: 'Failed to download manual from URL');
      }

      final savedDocument = await _saveToExternalStorage(document, customFilename);
      return ScanResult.success(
        document: savedDocument,
        type: ScanResultType.download,
      );
    } catch (e) {
      return ScanResult.error(error: 'Failed to download manual: $e');
    }
  }

  /// Finalize scan result after image editing (used by widgets)
  /// This method handles PDF generation and external storage saving for edited documents
  Future<ScanResult> finalizeScanResult(
    ScannedDocument document,
    String? customFilename,
  ) async {
    try {
      Uint8List? pdfData = document.pdfData;
      if (pdfData == null && document.processingOptions.generatePdf) {
        final imageData = document.processedImageData ?? document.rawImageData;
        if (imageData != null) {
          pdfData = await _pdfGenerator.generatePdf(
            imageData: imageData,
            documentType: document.type,
            resolution: document.processingOptions.pdfResolution,
            documentFormat: document.processingOptions.documentFormat,
            metadata: document.metadata,
          );
        }
      }

      final updatedDocument = document.copyWith(
        pdfData: pdfData,
        metadata: {
          ...document.metadata,
          'finalized': true,
          'finalizedAt': DateTime.now().toIso8601String(),
          'pdfSize': pdfData?.length,
        },
      );

      final savedDocument = await _saveToExternalStorage(
        updatedDocument,
        customFilename,
      );

      return ScanResult.success(document: savedDocument);
    } catch (e) {
      return ScanResult.error(error: 'Failed to finalize scan result: $e');
    }
  }

  /// Finalize multi-page document session
  /// Combines all pages into a single PDF and saves to storage
  Future<ScanResult> finalizeMultiPageSession(
    MultiPageScanSession session, {
    String? customFilename,
  }) async {
    try {
      if (!session.isReadyForFinalization) {
        return ScanResult.error(error: 'No pages to finalize');
      }

      final hasStoragePermission = await _cameraService.requestStoragePermission();
      if (!hasStoragePermission) {
        return ScanResult.error(error: 'Storage permission denied');
      }

      final pageImages = <Uint8List>[];
      for (final page in session.pages) {
        final imageData = page.processedImageData ?? page.rawImageData;
        if (imageData != null) {
          pageImages.add(imageData);
        }
      }

      if (pageImages.isEmpty) {
        return ScanResult.error(error: 'No valid page images to finalize');
      }

      Uint8List? pdfData;
      if (session.processingOptions.generatePdf) {
        pdfData = await _pdfGenerator.generateMultiPagePdf(
          imageDataList: pageImages,
          documentType: session.documentType,
          resolution: session.processingOptions.pdfResolution,
          documentFormat: session.processingOptions.documentFormat,
          metadata: {
            'pageCount': session.pages.length,
            'sessionStartTime': session.startTime.toIso8601String(),
          },
        );
      }

      final document = session.toScannedDocument().copyWith(
        pdfData: pdfData,
        metadata: {
          ...session.toScannedDocument().metadata,
          'finalized': true,
          'finalizedAt': DateTime.now().toIso8601String(),
          'pdfSize': pdfData?.length,
        },
      );

      final savedDocument = await _saveToExternalStorage(
        document,
        customFilename ?? session.customFilename,
      );

      return ScanResult.success(document: savedDocument);
    } catch (e) {
      return ScanResult.error(error: 'Failed to finalize multi-page session: $e');
    }
  }

  /// Internal method to process and save document
  Future<ScanResult> _processAndSaveDocument({
    required Uint8List rawImageData,
    required String originalPath,
    required DocumentType documentType,
    required DocumentProcessingOptions processingOptions,
    required String source,
    String? customFilename,
    ImageResizeInfo? resizeInfo,
  }) async {
    try {
      final processedImageData = await _imageProcessor.processImage(
        rawImageData,
        processingOptions,
      );

      Uint8List? pdfData;
      if (processingOptions.generatePdf) {
        pdfData = await _pdfGenerator.generatePdf(
          imageData: processedImageData,
          documentType: documentType,
          resolution: processingOptions.pdfResolution,
          documentFormat: processingOptions.documentFormat,
          metadata: {
            'source': source,
            'originalSize': rawImageData.length,
            'processedSize': processedImageData.length,
            'autoProcessed': true,
          },
        );
      }

      final metadata = <String, dynamic>{
        'source': source,
        'originalSize': rawImageData.length,
        'processedSize': processedImageData.length,
        'pdfSize': pdfData?.length,
        'autoProcessed': true,
        'finalized': true,
        'finalizedAt': DateTime.now().toIso8601String(),
      };
      
      // Add resize information if available
      if (resizeInfo != null) {
        metadata.addAll(resizeInfo.toMetadata());
      }

      final document = ScannedDocument(
        id: _generateId(),
        type: documentType,
        originalPath: originalPath,
        scanTime: DateTime.now(),
        processingOptions: processingOptions,
        rawImageData: rawImageData,
        processedImageData: processedImageData,
        pdfData: pdfData,
        metadata: metadata,
      );

      final savedDocument = await _saveToExternalStorage(
        document,
        customFilename,
      );

      return ScanResult.success(document: savedDocument);
    } catch (e) {
      return ScanResult.error(error: 'Failed to process and save document: $e');
    }
  }

  /// Save document to external storage
  Future<ScannedDocument> _saveToExternalStorage(
    ScannedDocument document,
    String? customFilename,
  ) async {
    final directory = await _storageHelper.getExternalStorageDirectory();
    final timestamp = DateTime.now();

    final filename = _storageHelper.generateFilename(
      documentType: document.type,
      timestamp: timestamp,
      customFilename: customFilename,
      metadata: document.metadata,
    );

    String? processedPath;
    String? pdfPath;

    if (document.processedImageData != null && document.processingOptions.saveImageFile) {
      processedPath = await _storageHelper.saveImageFile(
        directory: directory,
        filename: filename,
        imageData: document.processedImageData!,
      );
    }

    if (document.pdfData != null) {
      pdfPath = await _storageHelper.savePdfFile(
        directory: directory,
        filename: filename,
        pdfData: document.pdfData!,
      );
    }

    return document.copyWith(
      processedPath: processedPath,
      pdfPath: pdfPath,
      metadata: {
        ...document.metadata,
        'savedAt': timestamp.toIso8601String(),
        'externalPath': directory.path,
      },
    );
  }

  /// Get default processing options for document type
  DocumentProcessingOptions _getDefaultOptions(DocumentType type) {
    switch (type) {
      case DocumentType.receipt:
        return DocumentProcessingOptions.receipt;
      case DocumentType.manual:
        return DocumentProcessingOptions.manual;
      case DocumentType.document:
        return DocumentProcessingOptions.document;
      case DocumentType.other:
        return DocumentProcessingOptions.document;
    }
  }

  /// Generate unique ID for document
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
