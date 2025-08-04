import 'dart:typed_data';
import 'dart:ui';

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

  /// Convert to Map for compatibility with existing code
  Map<String, dynamic> toMap() {
    return toJson();
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
  final double compressionQuality;
  final ImageFormat outputFormat;
  final bool generatePdf;
  final bool saveImageFile; // Save processed image file alongside PDF
  final PdfResolution pdfResolution; // PDF resolution option
  final DocumentFormat? documentFormat; // Document format for PDF page size
  final String? customFilename;

  const DocumentProcessingOptions({
    this.convertToGrayscale = true,
    this.enhanceContrast = true,
    this.autoCorrectPerspective = true,
    this.compressionQuality = 0.8,
    this.outputFormat = ImageFormat.jpeg,
    this.generatePdf = true,
    this.saveImageFile = false, // Default: save only PDF
    this.pdfResolution = PdfResolution.quality, // Default: 300 DPI quality
    this.documentFormat, // Default: null (will use DocumentType fallback)
    this.customFilename,
  });

  /// Default options for receipts (high contrast, grayscale, PDF only)
  static const receipt = DocumentProcessingOptions(
    convertToGrayscale: true,
    enhanceContrast: true,
    autoCorrectPerspective: true,
    compressionQuality: 0.9,
    generatePdf: true,
    saveImageFile: false, // PDF only
    pdfResolution: PdfResolution.quality, // 300 DPI for archival quality
  );

  /// Default options for manuals (preserve colors, PDF only)
  static const manual = DocumentProcessingOptions(
    convertToGrayscale: false,
    enhanceContrast: false,
    autoCorrectPerspective: true,
    compressionQuality: 0.7,
    generatePdf: true,
    saveImageFile: false, // PDF only
    pdfResolution: PdfResolution.quality, // 300 DPI for detailed diagrams
  );

  /// Default options for documents (balanced, PDF only)
  static const document = DocumentProcessingOptions(
    convertToGrayscale: true,
    enhanceContrast: true,
    autoCorrectPerspective: true,
    compressionQuality: 0.8,
    generatePdf: true,
    saveImageFile: false, // PDF only
    pdfResolution: PdfResolution.quality, // 300 DPI standard
  );

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'convertToGrayscale': convertToGrayscale,
      'enhanceContrast': enhanceContrast,
      'autoCorrectPerspective': autoCorrectPerspective,
      'compressionQuality': compressionQuality,
      'outputFormat': outputFormat.toString(),
      'generatePdf': generatePdf,
      'saveImageFile': saveImageFile,
      'pdfResolution': pdfResolution.toString(),
      'customFilename': customFilename,
    };
  }

  /// Create from JSON
  factory DocumentProcessingOptions.fromJson(Map<String, dynamic> json) {
    return DocumentProcessingOptions(
      convertToGrayscale: json['convertToGrayscale'] ?? true,
      enhanceContrast: json['enhanceContrast'] ?? true,
      autoCorrectPerspective: json['autoCorrectPerspective'] ?? true,
      compressionQuality: json['compressionQuality'] ?? 0.8,
      outputFormat: ImageFormat.values.firstWhere(
        (e) => e.toString() == json['outputFormat'],
        orElse: () => ImageFormat.jpeg,
      ),
      generatePdf: json['generatePdf'] ?? true,
      saveImageFile: json['saveImageFile'] ?? false,
      pdfResolution: PdfResolution.values.firstWhere(
        (e) => e.toString() == json['pdfResolution'],
        orElse: () => PdfResolution.quality,
      ),
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

/// Color filter options for image editing
enum ColorFilter {
  none,
  highContrast,
  blackAndWhite,
}

/// Document format options for crop aspect ratio
enum DocumentFormat {
  auto,        // Use detected dimensions
  isoA,        // A4, A3, A5 - all have same ratio (1:√2)
  usLetter,    // US Letter (8.5" x 11")
  usLegal,     // US Legal (8.5" x 14")
  square,      // Square (1:1)
  receipt,     // Receipt format (narrow and tall)
  businessCard, // Business card format
}

/// PDF resolution options for document output
enum PdfResolution {
  original,    // Use original image resolution (no scaling)
  quality,     // 300 DPI - standard for print/archive quality
  size,        // 150 DPI - optimized for smaller file sizes
}

/// Image editing options
class ImageEditingOptions {
  final int rotationDegrees; // 0, 90, 180, 270
  final ColorFilter colorFilter;
  final List<Offset>? cropCorners; // 4 corners for cropping
  final DocumentFormat documentFormat; // Format for aspect ratio
  
  const ImageEditingOptions({
    this.rotationDegrees = 0,
    this.colorFilter = ColorFilter.none,
    this.cropCorners,
    this.documentFormat = DocumentFormat.auto,
  });
  
  ImageEditingOptions copyWith({
    int? rotationDegrees,
    ColorFilter? colorFilter,
    List<Offset>? cropCorners,
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

