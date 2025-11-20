import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/src/models/scanned_document.dart';

/// Test utilities for document scanner services
class TestUtils {
  /// Creates a minimal valid PNG image (2x2 black pixels)
  static Uint8List createTestPngImage() {
    return Uint8List.fromList([
      // PNG signature
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      // IHDR chunk (2x2 image, 8-bit grayscale)
      0x00, 0x00, 0x00, 0x0D, // Chunk length
      0x49, 0x48, 0x44, 0x52, // Chunk type "IHDR"
      0x00, 0x00, 0x00, 0x02, // Width: 2
      0x00, 0x00, 0x00, 0x02, // Height: 2
      0x08, 0x00, 0x00, 0x00, 0x00, // Bit depth, color type, compression, filter, interlace
      0x4D, 0x18, 0x95, 0x57, // CRC
      // IDAT chunk (minimal image data)
      0x00, 0x00, 0x00, 0x0C, // Chunk length
      0x49, 0x44, 0x41, 0x54, // Chunk type "IDAT"
      0x08, 0x99, 0x01, 0x01, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01, // Compressed data
      0x00, 0x00, 0x00, 0x00, // CRC
      // IEND chunk
      0x00, 0x00, 0x00, 0x00, // Chunk length
      0x49, 0x45, 0x4E, 0x44, // Chunk type "IEND"
      0xAE, 0x42, 0x60, 0x82, // CRC
    ]);
  }

  /// Creates a minimal valid JPEG image
  static Uint8List createTestJpegImage() {
    return Uint8List.fromList([
      // JPEG SOI marker
      0xFF, 0xD8,
      // APP0 marker (JFIF)
      0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00,
      // SOF0 marker (baseline DCT)
      0xFF, 0xC0, 0x00, 0x11, 0x08, 0x00, 0x02, 0x00, 0x02, 0x01,
      0x01, 0x11, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
      // DQT marker
      0xFF, 0xDB, 0x00, 0x43, 0x00, 0x08, 0x06, 0x06, 0x07, 0x06,
      0x05, 0x08, 0x07, 0x07, 0x07, 0x09, 0x09, 0x08, 0x0A, 0x0C,
      0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12, 0x13, 0x0F,
      0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
      0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28,
      0x37, 0x29, 0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27,
      0x39, 0x3D, 0x38, 0x32, 0x3C, 0x2E, 0x33, 0x34, 0x32,
      // SOS marker
      0xFF, 0xDA, 0x00, 0x0C, 0x03, 0x01, 0x00, 0x02, 0x11, 0x03,
      0x11, 0x00, 0x3F, 0x00, 0x80,
      // Minimal image data (compressed)
      0x00, 0x10, 0x01, 0x00,
      // JPEG EOI marker
      0xFF, 0xD9,
    ]);
  }

