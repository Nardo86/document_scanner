import 'dart:typed_data';

/// Represents a single page in a multi-page document.
///
/// Each [DocumentPage] encapsulates a scanned page with its metadata, original image,
/// and optionally processed image data. Pages maintain their order through [pageNumber]
/// and can be individually updated while preserving other page data through [copyWith].
class DocumentPage {
  /// Unique identifier for this page
  final String id;

  /// The page number within the document (1-indexed)
  final int pageNumber;

  /// Path to the original scanned image file
  final String originalPath;

  /// Path to the processed image file (if processed)
  final String? processedPath;

  /// Timestamp when this page was scanned
  final DateTime scanTime;

  /// Raw image data from the scanner (optional, for in-memory handling)
  final Uint8List? rawImageData;

  /// Processed image data (optional, after filtering/rotation/crop)
  final Uint8List? processedImageData;

  /// Arbitrary metadata associated with this page
  final Map<String, dynamic> metadata;

  /// Creates a new [DocumentPage].
  ///
  /// The [id], [pageNumber], [originalPath], and [scanTime] are required.
  /// All other fields are optional and default to null/empty values.
  DocumentPage({
    required this.id,
    required this.pageNumber,
    required this.originalPath,
    required this.scanTime,
    this.processedPath,
    this.rawImageData,
    this.processedImageData,
    this.metadata = const {},
  });

  /// Creates a copy of this page with optionally updated fields.
  ///
  /// Fields not specified in the call retain their original values.
  /// This is useful for updating a page after processing while keeping
  /// the original metadata and paths intact.
  ///
  /// Example:
  /// ```dart
  /// final updatedPage = page.copyWith(
  ///   processedPath: '/path/to/processed.jpg',
  ///   processedImageData: processedBytes,
  /// );
  /// ```
  DocumentPage copyWith({
    String? processedPath,
    Uint8List? processedImageData,
    Map<String, dynamic>? metadata,
  }) {
    return DocumentPage(
      id: id,
      pageNumber: pageNumber,
      originalPath: originalPath,
      scanTime: scanTime,
      processedPath: processedPath ?? this.processedPath,
      rawImageData: rawImageData,
      processedImageData: processedImageData ?? this.processedImageData,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Converts this page to a JSON representation.
  ///
  /// The resulting map excludes binary image data (rawImageData and processedImageData)
  /// but includes all paths, timestamps, and metadata. This is suitable for:
  /// - Serializing to disk/database
  /// - Sending over network
  /// - Storing in configuration files
  ///
  /// Use [fromJson] to deserialize.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pageNumber': pageNumber,
      'originalPath': originalPath,
      'processedPath': processedPath,
      'scanTime': scanTime.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Creates a [DocumentPage] from a JSON representation.
  ///
  /// Expects a map with at least the required fields: id, pageNumber, originalPath, scanTime.
  /// Optional fields like processedPath and metadata are filled with sensible defaults if missing.
  ///
  /// Example:
  /// ```dart
  /// final page = DocumentPage.fromJson({
  ///   'id': 'page-123',
  ///   'pageNumber': 1,
  ///   'originalPath': '/path/to/image.jpg',
  ///   'scanTime': '2024-01-15T10:30:00.000Z',
  ///   'metadata': {'quality': 'high'},
  /// });
  /// ```
  factory DocumentPage.fromJson(Map<String, dynamic> json) {
    return DocumentPage(
      id: json['id'] as String,
      pageNumber: json['pageNumber'] as int,
      originalPath: json['originalPath'] as String,
      processedPath: json['processedPath'] as String?,
      scanTime: DateTime.parse(json['scanTime'] as String),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }
}
