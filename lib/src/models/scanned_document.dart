import 'dart:typed_data';

import 'document_page.dart';
import 'processing_options.dart';

/// Document type classification for scanning operations
enum DocumentType {
  /// Receipt/invoice document
  receipt,

  /// Manual or guide document
  manual,

  /// General document (contracts, letters, etc.)
  document,

  /// Other document types
  other,
}

/// Color filter options for image display and editing
enum ColorFilter {
  /// No filtering applied
  none,

  /// High contrast filter for enhanced readability
  highContrast,

  /// Black and white filter
  blackAndWhite,
}

/// Image editing options for preview and adjustment
class ImageEditingOptions {
  /// Rotation angle in degrees (0, 90, 180, 270)
  final int rotationDegrees;

  /// Color filter to apply
  final ColorFilter colorFilter;

  /// Four corner points defining the crop area (optional).
  /// Each element represents a 2D point with dx (x-coordinate) and dy (y-coordinate) properties.
  final List<dynamic>? cropCorners;

  /// Document format determining aspect ratio for auto-cropping
  final DocumentFormat documentFormat;

  /// Creates new [ImageEditingOptions] for image preview and editing.
  ///
  /// All parameters are optional and have sensible defaults.
  ///
  /// Example:
  /// ```dart
  /// const options = ImageEditingOptions(
  ///   rotationDegrees: 90,
  ///   colorFilter: ColorFilter.highContrast,
  ///   documentFormat: DocumentFormat.isoA,
  /// );
  /// ```
  const ImageEditingOptions({
    this.rotationDegrees = 0,
    this.colorFilter = ColorFilter.none,
    this.cropCorners,
    this.documentFormat = DocumentFormat.auto,
  });

  /// Creates a copy with optionally updated fields.
  ///
  /// Example:
  /// ```dart
  /// final rotated = options.copyWith(rotationDegrees: 90);
  /// ```
  ImageEditingOptions copyWith({
    int? rotationDegrees,
    ColorFilter? colorFilter,
    List<dynamic>? cropCorners,
    DocumentFormat? documentFormat,
  }) {
    return ImageEditingOptions(
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      colorFilter: colorFilter ?? this.colorFilter,
      cropCorners: cropCorners ?? this.cropCorners,
      documentFormat: documentFormat ?? this.documentFormat,
    );
  }
}

/// Represents a complete scanned document with metadata and processing configuration.
///
/// A [ScannedDocument] encapsulates:
/// - A unique identifier and document type
/// - File paths for original and processed image data (plus optional binary data)
/// - Multi-page support with individual [DocumentPage] objects
/// - Processing options that were/will be applied
/// - Arbitrary metadata for application-specific tracking
///
/// Documents can be:
/// - Single-page (simple captures from camera/gallery)
/// - Multi-page (assembled from a [MultiPageScanSession])
///
/// The class provides:
/// - Copy-with functionality for immutable updates
/// - JSON serialization for persistence
/// - Metadata propagation hooks for tracking document properties
///
/// Example:
/// ```dart
/// final document = ScannedDocument(
///   id: 'doc-001',
///   type: DocumentType.document,
///   originalPath: '/path/to/original.jpg',
///   scanTime: DateTime.now(),
///   processingOptions: DocumentProcessingOptions.document,
/// );
/// ```
class ScannedDocument {
  /// Unique identifier for this document
  final String id;

  /// The document type (receipt, manual, document, other)
  final DocumentType type;

  /// Path to the original captured image
  final String originalPath;

  /// Path to the processed image (after filtering/cropping)
  final String? processedPath;

  /// Path to the generated PDF file (if generatePdf was true)
  final String? pdfPath;

  /// Timestamp when the document was scanned
  final DateTime scanTime;

  /// Processing options that were/will be applied to this document
  final DocumentProcessingOptions processingOptions;

  /// Arbitrary application-specific metadata (e.g., OCR results, user tags)
  final Map<String, dynamic> metadata;

