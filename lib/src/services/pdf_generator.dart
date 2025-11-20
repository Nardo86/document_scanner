import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/processing_options.dart';
import '../models/scanned_document.dart';

/// Service for generating PDF documents from scanned images
class PdfGenerator {
  /// Generate PDF from processed image data with resolution control
  Future<Uint8List> generatePdf({
    required Uint8List imageData,
    required DocumentType documentType,
    required PdfResolution resolution,
    DocumentFormat? documentFormat,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final pdf = pw.Document();
      
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
  /// NOTE: This method is ready for integration when multi-page workflow is implemented
  Future<Uint8List> generateMultiPagePdf({
    required List<Uint8List> imageDataList,
    required DocumentType documentType,
    required PdfResolution resolution,
    DocumentFormat? documentFormat,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final pdf = pw.Document();
      final pageFormat = _getPageFormat(documentType, documentFormat);
      
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
                  
                  // Page number in bottom-right corner
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


  /// Get appropriate page format for document type and format
  /// NOTE: PDF is always A4, documentFormat only affects image scaling
  PdfPageFormat _getPageFormat(DocumentType documentType, DocumentFormat? documentFormat) {
    // Always return A4 format - documentFormat only affects image scaling
    return PdfPageFormat.a4;
  }


  /// Build image widget with resolution control and document format scaling
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
        return pw.Image(
          image,
          fit: boxFit,
          width: maxDimensions['width'],
          height: maxDimensions['height'],
          dpi: 300,
        );
      
      case PdfResolution.size:
        // 150 DPI for smaller file size, constrained by document format
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
  /// The image will be scaled to fit within these dimensions while maintaining aspect ratio
  Map<String, double> _calculateMaxDimensionsForFormat(PdfPageFormat pageFormat, DocumentFormat? documentFormat) {
    // A4 page dimensions with margins (5 points on each side)
    final usableWidth = pageFormat.width - 10;  // ~585 points
    final usableHeight = pageFormat.height - 10; // ~832 points
    
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