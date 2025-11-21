import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/scanned_document.dart';

/// Service for generating PDF documents from scanned images
/// 
/// This service creates PDF documents with proper page sizing, DPI control,
/// and embedded metadata. It supports both single-page and multi-page document
/// generation with various paper formats and orientations.
/// 
/// **Supported Features:**
/// - Multiple page formats (A4, US Letter, US Legal, Receipt, Square, Business Card)
/// - DPI control for file size management (original, quality ~300 DPI, size ~150 DPI)
/// - Embedded metadata (title, author, subject, keywords, custom properties)
/// - Page numbering for multi-page documents
/// - Memory-efficient handling of large documents
class PdfGenerator {
  static const String _defaultAuthor = 'Document Scanner';

  /// Generate PDF from processed image data with resolution control
  /// 
  /// Creates a single-page PDF with the specified format and resolution settings.
  /// The image is scaled according to the [resolution] parameter and fitted to
  /// the page format derived from [documentType] and [documentFormat].
  /// 
  /// **Parameters:**
  /// - [imageData]: The processed image data as bytes
  /// - [documentType]: Type of document (receipt, manual, document, other)
  /// - [resolution]: DPI target (original, quality ~300 DPI, size ~150 DPI)
  /// - [documentFormat]: Optional format override (A4, US Letter, etc.)
  /// - [metadata]: Optional metadata map for custom properties and document info
  /// 
  /// **Returns:** PDF document as [Uint8List]
  /// 
  /// **Throws:** Exception if PDF generation fails
  Future<Uint8List> generatePdf({
    required Uint8List imageData,
    required DocumentType documentType,
    required PdfResolution resolution,
    DocumentFormat? documentFormat,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Prepare document metadata
      final docMetadata = _prepareDocumentMetadata(
        documentType: documentType,
        metadata: metadata,
        pageCount: 1,
      );
      
      // Create PDF with metadata
      final pdf = pw.Document(
        title: docMetadata['title'],
        author: docMetadata['author'],
        creator: docMetadata['creator'],
        subject: docMetadata['subject'],
        keywords: docMetadata['keywords'],
        producer: docMetadata['producer'],
      );
      
      // Create PDF page with the image at specified resolution
      final image = pw.MemoryImage(imageData);
      final pageFormat = _getPageFormat(documentType, documentFormat);
      
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(5), // Minimal margin
          build: (pw.Context context) {
            return pw.Center(
              child: _buildImageWithResolution(image, resolution, pageFormat, documentFormat),
            );
          },
        ),
      );

