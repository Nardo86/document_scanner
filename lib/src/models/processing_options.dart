/// Processing configuration for document scanning and image transformation.
///
/// [DocumentProcessingOptions] encapsulates all parameters controlling how a scanned
/// image is processed, including color adjustments, PDF generation, and output format.
/// Named constructors provide sensible defaults for common document types.
class DocumentProcessingOptions {
  /// Whether to convert the image to grayscale (black and white)
  final bool convertToGrayscale;

  /// Whether to enhance contrast for better readability
  final bool enhanceContrast;

  /// Whether to automatically detect and correct perspective distortion
  final bool autoCorrectPerspective;

  /// Compression quality for the output image (0.0 to 1.0, where 1.0 is highest quality)
  final double compressionQuality;

  /// The output format for processed images
  final ImageFormat outputFormat;

  /// Whether to generate a PDF file from the document
  final bool generatePdf;

  /// Whether to save the processed image file alongside the PDF
  final bool saveImageFile;

  /// The resolution/DPI setting for PDF output
  final PdfResolution pdfResolution;

  /// Optional document format that determines aspect ratio during cropping
  final DocumentFormat? documentFormat;

  /// Custom filename for the output file (without extension)
  final String? customFilename;

  /// Creates a new [DocumentProcessingOptions] with the specified settings.
  ///
  /// All parameters have sensible defaults, so you typically only need to specify
  /// the options you want to override.
  ///
  /// Example:
  /// ```dart
  /// const options = DocumentProcessingOptions(
  ///   convertToGrayscale: true,
  ///   enhanceContrast: true,
  ///   compressionQuality: 0.85,
  /// );
  /// ```
  const DocumentProcessingOptions({
    this.convertToGrayscale = true,
    this.enhanceContrast = true,
    this.autoCorrectPerspective = true,
    this.compressionQuality = 0.8,
    this.outputFormat = ImageFormat.jpeg,
    this.generatePdf = true,
    this.saveImageFile = false,
    this.pdfResolution = PdfResolution.quality,
    this.documentFormat,
    this.customFilename,
  });

  /// Default processing options optimized for receipts.
  ///
  /// Features:
  /// - Converts to grayscale for cleaner text
  /// - Enhances contrast for better OCR and archival
  /// - Corrects perspective distortion
  /// - High compression quality (0.9) for good detail
  /// - Generates PDF only (no separate image file)
  /// - Uses 300 DPI for archival quality
  static const DocumentProcessingOptions receipt = DocumentProcessingOptions(
    convertToGrayscale: true,
    enhanceContrast: true,
    autoCorrectPerspective: true,
    compressionQuality: 0.9,
    generatePdf: true,
    saveImageFile: false,
    pdfResolution: PdfResolution.quality,
  );

  /// Default processing options optimized for manuals and color documents.
  ///
  /// Features:
  /// - Preserves colors for diagrams and illustrations
  /// - No contrast enhancement to maintain color fidelity
  /// - Corrects perspective distortion
  /// - Good compression (0.7) while preserving colors
  /// - Generates PDF only
  /// - Uses 300 DPI for detailed diagrams
  static const DocumentProcessingOptions manual = DocumentProcessingOptions(
    convertToGrayscale: false,
    enhanceContrast: false,
    autoCorrectPerspective: true,
    compressionQuality: 0.7,
    generatePdf: true,
    saveImageFile: false,
    pdfResolution: PdfResolution.quality,
  );

  /// Default processing options balanced for general documents.
  ///
  /// Features:
  /// - Converts to grayscale for text clarity
  /// - Enhances contrast for readability
  /// - Corrects perspective distortion
  /// - Balanced compression (0.8)
  /// - Generates PDF only
  /// - Uses 300 DPI standard for documents
  static const DocumentProcessingOptions document = DocumentProcessingOptions(
    convertToGrayscale: true,
    enhanceContrast: true,
    autoCorrectPerspective: true,
    compressionQuality: 0.8,
    generatePdf: true,
    saveImageFile: false,
    pdfResolution: PdfResolution.quality,
  );

