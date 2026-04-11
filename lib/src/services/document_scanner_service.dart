import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../models/scanned_document.dart';
import '../models/scan_result.dart';
import 'camera_service.dart';
import 'storage_helper.dart';
import 'pdf_generator.dart';
import 'qr_scanner_service.dart';
import 'image_processor.dart';
import '../ui/image_editing_widget.dart';
import '../ui/pdf_preview_widget.dart';

/// Main orchestrator service for document scanning operations.
///
/// Delegates capture/import to [CameraService], uses [StorageHelper] for file
/// operations, and pipes data through [ImageProcessor] / [PdfGenerator].
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

  static final DocumentScannerService _instance =
      DocumentScannerService._internal();

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

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Configure storage directory and app name for file operations.
  /// Must be called before any scanning operations.
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

  // ---------------------------------------------------------------------------
  // Scan / Import — unified capture entry points
  // ---------------------------------------------------------------------------

  /// Scan a document using the camera.
  ///
  /// When [autoProcess] is true the document is processed and saved immediately
  /// (same behaviour as [scanDocumentWithProcessing]).
  Future<ScanResult> scanDocument({
    required DocumentType documentType,
    DocumentProcessingOptions? processingOptions,
    String? customFilename,
    bool autoProcess = false,
  }) =>
      _captureAndProcess(
        source: _CaptureSource.camera,
        documentType: documentType,
        processingOptions: processingOptions,
        customFilename: customFilename,
        autoProcess: autoProcess,
      );

  /// Import a document from the gallery.
  Future<ScanResult> importDocument({
    required DocumentType documentType,
    DocumentProcessingOptions? processingOptions,
    String? customFilename,
  }) =>
      _captureAndProcess(
        source: _CaptureSource.gallery,
        documentType: documentType,
        processingOptions: processingOptions,
        customFilename: customFilename,
        autoProcess: false,
      );

  /// Scan with automatic processing and file saving (bypasses image editor).
  /// Returns [ScannedDocument] with populated [pdfPath] and [processedPath].
  Future<ScanResult> scanDocumentWithProcessing({
    required DocumentType documentType,
    DocumentProcessingOptions? processingOptions,
    String? customFilename,
  }) =>
      _captureAndProcess(
        source: _CaptureSource.camera,
        documentType: documentType,
        processingOptions: processingOptions,
        customFilename: customFilename,
        autoProcess: true,
      );

  /// Import with automatic processing and file saving (bypasses image editor).
  /// Returns [ScannedDocument] with populated [pdfPath] and [processedPath].
  Future<ScanResult> importDocumentWithProcessing({
    required DocumentType documentType,
    DocumentProcessingOptions? processingOptions,
    String? customFilename,
  }) =>
      _captureAndProcess(
        source: _CaptureSource.gallery,
        documentType: documentType,
        processingOptions: processingOptions,
        customFilename: customFilename,
        autoProcess: true,
      );

  // ---------------------------------------------------------------------------
  // QR code
  // ---------------------------------------------------------------------------

  /// Scan a QR code for manual download.
  Future<QRScanResult> scanQRCode() async {
    try {
      final hasPermission = await _cameraService.requestCameraPermission();
      if (!hasPermission) {
        return QRScanResult.error(error: 'Camera permission denied', qrData: '');
      }
      return await _qrScanner.scanQRCode();
    } catch (e) {
      return QRScanResult.error(error: 'Failed to scan QR code: $e', qrData: '');
    }
  }

  /// Scan a QR code and download the document if a URL is detected.
  Future<ScanResult> scanQRCodeAndDownload({String? customFilename}) async {
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
        return await downloadManualFromUrl(
          url: qrResult.qrData,
          customFilename: customFilename,
        );
      }

      return ScanResult.error(
        error: 'QR code does not contain a downloadable document link.\n'
            'Content: ${qrResult.qrData}\nType: ${qrResult.contentType}',
        metadata: {
          'qrData': qrResult.qrData,
          'qrContentType': qrResult.contentType.toString(),
        },
      );
    } catch (e) {
      return ScanResult.error(error: 'Failed to scan QR code and download: $e');
    }
  }

  /// Download a document from a URL (typically obtained from a QR code).
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
      return ScanResult.success(document: savedDocument, type: ScanResultType.download);
    } catch (e) {
      return ScanResult.error(error: 'Failed to download manual: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Finalization
  // ---------------------------------------------------------------------------

  /// Finalize a scan result after image editing.
  ///
  /// Generates a PDF (if configured) and saves the document to external storage.
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

      final savedDocument = await _saveToExternalStorage(updatedDocument, customFilename);
      return ScanResult.success(document: savedDocument);
    } catch (e) {
      return ScanResult.error(error: 'Failed to finalize scan result: $e');
    }
  }

  /// Finalize a multi-page document session.
  ///
  /// Combines all pages into a single PDF and saves to storage.
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

      final pageImages = <Uint8List>[
        for (final page in session.pages)
          if (page.processedImageData ?? page.rawImageData case final data?)
            data,
      ];

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

  // ---------------------------------------------------------------------------
  // Image editor flow
  // ---------------------------------------------------------------------------

  /// Show the image editor and handle the complete editing flow.
  ///
  /// Can be used by both [DocumentScannerWidget] and quick actions.
  /// Returns the final [ScanResult] after editing, preview, and finalization.
  Future<ScanResult> showImageEditorFlow({
    required BuildContext context,
    required ScannedDocument document,
    String? customFilename,
    DocumentProcessingOptions? processingOptions,
  }) async {
    if (document.rawImageData == null) {
      return ScanResult.error(error: 'No image data available for editing');
    }

    try {
      final editResult = await Navigator.push<Map<String, dynamic>?>(
        context,
        MaterialPageRoute(
          builder: (context) => ImageEditingWidget(
            imageData: document.rawImageData!,
            initialPreviewData: document.processedImageData,
            initialCropCorners: _extractCornersFromMetadata(document.metadata),
            onImageEdited: (editedData, selectedResolution, selectedFormat) {
              Navigator.pop(context, {
                'imageData': editedData,
                'resolution': selectedResolution,
                'format': selectedFormat,
              });
            },
            onCancel: () => Navigator.pop(context, null),
          ),
        ),
      );

      if (editResult == null) {
        return ScanResult.error(error: 'Editing cancelled', type: ScanResultType.scan);
      }

      final editedImageData = editResult['imageData'] as Uint8List;
      final selectedResolution = editResult['resolution'] as PdfResolution;
      final selectedFormat = editResult['format'] as DocumentFormat;

      final updatedProcessingOptions = DocumentProcessingOptions(
        convertToGrayscale: processingOptions?.convertToGrayscale ?? true,
        enhanceContrast: processingOptions?.enhanceContrast ?? true,
        autoCorrectPerspective: processingOptions?.autoCorrectPerspective ?? true,
        compressionQuality: processingOptions?.compressionQuality ?? 0.8,
        outputFormat: processingOptions?.outputFormat ?? ImageFormat.jpeg,
        generatePdf: processingOptions?.generatePdf ?? true,
        saveImageFile: processingOptions?.saveImageFile ?? false,
        pdfResolution: selectedResolution,
        documentFormat: selectedFormat,
        customFilename: processingOptions?.customFilename,
      );

      final editedDocument = ScannedDocument(
        id: document.id,
        type: document.type,
        originalPath: document.originalPath,
        scanTime: document.scanTime,
        processingOptions: updatedProcessingOptions,
        processedPath: document.processedPath,
        pdfPath: document.pdfPath,
        rawImageData: document.rawImageData,
        processedImageData: editedImageData,
        pdfData: document.pdfData,
        pages: document.pages,
        isMultiPage: document.isMultiPage,
        metadata: {
          ...document.metadata,
          'edited': true,
          'editedAt': DateTime.now().toIso8601String(),
          'selectedResolution': selectedResolution.name,
          'selectedFormat': selectedFormat.name,
        },
      );

      final finalResult = await finalizeScanResult(editedDocument, customFilename);

      if (finalResult.success && finalResult.document?.pdfData != null) {
        await _showPdfPreview(context, finalResult.document!);
      }
      return finalResult;
    } catch (e) {
      return ScanResult.error(error: 'Error during image editing: $e', type: ScanResultType.scan);
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Unified capture → optional auto-crop → optional auto-process pipeline.
  Future<ScanResult> _captureAndProcess({
    required _CaptureSource source,
    required DocumentType documentType,
    DocumentProcessingOptions? processingOptions,
    String? customFilename,
    required bool autoProcess,
  }) async {
    try {
      final captureResult = source == _CaptureSource.camera
          ? await _cameraService.captureFromCamera()
          : await _cameraService.importFromGallery();

      if (!captureResult.success) {
        if (captureResult.cancelled) return ScanResult.cancelled();
        return ScanResult.error(
          error: captureResult.error ?? '${source.label} failed',
        );
      }

      final options = processingOptions ?? _getDefaultOptions(documentType);

      // Fast path: process + save immediately, skip editor
      if (autoProcess) {
        return await _processAndSaveDocument(
          rawImageData: captureResult.imageData!,
          originalPath: captureResult.path!,
          documentType: documentType,
          processingOptions: options,
          customFilename: customFilename,
          source: source.label,
          resizeInfo: captureResult.resizeInfo,
        );
      }

      // Editor path: optionally auto-crop, then return raw document for editing
      Uint8List? processedImageData;
      Map<String, dynamic>? autoCropMetadata;

      if (options.autoCorrectPerspective) {
        try {
          final processingResult = await _imageProcessor.processImageWithAutoCrop(
            captureResult.imageData!,
            options,
          );
          processedImageData = processingResult['processedImageData'] as Uint8List;
          autoCropMetadata = processingResult['metadata'] as Map<String, dynamic>;
        } catch (_) {
          // Auto-crop failure is non-fatal; continue with original image
        }
      }

      final metadata = <String, dynamic>{
        'source': source.label,
        'originalSize': captureResult.imageData!.length,
        if (captureResult.resizeInfo != null)
          ...captureResult.resizeInfo!.toMetadata(),
        if (autoCropMetadata != null) ...autoCropMetadata,
      };

      final document = ScannedDocument(
        id: _generateId(),
        type: documentType,
        originalPath: captureResult.path!,
        scanTime: DateTime.now(),
        processingOptions: options,
        rawImageData: captureResult.imageData,
        processedImageData: processedImageData,
        metadata: metadata,
      );

      return ScanResult.success(document: document);
    } catch (e) {
      return ScanResult.error(error: 'Failed to ${source.label} document: $e');
    }
  }

  /// Process raw image data and save to external storage.
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
      final processingResult = await _imageProcessor.processImageWithAutoCrop(
        rawImageData,
        processingOptions,
      );

      final processedImageData = processingResult['processedImageData'] as Uint8List;
      final detectedEdges = processingResult['detectedEdges'] as List<Offset>;
      final autoCropMetadata = processingResult['metadata'] as Map<String, dynamic>;

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
            'autoCrop': autoCropMetadata['autoCrop'],
            'detectedEdges': detectedEdges
                .map((o) => {'dx': o.dx, 'dy': o.dy})
                .toList(),
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
        'autoCrop': autoCropMetadata['autoCrop'],
        'detectedEdges': detectedEdges
            .map((o) => {'dx': o.dx, 'dy': o.dy})
            .toList(),
        if (resizeInfo != null) ...resizeInfo.toMetadata(),
      };

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

      final savedDocument = await _saveToExternalStorage(document, customFilename);
      return ScanResult.success(document: savedDocument);
    } catch (e) {
      return ScanResult.error(error: 'Failed to process and save document: $e');
    }
  }

  /// Save document to configured external storage.
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

    if (document.processedImageData != null &&
        document.processingOptions.saveImageFile) {
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

  Future<void> _showPdfPreview(
    BuildContext context,
    ScannedDocument document,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfPreviewWidget(
          pdfData: document.pdfData,
          pdfPath: document.pdfPath,
          title: 'Document Preview',
          onConfirm: () => Navigator.pop(context),
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  DocumentProcessingOptions _getDefaultOptions(DocumentType type) {
    switch (type) {
      case DocumentType.receipt:
        return DocumentProcessingOptions.receipt;
      case DocumentType.manual:
        return DocumentProcessingOptions.manual;
      case DocumentType.document:
      case DocumentType.other:
        return DocumentProcessingOptions.document;
    }
  }

  String _generateId() {
    return '${DateTime.now().microsecondsSinceEpoch}';
  }

  List<Offset>? _extractCornersFromMetadata(Map<String, dynamic> metadata) {
    final detectedEdges = metadata['detectedEdges'] as List<dynamic>?;
    if (detectedEdges == null || detectedEdges.isEmpty) return null;
    try {
      return detectedEdges.map((edge) {
        final edgeMap = edge as Map<String, dynamic>;
        return Offset(
          (edgeMap['dx'] as num).toDouble(),
          (edgeMap['dy'] as num).toDouble(),
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }
}

/// Internal enum to distinguish capture sources without string comparison.
enum _CaptureSource {
  camera('camera'),
  gallery('gallery');

  const _CaptureSource(this.label);
  final String label;
}