  /// Raw image data from the scanner (optional, for in-memory handling)
  final Uint8List? rawImageData;

  /// Processed image data after filtering/rotation/crop (optional)
  final Uint8List? processedImageData;

  /// Generated PDF binary data (optional)
  final Uint8List? pdfData;

  /// Individual pages for multi-page documents
  final List<DocumentPage> pages;

  /// Whether this is a multi-page document
  final bool isMultiPage;

  /// Creates a new [ScannedDocument].
  ///
  /// The [id], [type], [originalPath], [scanTime], and [processingOptions] are required.
  /// All other fields are optional.
  ///
  /// Example:
  /// ```dart
  /// final doc = ScannedDocument(
  ///   id: 'doc-123',
  ///   type: DocumentType.receipt,
  ///   originalPath: '/path/to/receipt.jpg',
  ///   scanTime: DateTime.now(),
  ///   processingOptions: DocumentProcessingOptions.receipt,
  /// );
  /// ```
  ScannedDocument({
    required this.id,
    required this.type,
    required this.originalPath,
    required this.scanTime,
    required this.processingOptions,
    this.processedPath,
    this.pdfPath,
    this.metadata = const {},
    this.rawImageData,
    this.processedImageData,
    this.pdfData,
    this.pages = const [],
    this.isMultiPage = false,
  });

  /// Creates a copy of this document with optionally updated fields.
  ///
  /// Immutable operation - returns a new instance without modifying the original.
  /// Only specified fields are overridden; others retain their values.
  ///
  /// Example:
  /// ```dart
  /// final processed = document.copyWith(
  ///   processedPath: '/path/to/processed.jpg',
  ///   pdfPath: '/path/to/document.pdf',
  /// );
  /// ```
  ScannedDocument copyWith({
    String? processedPath,
    String? pdfPath,
    Uint8List? rawImageData,
    Uint8List? processedImageData,
    Uint8List? pdfData,
    Map<String, dynamic>? metadata,
    List<DocumentPage>? pages,
    bool? isMultiPage,
  }) {
    return ScannedDocument(
      id: id,
      type: type,
      originalPath: originalPath,
      scanTime: scanTime,
      processingOptions: processingOptions,
      processedPath: processedPath ?? this.processedPath,
      pdfPath: pdfPath ?? this.pdfPath,
      rawImageData: rawImageData ?? this.rawImageData,
      processedImageData: processedImageData ?? this.processedImageData,
      pdfData: pdfData ?? this.pdfData,
      metadata: metadata ?? this.metadata,
      pages: pages ?? this.pages,
      isMultiPage: isMultiPage ?? this.isMultiPage,
    );
  }