      return await pdf.save();
    } catch (e) {
      throw Exception('Failed to generate PDF: $e');
    }
  }

  /// Generate multi-page PDF from multiple images with resolution control
  /// 
  /// Creates a multi-page PDF with consistent formatting across all pages.
  /// Each page includes a page number footer (X of Y) in the bottom-right corner.
  /// 
  /// **Parameters:**
  /// - [imageDataList]: List of processed image data as bytes, one per page
  /// - [documentType]: Type of document (receipt, manual, document, other)
  /// - [resolution]: DPI target (original, quality ~300 DPI, size ~150 DPI)
  /// - [documentFormat]: Optional format override (A4, US Letter, etc.)
  /// - [metadata]: Optional metadata map for custom properties and document info
  /// 
  /// **Returns:** PDF document as [Uint8List]
  /// 
  /// **Throws:** Exception if PDF generation fails
  /// 
  /// **Memory Management:**
  /// Images are processed one at a time to avoid memory leaks with large documents.
  /// Each page reuses the pw.MemoryImage without keeping extra copies.
  Future<Uint8List> generateMultiPagePdf({
    required List<Uint8List> imageDataList,
    required DocumentType documentType,
    required PdfResolution resolution,
    DocumentFormat? documentFormat,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Prepare document metadata with page count
      final docMetadata = _prepareDocumentMetadata(
        documentType: documentType,
        metadata: metadata,
        pageCount: imageDataList.length,
      );
      
      // Create PDF with metadata
      final pdf = pw.Document(
        title: docMetadata['title'],
        author: docMetadata['author'],
        creator: docMetadata['creator'],
        subject: docMetadata['subject'],
        keywords: docMetadata['keywords'],
        producer: docMetadata['producer'],
      );
      
      final pageFormat = _getPageFormat(documentType, documentFormat);
      
      // Process each page individually to manage memory efficiently
      for (int i = 0; i < imageDataList.length; i++) {
        final imageData = imageDataList[i];
        final image = pw.MemoryImage(imageData);
        
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: const pw.EdgeInsets.all(5), // Minimal margin
            build: (pw.Context context) {
              return pw.Stack(
                children: [
                  // Main content - centered image with resolution control
                  pw.Center(
                    child: _buildImageWithResolution(image, resolution, pageFormat, documentFormat),
                  ),
                  
                  // Page number footer in bottom-right corner
                  pw.Positioned(
                    bottom: 5,
                    right: 5,
                    child: pw.Text(
                      '${i + 1}/${imageDataList.length}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }

      return await pdf.save();
    } catch (e) {
      throw Exception('Failed to generate multi-page PDF: $e');
    }
  }

  /// Prepare PDF document metadata for initialization
  /// 
  /// Extracts and formats metadata fields (title, author, subject, keywords)
  /// from the provided metadata map and document information.
  /// 
  /// Returns a map with all metadata fields ready to be passed to pw.Document constructor.
  Map<String, String?> _prepareDocumentMetadata({
    required DocumentType documentType,
    Map<String, dynamic>? metadata,
    required int pageCount,
  }) {
    final now = DateTime.now();
    
    // Extract metadata values
    final customFilename = metadata?['customFilename'] as String?;
    final source = metadata?['source'] as String?;
    final author = metadata?['author'] as String? ?? metadata?['appName'] as String? ?? _defaultAuthor;
    
    // Generate title
    String title;
    if (customFilename != null && customFilename.isNotEmpty) {
      title = customFilename;
    } else {
      title = '${_getDocumentTypeName(documentType)} - ${_formatDate(now)}';
    }
    
    // Generate subject
    final subject = metadata?['subject'] as String? ?? 
        '${_getDocumentTypeName(documentType)} ${pageCount > 1 ? '($pageCount pages)' : ''}';
    
    // Generate keywords
    final keywords = _buildKeywords(documentType, metadata, source);
    
    return {
      'title': title,
      'author': author,
      'creator': author,
      'subject': subject.trim(),
      'keywords': keywords,
      'producer': 'Document Scanner PDF Generator',
    };
  }

  /// Get appropriate page format for document type and format
  /// 
  /// Maps DocumentFormat and DocumentType to real PdfPageFormat values.
  /// Supports portrait and landscape orientations based on format characteristics.
  /// 
  /// **Supported Formats:**
  /// - A4 (210 x 297 mm) - ISO A series
  /// - US Letter (8.5 x 11 in)
  /// - US Legal (8.5 x 14 in)
  /// - Receipt (narrow and tall, ~80 x 297 mm)
  /// - Square (210 x 210 mm)
  /// - Business Card (85 x 55 mm)
  PdfPageFormat _getPageFormat(DocumentType documentType, DocumentFormat? documentFormat) {
    // Determine format priority: explicit documentFormat > documentType fallback
    final format = documentFormat ?? _getDefaultFormatForType(documentType);
    
    switch (format) {
      case DocumentFormat.auto:
      case DocumentFormat.isoA:
        // Standard A4 portrait
        return PdfPageFormat.a4;
      
      case DocumentFormat.usLetter:
        // US Letter (8.5" x 11")
        return PdfPageFormat.letter;
      
      case DocumentFormat.usLegal:
        // US Legal (8.5" x 14")
        return PdfPageFormat.legal;
      
      case DocumentFormat.square:
        // Square format (210 x 210 mm, same width as A4)
        return PdfPageFormat(
          210 * PdfPageFormat.mm,
          210 * PdfPageFormat.mm,
        );
      
      case DocumentFormat.receipt:
        // Receipt format (narrow and tall, typical thermal receipt width ~80mm)
        return PdfPageFormat(
          80 * PdfPageFormat.mm,
          297 * PdfPageFormat.mm, // A4 height
        );
      
      case DocumentFormat.businessCard:
        // Business card (85 x 55 mm) - landscape orientation
        return PdfPageFormat(
          85 * PdfPageFormat.mm,
          55 * PdfPageFormat.mm,
        );
    }
  }

  /// Get default document format for a document type
  DocumentFormat _getDefaultFormatForType(DocumentType documentType) {
    switch (documentType) {
      case DocumentType.receipt:
        return DocumentFormat.receipt;
      case DocumentType.manual:
        return DocumentFormat.isoA;
      case DocumentType.document:
        return DocumentFormat.isoA;
      case DocumentType.other:
        return DocumentFormat.auto;
    }
  }

  /// Build image widget with resolution control and document format scaling
  /// 
  /// Scales the image according to the resolution setting:
  /// - **original**: Uses the image's native resolution, contained within page bounds
  /// - **quality**: Targets ~300 DPI for print-quality output
  /// - **size**: Targets ~150 DPI for smaller file sizes
  /// 
  /// The fit behavior depends on the document format:
  /// - auto format: maintains aspect ratio (contain)
  /// - specific formats: stretches to fit format (fill) for proper document alignment
  pw.Widget _buildImageWithResolution(
    pw.MemoryImage image,
    PdfResolution resolution,
    PdfPageFormat pageFormat,
    DocumentFormat? documentFormat,
  ) {
    // Calculate maximum dimensions based on document format
    final maxDimensions = _calculateMaxDimensionsForFormat(pageFormat, documentFormat);
    
    // Determine fit behavior based on document format
    // Auto format: maintain aspect ratio (contain)
    // Specific formats: stretch to fit format (fill)
    final boxFit = (documentFormat == null || documentFormat == DocumentFormat.auto)
        ? pw.BoxFit.contain
        : pw.BoxFit.fill;
    
    switch (resolution) {
      case PdfResolution.original:
        // Use original image resolution but constrained by document format
        return pw.Image(
          image,
          fit: boxFit,
          width: maxDimensions['width'],
          height: maxDimensions['height'],
        );
      
      case PdfResolution.quality:
        // 300 DPI for print quality, constrained by document format
        // This ensures high-quality output suitable for archival and printing
        return pw.Image(
          image,
          fit: boxFit,
          width: maxDimensions['width'],
          height: maxDimensions['height'],
          dpi: 300,
        );
      
      case PdfResolution.size:
        // 150 DPI for smaller file size, constrained by document format
        // This reduces file size while maintaining acceptable quality
        return pw.Image(
          image,
          fit: boxFit,
          width: maxDimensions['width'],
          height: maxDimensions['height'],
          dpi: 150,
        );
    }
  }

  /// Calculate maximum dimensions based on document format
  /// 
  /// Returns the maximum width and height for the image based on the page format
  /// and document format. The image will be scaled to fit within these dimensions
  /// while maintaining aspect ratio (contain) or filling the area (fill).
  Map<String, double> _calculateMaxDimensionsForFormat(PdfPageFormat pageFormat, DocumentFormat? documentFormat) {
    // Page dimensions with margins (5 points on each side)
    final usableWidth = pageFormat.width - 10;
    final usableHeight = pageFormat.height - 10;
    
    if (documentFormat == null) {
      // No format specified, use full page
      return {
        'width': usableWidth,
        'height': usableHeight,
      };
    }
    
    switch (documentFormat) {
      case DocumentFormat.auto:
        // Use full page dimensions
        return {
          'width': usableWidth,
          'height': usableHeight,
        };
      
      case DocumentFormat.isoA:
        // A4 aspect ratio (1:√2 ≈ 1:1.414)
        return {
          'width': usableWidth,
          'height': usableHeight,
        };
      
      case DocumentFormat.usLetter:
        // US Letter aspect ratio (8.5:11 ≈ 1:1.294)
        final letterHeight = usableWidth * (11.0 / 8.5);
        return {
          'width': usableWidth,
          'height': letterHeight.clamp(0, usableHeight),
        };
      
      case DocumentFormat.usLegal:
        // US Legal aspect ratio (8.5:14 ≈ 1:1.647)
        final legalHeight = usableWidth * (14.0 / 8.5);
        return {
          'width': usableWidth,
          'height': legalHeight.clamp(0, usableHeight),
        };
      
      case DocumentFormat.square:
        // Square aspect ratio (1:1)
        final squareSize = usableWidth < usableHeight ? usableWidth : usableHeight;
        return {
          'width': squareSize,
          'height': squareSize,
        };
      
      case DocumentFormat.receipt:
        // Receipt aspect ratio (narrow and tall, approximately 3:11)
        final receiptWidth = usableHeight * (3.0 / 11.0);
        return {
          'width': receiptWidth.clamp(0, usableWidth),
          'height': usableHeight,
        };
      
      case DocumentFormat.businessCard:
        // Business card aspect ratio (3.5:2)
        final cardHeight = usableWidth * (2.0 / 3.5);
        return {
          'width': usableWidth,
          'height': cardHeight.clamp(0, usableHeight),
        };
    }
  }

  /// Get human-readable document type name
  String _getDocumentTypeName(DocumentType type) {
    switch (type) {
      case DocumentType.receipt:
        return 'Receipt';
      case DocumentType.manual:
        return 'Manual';
      case DocumentType.document:
        return 'Document';
      case DocumentType.other:
        return 'Document';
    }
  }

  /// Format date for PDF metadata
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Build keywords string from document type and metadata
  String _buildKeywords(DocumentType documentType, Map<String, dynamic>? metadata, String? source) {
    final keywords = <String>[
      _getDocumentTypeName(documentType),
      'scanned',
    ];
    
    if (source != null) {
      keywords.add(source);
    }
    
    // Add custom keywords from metadata
    if (metadata != null) {
      if (metadata['keywords'] is String) {
        keywords.add(metadata['keywords'] as String);
      } else if (metadata['keywords'] is List) {
        keywords.addAll((metadata['keywords'] as List).map((k) => k.toString()));
      }
      
      // Add document format if present
      if (metadata['documentFormat'] != null) {
        keywords.add(metadata['documentFormat'].toString());
      }
    }
    
    return keywords.join(', ');
  }

  /// Create PDF with custom layout for receipts (deprecated - use generatePdf)
  @Deprecated('Use generatePdf with PdfResolution parameter instead')
  Future<Uint8List> generateReceiptPdf({
    required Uint8List imageData,
    Map<String, dynamic>? metadata,
  }) async {
    return generatePdf(
      imageData: imageData,
      documentType: DocumentType.receipt,
      resolution: PdfResolution.quality,
      metadata: metadata,
    );
  }

  /// Create PDF with custom layout for manuals (deprecated - use generatePdf)
  @Deprecated('Use generatePdf with PdfResolution parameter instead')
  Future<Uint8List> generateManualPdf({
    required Uint8List imageData,
    Map<String, dynamic>? metadata,
  }) async {
    return generatePdf(
      imageData: imageData,
      documentType: DocumentType.manual,
      resolution: PdfResolution.quality,
      metadata: metadata,
    );
  }
}
