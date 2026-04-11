import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart' as pp;
import 'package:path/path.dart' as path;
import '../models/scanned_document.dart';

/// Configuration for storage operations.
class StorageConfig {
  final String? customDirectory;
  final String? appName;

  const StorageConfig({this.customDirectory, this.appName});
}

/// Lightweight helper for directory creation, filename generation, and file I/O.
class StorageHelper {
  StorageConfig _config = const StorageConfig();

  /// Apply storage configuration.
  void configure(StorageConfig config) {
    _config = config;
  }

  /// Return the configured external storage directory, creating it if needed.
  ///
  /// Resolution order:
  /// 1. [StorageConfig.customDirectory] (explicit path)
  /// 2. Android: `<external-storage>/Documents/<appName>`
  /// 3. iOS / other: application documents directory
  Future<Directory> getExternalStorageDirectory() async {
    if (_config.customDirectory != null) {
      return _ensureDirectory(_config.customDirectory!);
    }

    if (Platform.isAndroid) {
      // Prefer the platform-provided external storage directory. Fall back to
      // the well-known /storage/emulated/0/Documents path only when the
      // platform helper returns null (which should not happen on modern
      // Android, but guards against edge cases).
      final extDir = await pp.getExternalStorageDirectory();
      final appName = _config.appName ?? 'DocumentScanner';

      if (extDir != null) {
        // path_provider returns app-specific external storage
        // (e.g. /storage/emulated/0/Android/data/<pkg>/files).
        // We go up to the shared Documents folder instead.
        final docsPath = path.join(
          extDir.parent.parent.parent.parent.path,
          'Documents',
          appName,
        );
        return _ensureDirectory(docsPath);
      }

      // Fallback
      return _ensureDirectory('/storage/emulated/0/Documents/$appName');
    }

    // iOS / desktop / others
    final appDir = await pp.getApplicationDocumentsDirectory();
    return appDir;
  }

  /// Generate a filename based on type, metadata, and timestamp.
  String generateFilename({
    required DocumentType documentType,
    required DateTime timestamp,
    String? customFilename,
    Map<String, dynamic>? metadata,
  }) {
    if (customFilename != null) return customFilename;

    if (metadata != null) {
      final suggested = metadata['suggestedFilename'] as String?;
      if (suggested != null) return suggested;

      final brand = metadata['productBrand'] as String?;
      final model = metadata['productModel'] as String?;
      if (brand != null && model != null) {
        final dateStr =
            (metadata['purchaseDate'] as String?) ??
            _formatTimestamp(timestamp);
        final typeStr = _typeSuffix(documentType);
        return '${dateStr}_${_clean(brand)}_${_clean(model)}_$typeStr';
      }
    }

    return '${_formatTimestamp(timestamp)}_${_typeSuffix(documentType)}';
  }

  /// Save an image file and return its absolute path.
  Future<String> saveImageFile({
    required Directory directory,
    required String filename,
    required Uint8List imageData,
  }) async {
    final file = File(path.join(directory.path, '$filename.jpg'));
    await file.writeAsBytes(imageData);
    return file.path;
  }

  /// Save a PDF file and return its absolute path.
  Future<String> savePdfFile({
    required Directory directory,
    required String filename,
    required Uint8List pdfData,
  }) async {
    final file = File(path.join(directory.path, '$filename.pdf'));
    await file.writeAsBytes(pdfData);
    return file.path;
  }

  /// Save both image and PDF files. Returns a map with `'image'` and `'pdf'` keys.
  Future<Map<String, String>> saveFiles({
    required Directory directory,
    required String filename,
    Uint8List? imageData,
    Uint8List? pdfData,
  }) async {
    final paths = <String, String>{};
    if (imageData != null) {
      paths['image'] = await saveImageFile(
        directory: directory,
        filename: filename,
        imageData: imageData,
      );
    }
    if (pdfData != null) {
      paths['pdf'] = await savePdfFile(
        directory: directory,
        filename: filename,
        pdfData: pdfData,
      );
    }
    return paths;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<Directory> _ensureDirectory(String dirPath) async {
    final directory = Directory(dirPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _typeSuffix(DocumentType type) {
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

  String _formatTimestamp(DateTime ts) {
    final y = ts.year.toString();
    final m = ts.month.toString().padLeft(2, '0');
    final d = ts.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  String _clean(String input) {
    return input
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
  }
}