  /// Converts this document to a JSON representation.
  ///
  /// Binary data (rawImageData, processedImageData, pdfData) is excluded from JSON
  /// serialization. Use [fromJson] to deserialize.
  ///
  /// Useful for:
  /// - Persisting document metadata to disk/database
  /// - Sending document info over network
  /// - Logging for debugging
  ///
  /// Example:
  /// ```dart
  /// final json = document.toJson();
  /// final jsonString = jsonEncode(json);
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'originalPath': originalPath,
      'processedPath': processedPath,
      'pdfPath': pdfPath,
      'scanTime': scanTime.toIso8601String(),
      'processingOptions': processingOptions.toJson(),
      'metadata': metadata,
      'isMultiPage': isMultiPage,
      'pageCount': pages.length,
      'pages': pages.map((p) => p.toJson()).toList(),
    };
  }

  /// Converts this document to a Map (compatibility alias for [toJson]).
  ///
  /// Provided for backward compatibility with code expecting [toMap].
  Map<String, dynamic> toMap() {
    return toJson();
  }

  /// Creates a [ScannedDocument] from a JSON representation.
  ///
  /// Required fields: id, type, originalPath, scanTime, processingOptions.
  /// Optional fields use sensible defaults if missing.
  ///
  /// Example:
  /// ```dart
  /// final doc = ScannedDocument.fromJson({
  ///   'id': 'doc-123',
  ///   'type': 'DocumentType.receipt',
  ///   'originalPath': '/path/to/image.jpg',
  ///   'scanTime': '2024-01-15T10:30:00.000Z',
  ///   'processingOptions': {...},
  /// });
  /// ```
  factory ScannedDocument.fromJson(Map<String, dynamic> json) {
    final pages = (json['pages'] as List<dynamic>?)
            ?.map((p) => DocumentPage.fromJson(
                Map<String, dynamic>.from(p as Map<dynamic, dynamic>)))
            .toList() ??
        [];

    return ScannedDocument(
      id: json['id'] as String,
      type: DocumentType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => DocumentType.other,
      ),
      originalPath: json['originalPath'] as String,
      processedPath: json['processedPath'] as String?,
      pdfPath: json['pdfPath'] as String?,
      scanTime: DateTime.parse(json['scanTime'] as String),
      processingOptions: DocumentProcessingOptions.fromJson(
          Map<String, dynamic>.from(json['processingOptions'] as Map<dynamic, dynamic>)),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      pages: pages,
      isMultiPage: json['isMultiPage'] as bool? ?? (pages.length > 1),
    );
  }

  /// Returns a count of pages in this document.
  ///
  /// For multi-page documents, this equals [pages.length].
  /// For single-page documents, returns 1 even if [pages] is empty.
  ///
  /// Example:
  /// ```dart
  /// print('Document has ${document.pageCount} pages');
  /// ```
  int get pageCount => isMultiPage ? pages.length : 1;

  /// Returns whether this document has any processed data.
  ///
  /// True if either [processedPath] or [processedImageData] is present.
  ///
  /// Example:
  /// ```dart
  /// if (document.isProcessed) {
  ///   // Use processed version
  /// }
  /// ```
  bool get isProcessed => processedPath != null || processedImageData != null;

  /// Returns whether this document has generated PDF output.
  ///
  /// True if either [pdfPath] or [pdfData] is present.
  ///
  /// Example:
  /// ```dart
  /// if (document.hasPdfOutput) {
  ///   // Save or share the PDF
  /// }
  /// ```
  bool get hasPdfOutput => pdfPath != null || pdfData != null;

  /// Creates a [ScannedDocument] from a [MultiPageScanSession].
  ///
  /// Converts the session state into a complete document with:
  /// - All pages from the session
  /// - A flag indicating whether it's multi-page (pages.length > 1)
  /// - Metadata including page count and session info
  ///
  /// This is typically called when the user finishes scanning and is ready
  /// to process, save, or finalize the multi-page document.
  ///
  /// Example:
  /// ```dart
  /// import 'multi_page_scan_session.dart';
  ///
  /// final session = MultiPageScanSession(...);
  /// // ... add pages ...
  /// final document = ScannedDocument.fromSession(session);
  /// ```
  static ScannedDocument fromSession(dynamic sessionDynamic) {
    // We use dynamic here to avoid circular imports
    // The caller should pass a MultiPageScanSession
    final session = sessionDynamic;
    
    return ScannedDocument(
      id: session.sessionId as String,
      type: session.documentType as DocumentType,
      originalPath: (session.pages as List).isNotEmpty 
          ? (session.pages.first as DocumentPage).originalPath 
          : '',
      scanTime: session.startTime as DateTime,
      processingOptions: session.processingOptions as DocumentProcessingOptions,
      pages: session.pages as List<DocumentPage>,
      isMultiPage: (session.pages as List).length > 1,
      metadata: {
        'pageCount': (session.pages as List).length,
        'sessionStartTime': (session.startTime as DateTime).toIso8601String(),
        'customFilename': session.customFilename,
      },
    );
  }
}
