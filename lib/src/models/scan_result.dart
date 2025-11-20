import 'scanned_document.dart';

/// Types of QR code content
enum QRContentType {
  /// URL link
  url,

  /// Direct PDF link
  pdfLink,

  /// Manual/guide link
  manualLink,

  /// Plain text content
  text,

  /// Unknown or unclassified content
  unknown,
}

/// Types of scan results
enum ScanResultType {
  /// Direct camera scan
  scan,

  /// Imported from gallery or file system
  import,

  /// Downloaded from URL or QR code
  download,

  /// QR code scan result
  qrScan,
}

/// Result of a document scanning operation.
///
/// [ScanResult] encapsulates the outcome of any document scanning operation, including:
/// - Whether the operation succeeded
/// - The resulting [ScannedDocument] (if successful)
/// - Error messages (if failed)
/// - The type of operation that was performed
/// - Additional metadata
///
/// Use factory constructors [ScanResult.success], [ScanResult.error], or [ScanResult.cancelled]
/// for creating results more conveniently.
///
/// Example:
/// ```dart
/// // Success case
/// final result = ScanResult.success(document: myDocument);
///
/// // Error case
/// final error = ScanResult.error(error: 'Camera not available');
///
/// // Cancelled
/// final cancelled = ScanResult.cancelled();
/// ```
class ScanResult {
  /// Whether the operation succeeded
  final bool success;

  /// The resulting scanned document (present if success is true)
  final ScannedDocument? document;

  /// Error message (present if success is false)
  final String? error;

  /// The type of scan operation that was performed
  final ScanResultType type;

  /// Additional metadata about the operation
  final Map<String, dynamic> metadata;

  /// Creates a new [ScanResult].
  ///
  /// Use the factory constructors instead for simpler creation.
  const ScanResult({
    required this.success,
    this.document,
    this.error,
    required this.type,
    this.metadata = const {},
  });

  /// Creates a success result with a document.
  ///
  /// Example:
  /// ```dart
  /// return ScanResult.success(
  ///   document: scannedDocument,
  ///   type: ScanResultType.scan,
  /// );
  /// ```
  factory ScanResult.success({
    required ScannedDocument document,
    ScanResultType type = ScanResultType.scan,
    Map<String, dynamic> metadata = const {},
  }) {
    return ScanResult(
      success: true,
      document: document,
      type: type,
      metadata: metadata,
    );
  }

  /// Creates an error result.
  ///
  /// Example:
  /// ```dart
  /// return ScanResult.error(
  ///   error: 'Failed to process image',
  ///   type: ScanResultType.scan,
  /// );
  /// ```
  factory ScanResult.error({
    required String error,
    ScanResultType type = ScanResultType.scan,
    Map<String, dynamic> metadata = const {},
  }) {
    return ScanResult(
      success: false,
      error: error,
      type: type,
      metadata: metadata,
    );
  }

  /// Creates a cancelled result (user-initiated cancellation).
  ///
  /// Example:
  /// ```dart
  /// return ScanResult.cancelled();
  /// ```
  factory ScanResult.cancelled({
    ScanResultType type = ScanResultType.scan,
  }) {
    return ScanResult(
      success: false,
      error: 'User cancelled operation',
      type: type,
    );
  }

  /// Converts this result to a JSON representation.
  ///
  /// Excludes binary data from the result's document (if present).
  ///
  /// Example:
  /// ```dart
  /// final json = result.toJson();
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'document': document?.toJson(),
      'error': error,
      'type': type.toString(),
      'metadata': metadata,
    };
  }

  /// Creates a [ScanResult] from a JSON representation.
  ///
  /// Example:
  /// ```dart
  /// final result = ScanResult.fromJson(jsonMap);
  /// ```
  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'];
    return ScanResult(
      success: json['success'] as bool,
      document: json['document'] != null
          ? ScannedDocument.fromJson(
              Map<String, dynamic>.from(json['document'] as Map<dynamic, dynamic>))
          : null,
      error: json['error'] as String?,
      type: ScanResultType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => ScanResultType.scan,
      ),
      metadata: metadata is Map
          ? Map<String, dynamic>.from(metadata)
          : {},
    );
  }
}

/// QR Code scan result specifically for manual downloads and QR-based document retrieval.
///
/// [QRScanResult] extends [ScanResult] to include QR-specific data:
/// - The raw QR data (URL, text, etc.)
/// - The type of content encoded in the QR
///
/// Typically used in manual/guide lookup workflows where users can:
/// 1. Scan a QR code containing a URL
/// 2. Download the PDF from that URL
/// 3. Store or view the document
///
/// Example:
/// ```dart
/// final qrResult = QRScanResult.success(
///   qrData: 'https://example.com/manual.pdf',
///   contentType: QRContentType.pdfLink,
///   document: downloadedDocument,
/// );
/// ```
class QRScanResult extends ScanResult {
  /// The raw data encoded in the QR code
  final String qrData;

  /// The type of content (URL, PDF link, manual link, etc.)
  final QRContentType contentType;

  /// Creates a new [QRScanResult].
  ///
  /// Use factory constructors for simpler creation.
  const QRScanResult({
    required bool success,
    required this.qrData,
    required this.contentType,
    ScannedDocument? document,
    String? error,
    Map<String, dynamic> metadata = const {},
  }) : super(
         success: success,
         document: document,
         error: error,
         type: ScanResultType.qrScan,
         metadata: metadata,
       );

  /// Creates a successful QR scan result.
  ///
  /// Example:
  /// ```dart
  /// return QRScanResult.success(
  ///   qrData: 'https://example.com/manual.pdf',
  ///   contentType: QRContentType.pdfLink,
  /// );
  /// ```
  factory QRScanResult.success({
    required String qrData,
    required QRContentType contentType,
    ScannedDocument? document,
    Map<String, dynamic> metadata = const {},
  }) {
    return QRScanResult(
      success: true,
      qrData: qrData,
      contentType: contentType,
      document: document,
      metadata: metadata,
    );
  }

  /// Creates a failed QR scan result.
  ///
  /// Example:
  /// ```dart
  /// return QRScanResult.error(
  ///   error: 'Failed to parse QR code',
  ///   qrData: rawData,
  /// );
  /// ```
  factory QRScanResult.error({
    required String error,
    required String qrData,
    QRContentType contentType = QRContentType.unknown,
  }) {
    return QRScanResult(
      success: false,
      qrData: qrData,
      contentType: contentType,
      error: error,
    );
  }

  /// Converts this QR result to a JSON representation.
  ///
  /// Includes all parent [ScanResult] fields plus QR-specific data.
  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['qrData'] = qrData;
    json['contentType'] = contentType.toString();
    return json;
  }

  /// Creates a [QRScanResult] from a JSON representation.
  ///
  /// Example:
  /// ```dart
  /// final result = QRScanResult.fromJson(jsonMap);
  /// ```
  factory QRScanResult.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'];
    return QRScanResult(
      success: json['success'] as bool,
      qrData: json['qrData'] as String,
      contentType: QRContentType.values.firstWhere(
        (e) => e.toString() == json['contentType'],
        orElse: () => QRContentType.unknown,
      ),
      document: json['document'] != null
          ? ScannedDocument.fromJson(
              Map<String, dynamic>.from(json['document'] as Map<dynamic, dynamic>))
          : null,
      error: json['error'] as String?,
      metadata: metadata is Map
          ? Map<String, dynamic>.from(metadata)
          : {},
    );
  }
}
