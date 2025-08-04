import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/scanned_document.dart';
import '../models/scan_result.dart';
import 'pdf_generator.dart';
import 'qr_scanner_service.dart';
import 'image_processor.dart';

/// Main service for document scanning operations
class DocumentScannerService {
  static final DocumentScannerService _instance = DocumentScannerService._internal();
  factory DocumentScannerService() => _instance;
  DocumentScannerService._internal();

  final ImagePicker _imagePicker = ImagePicker();
  final PdfGenerator _pdfGenerator = PdfGenerator();
  final QRScannerService _qrScanner = QRScannerService();
  final ImageProcessor _imageProcessor = ImageProcessor();
  
  // Storage configuration - made configurable to remove hardcoded paths
  String? _customStorageDirectory;
  String? _customAppName;
  
  /// Configure storage directory and app name for file operations
  /// This must be called before any scanning operations to avoid hardcoded paths
  void configureStorage({
    String? customStorageDirectory,
    String? appName,
    String? pdfBrandingText, // Kept for backward compatibility but no longer used
  }) {
    _customStorageDirectory = customStorageDirectory;
    _customAppName = appName;
    
    // Note: PDF branding is no longer supported as PDFs are now minimal
    // The pdfBrandingText parameter is kept for backward compatibility
  }

  /// Scan a document using camera
  Future<ScanResult> scanDocument({
    required DocumentType documentType,
    DocumentProcessingOptions? processingOptions,
    String? customFilename,
    bool autoProcess = false, // AIDEV-NOTE: Added for backward compatibility with RobaMia
  }) async {
    try {
      // Check camera permission
      final hasCameraPermission = await _checkCameraPermission();
      if (!hasCameraPermission) {
        return ScanResult.error(error: 'Camera permission denied');
      }

      // Check storage permission (needed to save processed document)
      final hasStoragePermission = await _checkStoragePermission();
      if (!hasStoragePermission) {
        return ScanResult.error(error: 'Storage permission denied');
      }

      // Get processing options based on document type
      final options = processingOptions ?? _getDefaultOptions(documentType);

      // Capture image
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );

      if (image == null) {
        return ScanResult.cancelled();
      }

      // Read image data
      final rawImageData = await image.readAsBytes();

      // AIDEV-NOTE: Backward compatibility - auto-process when requested
      if (autoProcess) {
        print('🔍 SCANNER DEBUG: Auto-processing enabled for backward compatibility');
        return await _processAndSaveDocument(
          rawImageData: rawImageData,
          originalPath: image.path,
          documentType: documentType,
          processingOptions: options,
          customFilename: customFilename,
          source: 'camera',
        );
      }

      // Create scanned document
      final document = ScannedDocument(
        id: _generateId(),
        type: documentType,
        originalPath: image.path,
        scanTime: DateTime.now(),
        processingOptions: options,
        rawImageData: rawImageData,
        metadata: {
          'source': 'camera',
          'originalSize': rawImageData.length,
        },
      );

      // Return raw document for editing workflow
      // The widget will handle image editing and finalization
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
      // Check permissions
      final hasPermission = await _checkStoragePermission();
      if (!hasPermission) {
        return ScanResult.error(error: 'Storage permission denied');
      }

      final options = processingOptions ?? _getDefaultOptions(documentType);

      // Pick image from gallery
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (image == null) {
        return ScanResult.cancelled();
      }

      final document = ScannedDocument(
        id: _generateId(),
        type: documentType,
        originalPath: image.path,
        scanTime: DateTime.now(),
        processingOptions: options,
        rawImageData: await image.readAsBytes(),
        metadata: {
          'source': 'gallery',
          'originalSize': await image.length(),
        },
      );

      // Return raw document for editing workflow
      // The widget will handle image editing and finalization
      return ScanResult.success(document: document);
    } catch (e) {
      return ScanResult.error(error: 'Failed to import document: $e');
    }
  }

  /// Scan document with automatic processing and file saving (bypasses image editor)
  /// AIDEV-NOTE: Added for RobaMia integration - processes and saves files directly
  /// Returns ScannedDocument with populated pdfPath and processedPath
  Future<ScanResult> scanDocumentWithProcessing({
    required DocumentType documentType,
    DocumentProcessingOptions? processingOptions,
    String? customFilename,
  }) async {
    try {
      // Check camera permission
      final hasCameraPermission = await _checkCameraPermission();
      if (!hasCameraPermission) {
        return ScanResult.error(error: 'Camera permission denied');
      }

      // Check storage permission (needed to save processed document)
      final hasStoragePermission = await _checkStoragePermission();
      if (!hasStoragePermission) {
        return ScanResult.error(error: 'Storage permission denied');
      }

      // Get processing options based on document type
      final options = processingOptions ?? _getDefaultOptions(documentType);

      // Capture image
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );

      if (image == null) {
        return ScanResult.cancelled();
      }

      // Read image data and process using shared method
      final rawImageData = await image.readAsBytes();
      
      return await _processAndSaveDocument(
        rawImageData: rawImageData,
        originalPath: image.path,
        documentType: documentType,
        processingOptions: options,
        customFilename: customFilename,
        source: 'camera',
      );
    } catch (e) {
      return ScanResult.error(error: 'Failed to scan and process document: $e');
    }
  }

  /// Import document with automatic processing and file saving (bypasses image editor)
  /// AIDEV-NOTE: Added for RobaMia integration - processes and saves files directly  
  /// Returns ScannedDocument with populated pdfPath and processedPath
  Future<ScanResult> importDocumentWithProcessing({
    required DocumentType documentType,
    DocumentProcessingOptions? processingOptions,
    String? customFilename,
  }) async {
    try {
      // Check permissions
      final hasPermission = await _checkStoragePermission();
      if (!hasPermission) {
        return ScanResult.error(error: 'Storage permission denied');
      }

      final options = processingOptions ?? _getDefaultOptions(documentType);

      // Pick image from gallery
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (image == null) {
        return ScanResult.cancelled();
      }

      // Read image data and process using shared method
      final rawImageData = await image.readAsBytes();
      
      return await _processAndSaveDocument(
        rawImageData: rawImageData,
        originalPath: image.path,
        documentType: documentType,
        processingOptions: options,
        customFilename: customFilename,
        source: 'gallery',
      );
    } catch (e) {
      return ScanResult.error(error: 'Failed to import and process document: $e');
    }
  }

  /// Scan QR code for manual download
  Future<QRScanResult> scanQRCode() async {
    try {
      final hasPermission = await _checkCameraPermission();
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
      final hasCameraPermission = await _checkCameraPermission();
      if (!hasCameraPermission) {
        return ScanResult.error(error: 'Camera permission denied');
      }

      // Check storage permission (needed to save downloaded document)
      final hasStoragePermission = await _checkStoragePermission();
      if (!hasStoragePermission) {
        return ScanResult.error(error: 'Storage permission denied');
      }

      // First scan the QR code
      final qrResult = await _qrScanner.scanQRCode();
      
      if (!qrResult.success) {
        return ScanResult.error(error: qrResult.error ?? 'QR scan failed');
      }

      // Check if QR contains a downloadable link
      if (qrResult.contentType == QRContentType.pdfLink || 
          qrResult.contentType == QRContentType.manualLink) {
        
        // Automatically download the document
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
        // QR doesn't contain a downloadable link
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
      // Check storage permission (needed to save downloaded document)
      final hasStoragePermission = await _checkStoragePermission();
      if (!hasStoragePermission) {
        return ScanResult.error(error: 'Storage permission denied');
      }
      final document = await _qrScanner.downloadManualFromUrl(url);
      if (document == null) {
        return ScanResult.error(error: 'Failed to download manual from URL');
      }

      // Save to external storage with custom filename
      final savedDocument = await _saveToExternalStorage(document, customFilename);
      return ScanResult.success(
        document: savedDocument,
        type: ScanResultType.download,
      );
    } catch (e) {
      return ScanResult.error(error: 'Failed to download manual: $e');
    }
  }


  /// Save document to external storage with appropriate naming
  Future<ScannedDocument> _saveToExternalStorage(
    ScannedDocument document,
    String? customFilename,
  ) async {
    final directory = await _getExternalStorageDirectory();
    final timestamp = DateTime.now();
    
    // Generate filename based on document type, custom name, and metadata
    final filename = customFilename ?? _generateFilename(document.type, timestamp, document.metadata);
    
    // AIDEV-DEBUG: Log before saving files
    print('🔍 SCANNER DEBUG: _saveToExternalStorage called');
    print('🔍 Directory: ${directory.path}');
    print('🔍 Filename: $filename');
    print('🔍 ProcessedImageData exists: ${document.processedImageData != null}');
    print('🔍 ProcessedImageData size: ${document.processedImageData?.length ?? 0}');
    print('🔍 SaveImageFile option: ${document.processingOptions.saveImageFile}');
    print('🔍 PdfData exists: ${document.pdfData != null}');
    print('🔍 PdfData size: ${document.pdfData?.length ?? 0}');
    print('🔍 GeneratePdf option: ${document.processingOptions.generatePdf}');
    
    // Save processed image only if explicitly requested
    String? processedPath;
    if (document.processedImageData != null && document.processingOptions.saveImageFile) {
      final imageFile = File(path.join(directory.path, '${filename}.jpg'));
      await imageFile.writeAsBytes(document.processedImageData!);
      processedPath = imageFile.path;
      print('✅ SCANNER DEBUG: Processed image saved to: $processedPath');
    } else {
      print('⚠️ SCANNER DEBUG: Processed image NOT saved. Data null: ${document.processedImageData == null}, SaveImageFile: ${document.processingOptions.saveImageFile}');
    }

    // Save PDF (priority over JPG when both are enabled)
    String? pdfPath;
    if (document.pdfData != null) {
      final pdfFile = File(path.join(directory.path, '${filename}.pdf'));
      await pdfFile.writeAsBytes(document.pdfData!);
      pdfPath = pdfFile.path;
      print('✅ SCANNER DEBUG: PDF saved to: $pdfPath');
    } else {
      print('❌ SCANNER DEBUG: PDF NOT saved - pdfData is null!');
    }

    // AIDEV-DEBUG: Log final paths before copyWith
    print('🔍 SCANNER DEBUG: Final paths before copyWith:');
    print('🔍 processedPath: $processedPath');
    print('🔍 pdfPath: $pdfPath');

    final updatedDocument = document.copyWith(
      processedPath: processedPath,
      pdfPath: pdfPath,
      metadata: {
        ...document.metadata,
        'savedAt': timestamp.toIso8601String(),
        'externalPath': directory.path,
      },
    );

    // AIDEV-DEBUG: Log paths after copyWith
    print('✅ SCANNER DEBUG: Updated document paths:');
    print('✅ updatedDocument.processedPath: ${updatedDocument.processedPath}');
    print('✅ updatedDocument.pdfPath: ${updatedDocument.pdfPath}');

    return updatedDocument;
  }

  /// Get external storage directory for documents
  Future<Directory> _getExternalStorageDirectory() async {
    if (Platform.isAndroid) {
      if (_customStorageDirectory != null) {
        // Se customStorageDirectory è fornito, usalo direttamente 
        // SENZA aggiungere appName (evita doppia nidificazione)
        final directory = Directory(_customStorageDirectory!);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        return directory;
      } else {
        // Solo quando NON c'è customStorageDirectory, usa appName
        final appName = _customAppName ?? 'DocumentScanner';
        final basePath = '/storage/emulated/0/Documents';
        final directory = Directory(path.join(basePath, appName));
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        return directory;
      }
    } else {
      // iOS logic remains the same
      if (_customStorageDirectory != null) {
        final directory = Directory(_customStorageDirectory!);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        return directory;
      } else {
        return await getApplicationDocumentsDirectory();
      }
    }
  }

  /// Generate appropriate filename based on document type and timestamp
  /// Falls back to timestamp-based naming when product details are not available
  String _generateFilename(DocumentType type, DateTime timestamp, [Map<String, dynamic>? metadata]) {
    // Try to use suggested name from metadata first
    if (metadata != null && metadata['suggestedFilename'] != null) {
      return metadata['suggestedFilename'] as String;
    }
    
    // Try to build name from product details if available
    if (metadata != null) {
      final brand = metadata['productBrand'] as String?;
      final model = metadata['productModel'] as String?;
      final purchaseDate = metadata['purchaseDate'] as String?;
      
      if (brand != null && model != null) {
        final dateStr = purchaseDate ?? timestamp.toIso8601String().split('T')[0];
        final typeStr = _getDocumentTypeSuffix(type);
        // Clean brand and model for filename (remove invalid chars)
        final cleanBrand = _cleanFilename(brand);
        final cleanModel = _cleanFilename(model);
        return '${dateStr}_${cleanBrand}_${cleanModel}_${typeStr}';
      }
    }
    
    // Fallback to timestamp-based naming
    final dateTimeStr = _formatTimestampForFilename(timestamp);
    final typeStr = _getDocumentTypeSuffix(type);
    return '${dateTimeStr}_${typeStr}';
  }
  
  /// Get document type suffix for filename
  String _getDocumentTypeSuffix(DocumentType type) {
    switch (type) {
      case DocumentType.receipt:
        return 'Receipt';
      case DocumentType.manual:
        return 'Manual';
      case DocumentType.document:
        return 'Document';
      case DocumentType.other:
        return 'Scan';
    }
  }
  
  /// Format timestamp for filename (yyyymmdd)
  String _formatTimestampForFilename(DateTime timestamp) {
    final year = timestamp.year.toString();
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }
  
  /// Clean filename by removing invalid characters
  String _cleanFilename(String input) {
    // Replace invalid filename characters with underscores
    return input
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
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

  /// Check camera permission
  Future<bool> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isDenied) {
      final result = await Permission.camera.request();
      return result.isGranted;
    }
    return status.isGranted;
  }

  /// Check storage permission
  Future<bool> _checkStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.status;
      if (status.isDenied) {
        final result = await Permission.manageExternalStorage.request();
        return result.isGranted;
      }
      return status.isGranted;
    }
    return true; // iOS doesn't need explicit storage permission
  }

  /// Finalize scan result after image editing (used by widgets)
  /// This method handles PDF generation and external storage saving for edited documents
  Future<ScanResult> finalizeScanResult(
    ScannedDocument document,
    String? customFilename,
  ) async {
    try {
      // Generate PDF if the document doesn't have one and processing options require it
      Uint8List? pdfData = document.pdfData;
      if (pdfData == null && document.processingOptions.generatePdf) {
        // Use processed image data if available, otherwise use raw image data
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

      // Update document with PDF data
      final updatedDocument = document.copyWith(
        pdfData: pdfData,
        metadata: {
          ...document.metadata,
          'finalized': true,
          'finalizedAt': DateTime.now().toIso8601String(),
          'pdfSize': pdfData?.length,
        },
      );

      // Save to external storage
      final savedDocument = await _saveToExternalStorage(
        updatedDocument,
        customFilename,
      );

      return ScanResult.success(document: savedDocument);
    } catch (e) {
      return ScanResult.error(error: 'Failed to finalize scan result: $e');
    }
  }

  /// Internal method to process and save document (shared logic)
  /// AIDEV-NOTE: Refactored shared processing logic to avoid code duplication
  Future<ScanResult> _processAndSaveDocument({
    required Uint8List rawImageData,
    required String originalPath,
    required DocumentType documentType,
    required DocumentProcessingOptions processingOptions,
    required String source,
    String? customFilename,
  }) async {
    try {
      print('🔍 SCANNER DEBUG: _processAndSaveDocument called');
      print('🔍 Raw image data size: ${rawImageData.length}');

      // Process image automatically
      final processedImageData = await _imageProcessor.processImage(
        rawImageData,
        processingOptions,
      );
      print('🔍 SCANNER DEBUG: Image processed, size: ${processedImageData.length}');

      // Generate PDF if requested
      Uint8List? pdfData;
      if (processingOptions.generatePdf) {
        print('🔍 SCANNER DEBUG: Generating PDF...');
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
        print('🔍 SCANNER DEBUG: PDF generated, size: ${pdfData?.length ?? 0}');
      } else {
        print('🔍 SCANNER DEBUG: PDF generation skipped (generatePdf: false)');
      }

      // Create document with processed data
      final document = ScannedDocument(
        id: _generateId(),
        type: documentType,
        originalPath: originalPath,
        scanTime: DateTime.now(),
        processingOptions: processingOptions,
        rawImageData: rawImageData,
        processedImageData: processedImageData,
        pdfData: pdfData,
        metadata: {
          'source': source,
          'originalSize': rawImageData.length,
          'processedSize': processedImageData.length,
          'pdfSize': pdfData?.length,
          'autoProcessed': true,
          'finalized': true,
          'finalizedAt': DateTime.now().toIso8601String(),
        },
      );

      print('🔍 SCANNER DEBUG: Document created with:');
      print('🔍 - processedImageData: ${document.processedImageData != null}');
      print('🔍 - pdfData: ${document.pdfData != null}');
      print('🔍 - processing options generatePdf: ${document.processingOptions.generatePdf}');
      print('🔍 - processing options saveImageFile: ${document.processingOptions.saveImageFile}');

      // Save to external storage
      final savedDocument = await _saveToExternalStorage(
        document,
        customFilename,
      );

      print('✅ SCANNER DEBUG: Final result paths:');
      print('✅ - savedDocument.pdfPath: ${savedDocument.pdfPath}');
      print('✅ - savedDocument.processedPath: ${savedDocument.processedPath}');

      return ScanResult.success(document: savedDocument);
    } catch (e) {
      return ScanResult.error(error: 'Failed to process and save document: $e');
    }
  }

  /// Generate unique ID for document
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}

