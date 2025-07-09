import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/scanned_document.dart';
import '../models/scan_result.dart';
import 'image_processor.dart';
import 'pdf_generator.dart';
import 'qr_scanner_service.dart';

/// Main service for document scanning operations
class DocumentScannerService {
  static final DocumentScannerService _instance = DocumentScannerService._internal();
  factory DocumentScannerService() => _instance;
  DocumentScannerService._internal();

  final ImagePicker _imagePicker = ImagePicker();
  final ImageProcessor _imageProcessor = ImageProcessor();
  final PdfGenerator _pdfGenerator = PdfGenerator();
  final QRScannerService _qrScanner = QRScannerService();

  /// Scan a document using camera
  Future<ScanResult> scanDocument({
    required DocumentType documentType,
    DocumentProcessingOptions? processingOptions,
    String? customFilename,
  }) async {
    try {
      // Check permissions
      final hasPermission = await _checkCameraPermission();
      if (!hasPermission) {
        return ScanResult.error(error: 'Camera permission denied');
      }

      // Get processing options based on document type
      final options = processingOptions ?? _getDefaultOptions(documentType);

      // Capture image
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95, // High quality for processing
      );

      if (image == null) {
        return ScanResult.cancelled();
      }

      // Create scanned document
      final document = ScannedDocument(
        id: _generateId(),
        type: documentType,
        originalPath: image.path,
        scanTime: DateTime.now(),
        processingOptions: options,
        rawImageData: await image.readAsBytes(),
        metadata: {
          'source': 'camera',
          'originalSize': await image.length(),
        },
      );

      // Process the document
      return await _processDocument(document, customFilename);
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

      return await _processDocument(document, customFilename);
    } catch (e) {
      return ScanResult.error(error: 'Failed to import document: $e');
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

  /// Download manual from URL (from QR code)
  Future<ScanResult> downloadManualFromUrl({
    required String url,
    String? customFilename,
  }) async {
    try {
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

  /// Process a scanned document (crop, filter, generate PDF)
  Future<ScanResult> _processDocument(
    ScannedDocument document,
    String? customFilename,
  ) async {
    try {
      // Process image
      final processedImageData = await _imageProcessor.processImage(
        document.rawImageData!,
        document.processingOptions,
      );

      // Generate PDF if requested
      Uint8List? pdfData;
      if (document.processingOptions.generatePdf) {
        pdfData = await _pdfGenerator.generatePdf(
          imageData: processedImageData,
          documentType: document.type,
          metadata: document.metadata,
        );
      }

      // Create processed document
      final processedDocument = document.copyWith(
        processedImageData: processedImageData,
        pdfData: pdfData,
        metadata: {
          ...document.metadata,
          'processedSize': processedImageData.length,
          'pdfSize': pdfData?.length,
          'processingTime': DateTime.now().toIso8601String(),
        },
      );

      // Save to external storage
      final savedDocument = await _saveToExternalStorage(
        processedDocument,
        customFilename,
      );

      return ScanResult.success(document: savedDocument);
    } catch (e) {
      return ScanResult.error(error: 'Failed to process document: $e');
    }
  }

  /// Save document to external storage with appropriate naming
  Future<ScannedDocument> _saveToExternalStorage(
    ScannedDocument document,
    String? customFilename,
  ) async {
    final directory = await _getExternalStorageDirectory();
    final timestamp = DateTime.now();
    
    // Generate filename based on document type and custom name
    final filename = customFilename ?? _generateFilename(document.type, timestamp);
    
    // Save processed image
    String? processedPath;
    if (document.processedImageData != null) {
      final imageFile = File(path.join(directory.path, '${filename}.jpg'));
      await imageFile.writeAsBytes(document.processedImageData!);
      processedPath = imageFile.path;
    }

    // Save PDF
    String? pdfPath;
    if (document.pdfData != null) {
      final pdfFile = File(path.join(directory.path, '${filename}.pdf'));
      await pdfFile.writeAsBytes(document.pdfData!);
      pdfPath = pdfFile.path;
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

  /// Get external storage directory for documents
  Future<Directory> _getExternalStorageDirectory() async {
    if (Platform.isAndroid) {
      // Use external storage Documents directory
      final directory = Directory('/storage/emulated/0/Documents/RobaMia');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } else {
      // Fallback to app documents directory
      return await getApplicationDocumentsDirectory();
    }
  }

  /// Generate appropriate filename based on document type
  String _generateFilename(DocumentType type, DateTime timestamp) {
    final dateStr = timestamp.toIso8601String().split('T')[0];
    switch (type) {
      case DocumentType.receipt:
        return '${dateStr}_Receipt';
      case DocumentType.manual:
        return '${dateStr}_Manual';
      case DocumentType.document:
        return '${dateStr}_Document';
      case DocumentType.other:
        return '${dateStr}_Scan';
    }
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

  /// Generate unique ID for document
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}

// AIDEV-NOTE: This service provides a high-level interface for all document
// scanning operations while delegating specific tasks to specialized services