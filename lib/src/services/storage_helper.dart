import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/scanned_document.dart';

/// Configuration for storage operations
class StorageConfig {
  final String? customDirectory;
  final String? appName;

  const StorageConfig({
    this.customDirectory,
    this.appName,
  });
}

/// Lightweight helper for storage operations
/// Handles directory creation, file naming, and file saving
class StorageHelper {
  StorageConfig _config = const StorageConfig();

  /// Configure storage settings
  void configure(StorageConfig config) {
    _config = config;
  }

  /// Get the configured external storage directory
  Future<Directory> getExternalStorageDirectory() async {
    if (Platform.isAndroid) {
      if (_config.customDirectory != null) {
        final directory = Directory(_config.customDirectory!);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        return directory;
      } else {
        final appName = _config.appName ?? 'DocumentScanner';
        final basePath = '/storage/emulated/0/Documents';
        final directory = Directory(path.join(basePath, appName));
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        return directory;
      }
    } else {
      if (_config.customDirectory != null) {
        final directory = Directory(_config.customDirectory!);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        return directory;
      } else {
        return await getApplicationDocumentsDirectory();
      }
    }
  }

  /// Generate filename based on document type, custom name, and metadata
  String generateFilename({
    required DocumentType documentType,
    required DateTime timestamp,
    String? customFilename,
    Map<String, dynamic>? metadata,
  }) {
    if (customFilename != null) {
      return customFilename;
    }

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
        final dateStr = purchaseDate ?? _formatTimestampForFilename(timestamp);
        final typeStr = _getDocumentTypeSuffix(documentType);
        final cleanBrand = _cleanFilename(brand);
        final cleanModel = _cleanFilename(model);
        return '${dateStr}_${cleanBrand}_${cleanModel}_${typeStr}';
      }
    }

    // Fallback to timestamp-based naming
    final dateTimeStr = _formatTimestampForFilename(timestamp);
    final typeStr = _getDocumentTypeSuffix(documentType);
    return '${dateTimeStr}_${typeStr}';
  }

  /// Save image file to storage
  Future<String> saveImageFile({
    required Directory directory,
    required String filename,
    required Uint8List imageData,
  }) async {
    final imageFile = File(path.join(directory.path, '$filename.jpg'));
    await imageFile.writeAsBytes(imageData);
    return imageFile.path;
  }

  /// Save PDF file to storage
  Future<String> savePdfFile({
    required Directory directory,
    required String filename,
    required Uint8List pdfData,
  }) async {
    final pdfFile = File(path.join(directory.path, '$filename.pdf'));
    await pdfFile.writeAsBytes(pdfData);
    return pdfFile.path;
  }

  /// Save both image and PDF files
  Future<Map<String, String>> saveFiles({
    required Directory directory,
    required String filename,
    Uint8List? imageData,
    Uint8List? pdfData,
  }) async {
    final paths = <String, String>{};

    if (imageData != null) {
      final imagePath = await saveImageFile(
        directory: directory,
        filename: filename,
        imageData: imageData,
      );
      paths['image'] = imagePath;
    }

    if (pdfData != null) {
      final pdfPath = await savePdfFile(
        directory: directory,
        filename: filename,
        pdfData: pdfData,
      );
      paths['pdf'] = pdfPath;
    }

    return paths;
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
    return input
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
  }
}