  /// Creates invalid image data for error testing
  static Uint8List createInvalidImageData() {
    return Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04, 0x05]);
  }

  /// Creates a test ScannedDocument with single page
  static ScannedDocument createTestScannedDocument({
    String? id,
    DocumentType type = DocumentType.receipt,
    DocumentProcessingOptions? options,
    Uint8List? imageData,
  }) {
    return ScannedDocument(
      id: id ?? 'test-doc-${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      originalPath: '/test/original.jpg',
      scanTime: DateTime.now(),
      processingOptions: options ?? const DocumentProcessingOptions(
        convertToGrayscale: true,
        enhanceContrast: true,
        autoCorrectPerspective: true,
        compressionQuality: 0.9,
        generatePdf: true,
        saveImageFile: false,
        pdfResolution: PdfResolution.quality,
      ),
      rawImageData: imageData ?? createTestPngImage(),
      processedImageData: imageData ?? createTestPngImage(),
    );
  }

  /// Creates a test ScannedDocument with multiple pages
  static ScannedDocument createTestMultiPageScannedDocument({
    String? id,
    DocumentType type = DocumentType.manual,
    DocumentProcessingOptions? options,
    int pageCount = 3,
  }) {
    final pages = <DocumentPage>[];
    for (int i = 0; i < pageCount; i++) {
      pages.add(DocumentPage(
        id: 'page-${i + 1}',
        pageNumber: i + 1,
        originalPath: '/test/page${i + 1}.jpg',
        scanTime: DateTime.now(),
        rawImageData: createTestPngImage(),
        processedImageData: createTestPngImage(),
      ));
    }

    return ScannedDocument(
      id: id ?? 'test-multi-doc-${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      originalPath: pages.first.originalPath,
      scanTime: DateTime.now(),
      processingOptions: options ?? const DocumentProcessingOptions(
        convertToGrayscale: false,
        enhanceContrast: false,
        autoCorrectPerspective: true,
        compressionQuality: 0.7,
        generatePdf: true,
        saveImageFile: false,
        pdfResolution: PdfResolution.quality,
      ),
      pages: pages,
      isMultiPage: true,
    );
  }

  /// Creates test corner points for perspective correction
  static List<Offset> createTestCorners({
    double width = 200.0,
    double height = 300.0,
    double margin = 10.0,
  }) {
    return [
      Offset(margin, margin), // Top-left
      Offset(width - margin, margin), // Top-right
      Offset(width - margin, height - margin), // Bottom-right
      Offset(margin, height - margin), // Bottom-left
    ];
  }

  /// Creates invalid corner points for error testing
  static List<Offset> createInvalidCorners() {
    return [
      const Offset(-10.0, 10.0), // Negative coordinate
      const Offset(110.0, 10.0),
      const Offset(110.0, 160.0),
      const Offset(10.0, 160.0),
    ];
  }

  /// Creates incomplete corner points for error testing
  static List<Offset> createIncompleteCorners() {
    return [
      const Offset(10.0, 10.0),
      const Offset(110.0, 10.0),
      const Offset(110.0, 160.0),
      // Missing 4th corner
    ];
  }

  /// Verifies if data is a valid PDF
  static bool isValidPdf(Uint8List data) {
    if (data.length < 4) return false;
    final header = String.fromCharCodes(data.sublist(0, 4));
    return header == '%PDF';
  }

  /// Verifies if data is a valid PNG
  static bool isValidPng(Uint8List data) {
    if (data.length < 8) return false;
    final signature = data.sublist(0, 8);
    final expectedSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    return signature.every((byte) => expectedSignature.contains(byte));
  }

  /// Verifies if data is a valid JPEG
  static bool isValidJpeg(Uint8List data) {
    if (data.length < 2) return false;
    return data[0] == 0xFF && data[1] == 0xD8;
  }

  /// Generates a temporary file path for testing
  static String generateTempFilePath({String extension = 'pdf'}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '/tmp/test_${timestamp}.$extension';
  }

  /// Creates a list of test images for multi-page testing
  static List<Uint8List> createTestImageList({int count = 3}) {
    return List.generate(count, (_) => createTestPngImage());
  }

  /// Creates mock metadata for testing
  static Map<String, dynamic> createMockMetadata({
    String? title,
    String? author,
    String? subject,
    DateTime? creationDate,
    Map<String, dynamic>? additionalData,
  }) {
    final metadata = <String, dynamic>{
      'title': title ?? 'Test Document',
      'author': author ?? 'Test Author',
      'subject': subject ?? 'Test Subject',
      'creationDate': (creationDate ?? DateTime.now()).toIso8601String(),
      'generator': 'document_scanner',
      'version': '1.1.1',
    };
    
    if (additionalData != null) {
      metadata.addAll(additionalData);
    }
    
    return metadata;
  }

  /// Measures execution time of a function
  static Future<Duration> measureExecutionTime(Future<void> Function() function) async {
    final stopwatch = Stopwatch()..start();
    await function();
    stopwatch.stop();
    return stopwatch.elapsed;
  }

  /// Asserts that execution time is within bounds
  static void assertExecutionTime(Duration elapsed, {int maxMs = 5000}) {
    expect(elapsed.inMilliseconds, lessThan(maxMs),
        reason: 'Operation took ${elapsed.inMilliseconds}ms, expected less than ${maxMs}ms');
  }
}