  /// Creates a copy of these options with specified fields overridden.
  ///
  /// Useful for creating variations of standard presets.
  ///
  /// Example:
  /// ```dart
  /// final custom = DocumentProcessingOptions.receipt.copyWith(
  ///   compressionQuality: 0.95,
  ///   customFilename: 'receipt_2024_01_15',
  /// );
  /// ```
  DocumentProcessingOptions copyWith({
    bool? convertToGrayscale,
    bool? enhanceContrast,
    bool? autoCorrectPerspective,
    double? compressionQuality,
    ImageFormat? outputFormat,
    bool? generatePdf,
    bool? saveImageFile,
    PdfResolution? pdfResolution,
    DocumentFormat? documentFormat,
    String? customFilename,
  }) {
    return DocumentProcessingOptions(
      convertToGrayscale: convertToGrayscale ?? this.convertToGrayscale,
      enhanceContrast: enhanceContrast ?? this.enhanceContrast,
      autoCorrectPerspective: autoCorrectPerspective ?? this.autoCorrectPerspective,
      compressionQuality: compressionQuality ?? this.compressionQuality,
      outputFormat: outputFormat ?? this.outputFormat,
      generatePdf: generatePdf ?? this.generatePdf,
      saveImageFile: saveImageFile ?? this.saveImageFile,
      pdfResolution: pdfResolution ?? this.pdfResolution,
      documentFormat: documentFormat ?? this.documentFormat,
      customFilename: customFilename ?? this.customFilename,
    );
  }

  /// Converts these options to a JSON representation.
  ///
  /// Useful for:
  /// - Persisting options to disk
  /// - Sending settings over network
  /// - Logging for debugging
  ///
  /// Use [fromJson] to deserialize.
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
      'documentFormat': documentFormat?.toString(),
      'customFilename': customFilename,
    };
  }

  /// Creates [DocumentProcessingOptions] from a JSON representation.
  ///
  /// All fields have sensible defaults, so missing fields in the JSON will use those defaults.
  ///
  /// Example:
  /// ```dart
  /// final options = DocumentProcessingOptions.fromJson({
  ///   'convertToGrayscale': true,
  ///   'enhanceContrast': true,
  ///   'compressionQuality': 0.85,
  /// });
  /// ```
  factory DocumentProcessingOptions.fromJson(Map<String, dynamic> json) {
    return DocumentProcessingOptions(
      convertToGrayscale: json['convertToGrayscale'] as bool? ?? true,
      enhanceContrast: json['enhanceContrast'] as bool? ?? true,
      autoCorrectPerspective: json['autoCorrectPerspective'] as bool? ?? true,
      compressionQuality: (json['compressionQuality'] as num?)?.toDouble() ?? 0.8,
      outputFormat: _parseImageFormat(json['outputFormat']),
      generatePdf: json['generatePdf'] as bool? ?? true,
      saveImageFile: json['saveImageFile'] as bool? ?? false,
      pdfResolution: _parsePdfResolution(json['pdfResolution']),
      documentFormat: _parseDocumentFormat(json['documentFormat']),
      customFilename: json['customFilename'] as String?,
    );
  }
}

/// Supported image formats for processing output
enum ImageFormat {
  /// JPEG format - good compression, widely compatible
  jpeg,

  /// PNG format - lossless, larger files but better quality
  png,

  /// WebP format - modern compression, smaller files
  webp,
}

/// Document format options controlling aspect ratio and cropping behavior
enum DocumentFormat {
  /// Auto-detect document bounds and use detected dimensions
  auto,

  /// ISO A series (A0-A10): all have the same aspect ratio (1:√2)
  /// Examples: A4 (210 x 297 mm), A3 (297 x 420 mm)
  isoA,

  /// US Letter: 8.5" x 11" (standard office paper)
  usLetter,

  /// US Legal: 8.5" x 14" (legal documents)
  usLegal,

  /// Square format (1:1)
  square,

  /// Receipt format: narrow and tall (typically 3.5" x 6-8")
  receipt,

  /// Business card format: 3.5" x 2" (standard business card)
  businessCard,
}

/// PDF resolution/DPI options for output quality and file size optimization
enum PdfResolution {
  /// Use original image resolution without scaling (largest file size, best quality)
  original,

  /// 300 DPI - standard for print and archival quality
  quality,

  /// 150 DPI - optimized for smaller file sizes while maintaining readability
  size,
}

// Helper functions for parsing enums from JSON strings
ImageFormat _parseImageFormat(dynamic value) {
  if (value == null) return ImageFormat.jpeg;
  if (value is String) {
    return ImageFormat.values.firstWhere(
      (e) => e.toString() == value,
      orElse: () => ImageFormat.jpeg,
    );
  }
  return ImageFormat.jpeg;
}

PdfResolution _parsePdfResolution(dynamic value) {
  if (value == null) return PdfResolution.quality;
  if (value is String) {
    return PdfResolution.values.firstWhere(
      (e) => e.toString() == value,
      orElse: () => PdfResolution.quality,
    );
  }
  return PdfResolution.quality;
}

DocumentFormat? _parseDocumentFormat(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    return DocumentFormat.values.firstWhere(
      (e) => e.toString() == value,
      orElse: () => DocumentFormat.auto,
    );
  }
  return null;
}
