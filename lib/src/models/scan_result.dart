import 'scanned_document.dart';

/// Result of a document scanning operation
class ScanResult {
  final bool success;
  final ScannedDocument? document;
  final String? error;
  final ScanResultType type;
  final Map<String, dynamic> metadata;

  const ScanResult({
    required this.success,
    this.document,
    this.error,
    required this.type,
    this.metadata = const {},
  });

  /// Success result with document
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

  /// Error result
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

  /// User cancelled operation
  factory ScanResult.cancelled({
    ScanResultType type = ScanResultType.scan,
  }) {
    return ScanResult(
      success: false,
      error: 'User cancelled operation',
      type: type,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'document': document?.toJson(),
      'error': error,
      'type': type.toString(),
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      success: json['success'],
      document: json['document'] != null 
          ? ScannedDocument.fromJson(json['document'])
          : null,
      error: json['error'],
      type: ScanResultType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => ScanResultType.scan,
      ),
      metadata: json['metadata'] ?? {},
    );
  }
}

/// Types of scan results
enum ScanResultType {
  scan,           // Direct camera scan
  import,         // Imported from gallery
  download,       // Downloaded from URL/QR
  qrScan,         // QR code scan result
}

/// QR Code scan result specifically for manuals
class QRScanResult extends ScanResult {
  final String qrData;
  final QRContentType contentType;

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

  /// Success QR scan
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

  /// Error QR scan
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

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['qrData'] = qrData;
    json['contentType'] = contentType.toString();
    return json;
  }

  factory QRScanResult.fromJson(Map<String, dynamic> json) {
    return QRScanResult(
      success: json['success'],
      qrData: json['qrData'],
      contentType: QRContentType.values.firstWhere(
        (e) => e.toString() == json['contentType'],
        orElse: () => QRContentType.unknown,
      ),
      document: json['document'] != null 
          ? ScannedDocument.fromJson(json['document'])
          : null,
      error: json['error'],
      metadata: json['metadata'] ?? {},
    );
  }
}

/// Types of QR code content
enum QRContentType {
  url,
  pdfLink,
  manualLink,
  text,
  unknown,
}

