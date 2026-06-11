import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart' as pp;
import 'package:path/path.dart' as path;
import '../models/scanned_document.dart';

/// Configuration for storage operations.
class StorageConfig {
  /// Explicit directory to write into. When set it takes precedence over the
  /// platform default. The caller is responsible for any runtime permissions
  /// this location requires (e.g. shared external storage on Android).
  final String? customDirectory;

  /// Folder name used under the platform default location.
  final String? appName;

  const StorageConfig({this.customDirectory, this.appName});
}

/// Lightweight helper for directory creation, filename generation, and file I/O.
///
/// By default this writes to **scoped, app-specific** storage that requires no
/// runtime permission. Provide [StorageConfig.customDirectory] to target a
/// different location (the caller then owns any required permissions).
class StorageHelper {
  StorageConfig _config = const StorageConfig();

  /// Apply storage configuration.
  void configure(StorageConfig config) {
    _config = config;
  }

  /// Return the storage directory, creating it if needed.
  ///
  /// Resolution order:
  /// 1. [StorageConfig.customDirectory] (explicit path)
  /// 2. Android: app-specific external dir `<external-files>/<appName>`
  ///    (scoped storage — no permission required)
  /// 3. iOS / other: `<app-documents>/<appName>`
  Future<Directory> getExternalStorageDirectory() async {
    final custom = _config.customDirectory;
    if (custom != null && custom.isNotEmpty) {
      return _ensureDirectory(custom);
    }

    final appName = _config.appName ?? 'DocumentScanner';

    if (Platform.isAndroid) {
      // App-specific external storage: /Android/data/<pkg>/files. Scoped, so no
      // MANAGE_EXTERNAL_STORAGE / WRITE_EXTERNAL_STORAGE permission is needed.
      final extDir = await pp.getExternalStorageDirectory();
      final base = extDir ?? await pp.getApplicationDocumentsDirectory();
      return _ensureDirectory(path.join(base.path, appName));
    }

    // iOS / desktop / others: app documents directory.
    final appDir = await pp.getApplicationDocumentsDirectory();
    return _ensureDirectory(path.join(appDir.path, appName));
  }

  /// Generate a safe, sanitized base filename (without extension).
  ///
  /// All caller- or metadata-supplied names are reduced to a bare basename and
  /// stripped of path separators / unsafe characters, so they can never escape
  /// the target directory.
  String generateFilename({
    required DocumentType documentType,
    required DateTime timestamp,
    String? customFilename,
    Map<String, dynamic>? metadata,
  }) {
    if (customFilename != null && customFilename.trim().isNotEmpty) {
      return _sanitizeFilename(
        customFilename,
        fallback: _defaultName(documentType, timestamp),
      );
    }

    if (metadata != null) {
      final suggested = metadata['suggestedFilename'] as String?;
      if (suggested != null && suggested.trim().isNotEmpty) {
        return _sanitizeFilename(
          suggested,
          fallback: _defaultName(documentType, timestamp),
        );
      }

      final brand = metadata['productBrand'] as String?;
      final model = metadata['productModel'] as String?;
      if (brand != null && model != null) {
        final dateStr =
            (metadata['purchaseDate'] as String?) ??
            _formatTimestamp(timestamp);
        final typeStr = _typeSuffix(documentType);
        return _sanitizeFilename(
          '${dateStr}_${_clean(brand)}_${_clean(model)}_$typeStr',
          fallback: _defaultName(documentType, timestamp),
        );
      }
    }

    return _defaultName(documentType, timestamp);
  }

  /// Save an image file and return its absolute path.
  Future<String> saveImageFile({
    required Directory directory,
    required String filename,
    required Uint8List imageData,
  }) {
    return _writeBytes(directory, filename, 'jpg', imageData);
  }

  /// Save a PDF file and return its absolute path.
  Future<String> savePdfFile({
    required Directory directory,
    required String filename,
    required Uint8List pdfData,
  }) {
    return _writeBytes(directory, filename, 'pdf', pdfData);
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

  Future<String> _writeBytes(
    Directory directory,
    String filename,
    String extension,
    Uint8List bytes,
  ) async {
    // Re-sanitize defensively: callers may pass a name that did not go through
    // generateFilename().
    final safe = _sanitizeFilename(filename, fallback: 'document');
    final target = path.normalize(
      path.join(directory.path, '$safe.$extension'),
    );

    // Hard guarantee the write stays inside the target directory.
    if (!path.isWithin(directory.path, target)) {
      throw ArgumentError(
        'Refusing to write outside the storage directory: $target',
      );
    }

    final file = File(target);
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<Directory> _ensureDirectory(String dirPath) async {
    final directory = Directory(dirPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// Reduce an arbitrary string to a safe, separator-free basename.
  String _sanitizeFilename(String raw, {required String fallback}) {
    // basename() drops any directory components, including `../` and absolute
    // path prefixes (the core path-traversal defense).
    var name = path.basename(raw.trim());
    name = _clean(name);
    // Strip a trailing/leading dot run so we never produce "." / ".." / hidden.
    name = name.replaceAll(RegExp(r'^\.+'), '').replaceAll(RegExp(r'\.+$'), '');
    if (name.isEmpty) return fallback;
    // Cap length to stay well under filesystem limits.
    return name.length > 120 ? name.substring(0, 120) : name;
  }

  String _defaultName(DocumentType type, DateTime timestamp) {
    // Date + time so same-day scans of the same type don't overwrite.
    return '${_formatTimestamp(timestamp)}_${_formatTime(timestamp)}_${_typeSuffix(type)}';
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

  String _formatTime(DateTime ts) {
    final hh = ts.hour.toString().padLeft(2, '0');
    final mm = ts.minute.toString().padLeft(2, '0');
    final ss = ts.second.toString().padLeft(2, '0');
    return '$hh$mm$ss';
  }

  String _clean(String input) {
    return input
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
  }
}
