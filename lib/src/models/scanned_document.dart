import 'dart:io';
import 'dart:typed_data';

/// Represents a scanned document with metadata and processing options
class ScannedDocument {
  final String id;
  final DocumentType type;
  final String originalPath;
  final String? processedPath;
  final String? pdfPath;
  final DateTime scanTime;
  final DocumentProcessingOptions processingOptions;
  final Map<String, dynamic> metadata;
  
  // Raw image data for processing
  final Uint8List? rawImageData;
  final Uint8List? processedImageData;
  final Uint8List? pdfData;
  
  // Multi-page support
  final List<DocumentPage> pages;
  final bool isMultiPage;
  
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

  /// Create a copy with updated fields
  ScannedDocument copyWith({
    String? processedPath,
    String? pdfPath,
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
      rawImageData: rawImageData,
      processedImageData: processedImageData ?? this.processedImageData,
      pdfData: pdfData ?? this.pdfData,
      metadata: metadata ?? this.metadata,
      pages: pages ?? this.pages,
      isMultiPage: isMultiPage ?? this.isMultiPage,
    );
  }

  /// Convert to JSON for serialization
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
    };
  }

  /// Create from JSON
  factory ScannedDocument.fromJson(Map<String, dynamic> json) {
    return ScannedDocument(
      id: json['id'],
      type: DocumentType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => DocumentType.other,
      ),
      originalPath: json['originalPath'],
      processedPath: json['processedPath'],
      pdfPath: json['pdfPath'],
      scanTime: DateTime.parse(json['scanTime']),
      processingOptions: DocumentProcessingOptions.fromJson(json['processingOptions']),
      metadata: json['metadata'] ?? {},
    );
  }
}

/// Types of documents that can be scanned
enum DocumentType {
  receipt,
  manual,
  document,
  other,
}

/// Processing options for document scanning
class DocumentProcessingOptions {
  final bool convertToGrayscale;
  final bool enhanceContrast;
  final bool autoCorrectPerspective;
  final bool removeBackground;
  final double compressionQuality;
  final ImageFormat outputFormat;
  final bool generatePdf;
  final String? customFilename;

  const DocumentProcessingOptions({
    this.convertToGrayscale = true,
    this.enhanceContrast = true,
    this.autoCorrectPerspective = true,
    this.removeBackground = false,
    this.compressionQuality = 0.8,
    this.outputFormat = ImageFormat.jpeg,
    this.generatePdf = true,
    this.customFilename,
  });

  /// Default options for receipts (high contrast, grayscale, PDF)
  static const receipt = DocumentProcessingOptions(
    convertToGrayscale: true,
    enhanceContrast: true,
    autoCorrectPerspective: true,
    removeBackground: true,
    compressionQuality: 0.9,
    generatePdf: true,
  );

  /// Default options for manuals (preserve colors, PDF)
  static const manual = DocumentProcessingOptions(
    convertToGrayscale: false,
    enhanceContrast: false,
    autoCorrectPerspective: true,
    removeBackground: false,
    compressionQuality: 0.7,
    generatePdf: true,
  );

  /// Default options for documents (balanced)
  static const document = DocumentProcessingOptions(
    convertToGrayscale: true,
    enhanceContrast: true,
    autoCorrectPerspective: true,
    removeBackground: false,
    compressionQuality: 0.8,
    generatePdf: true,
  );

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'convertToGrayscale': convertToGrayscale,
      'enhanceContrast': enhanceContrast,
      'autoCorrectPerspective': autoCorrectPerspective,
      'removeBackground': removeBackground,
      'compressionQuality': compressionQuality,
      'outputFormat': outputFormat.toString(),
      'generatePdf': generatePdf,
      'customFilename': customFilename,
    };
  }

  /// Create from JSON
  factory DocumentProcessingOptions.fromJson(Map<String, dynamic> json) {
    return DocumentProcessingOptions(
      convertToGrayscale: json['convertToGrayscale'] ?? true,
      enhanceContrast: json['enhanceContrast'] ?? true,
      autoCorrectPerspective: json['autoCorrectPerspective'] ?? true,
      removeBackground: json['removeBackground'] ?? false,
      compressionQuality: json['compressionQuality'] ?? 0.8,
      outputFormat: ImageFormat.values.firstWhere(
        (e) => e.toString() == json['outputFormat'],
        orElse: () => ImageFormat.jpeg,
      ),
      generatePdf: json['generatePdf'] ?? true,
      customFilename: json['customFilename'],
    );
  }
}

/// Supported image formats
enum ImageFormat {
  jpeg,
  png,
  webp,
}

/// Represents a single page in a multi-page document
class DocumentPage {
  final String id;
  final int pageNumber;
  final String originalPath;
  final String? processedPath;
  final DateTime scanTime;
  final Uint8List? rawImageData;
  final Uint8List? processedImageData;
  final Map<String, dynamic> metadata;

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

  /// Create a copy with updated fields
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

  /// Convert to JSON
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

  /// Create from JSON
  factory DocumentPage.fromJson(Map<String, dynamic> json) {
    return DocumentPage(
      id: json['id'],
      pageNumber: json['pageNumber'],
      originalPath: json['originalPath'],
      processedPath: json['processedPath'],
      scanTime: DateTime.parse(json['scanTime']),
      metadata: json['metadata'] ?? {},
    );
  }
}

/// Multi-page document session for progressive scanning
class MultiPageScanSession {
  final String sessionId;
  final DocumentType documentType;
  final DocumentProcessingOptions processingOptions;
  final List<DocumentPage> pages;
  final DateTime startTime;
  final String? customFilename;
  
  MultiPageScanSession({
    required this.sessionId,
    required this.documentType,
    required this.processingOptions,
    required this.startTime,
    this.pages = const [],
    this.customFilename,
  });

  /// Add a new page to the session
  MultiPageScanSession addPage(DocumentPage page) {
    final updatedPages = [...pages, page];
    return MultiPageScanSession(
      sessionId: sessionId,
      documentType: documentType,
      processingOptions: processingOptions,
      startTime: startTime,
      pages: updatedPages,
      customFilename: customFilename,
    );
  }

  /// Remove a page from the session
  MultiPageScanSession removePage(String pageId) {
    final updatedPages = pages.where((p) => p.id != pageId).toList();
    return MultiPageScanSession(
      sessionId: sessionId,
      documentType: documentType,
      processingOptions: processingOptions,
      startTime: startTime,
      pages: updatedPages,
      customFilename: customFilename,
    );
  }

  /// Reorder pages in the session
  MultiPageScanSession reorderPages(List<DocumentPage> reorderedPages) {
    return MultiPageScanSession(
      sessionId: sessionId,
      documentType: documentType,
      processingOptions: processingOptions,
      startTime: startTime,
      pages: reorderedPages,
      customFilename: customFilename,
    );
  }

  /// Convert to final ScannedDocument
  ScannedDocument toScannedDocument() {
    return ScannedDocument(
      id: sessionId,
      type: documentType,
      originalPath: pages.isNotEmpty ? pages.first.originalPath : '',
      scanTime: startTime,
      processingOptions: processingOptions,
      pages: pages,
      isMultiPage: pages.length > 1,
      metadata: {
        'pageCount': pages.length,
        'sessionStartTime': startTime.toIso8601String(),
        'customFilename': customFilename,
      },
    );
  }

  /// Check if session is ready for finalization
  bool get isReadyForFinalization => pages.isNotEmpty;
  
  /// Get total page count
  int get pageCount => pages.length;
}

// AIDEV-NOTE: This model supports both single and multi-page documents
// MultiPageScanSession manages the progressive scanning workflow