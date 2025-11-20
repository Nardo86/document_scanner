import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/src/models/scanned_document.dart';

/// Test configuration and utilities for document scanner package
/// 
/// This file provides global test configuration and helper functions
/// that can be used across all test files in the package.

/// Global test setup
void setUpGlobalTests() {
  // Configure test timeout
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Note: Individual tests should use timeout parameter in test() function
  // Global timeout setting is not available in current Flutter test version
}

/// Test suite information
class TestSuiteInfo {
  static const String packageName = 'document_scanner';
  static const String version = '1.1.1';
  static const List<String> testCategories = [
    'ImageProcessor',
    'PdfGenerator',
    'DocumentScannerService',
    'QRScannerService',
    'UI Components',
  ];
  
  static const Map<String, List<String>> testFeatures = {
    'ImageProcessor': [
      'Edge Detection',
      'Perspective Correction',
      'Image Rotation',
      'Color Filters',
      'Image Resizing',
      'Document Processing',
      'Error Handling',
      'Performance',
    ],
    'PdfGenerator': [
      'Single Page PDF',
      'Multi Page PDF',
      'PDF from Scanned Document',
      'PDF Saving',
      'Error Handling',
      'Configuration',
      'Performance',
    ],
  };
}

/// Performance benchmarks
class PerformanceBenchmarks {
  static const Duration maxEdgeDetectionTime = Duration(seconds: 5);
  static const Duration maxDocumentProcessingTime = Duration(seconds: 10);
  static const Duration maxSinglePagePdfTime = Duration(seconds: 5);
  static const Duration maxMultiPagePdfTime = Duration(seconds: 15);
  
  static const int maxImageSizeForPerformanceTests = 1024 * 1024; // 1MB
  static const int maxPageCountForMultiPageTests = 10;
}

/// Test data configurations
class TestDataConfig {
  static const double defaultTestImageWidth = 200.0;
  static const double defaultTestImageHeight = 300.0;
  static const double defaultMargin = 10.0;
  
  static const List<int> validRotations = [0, 90, 180, 270];
  static const List<int> invalidRotations = [45, 135, 225, 315, -90];
  
  static const List<ColorFilter> allColorFilters = [
    ColorFilter.none,
    ColorFilter.highContrast,
    ColorFilter.blackAndWhite,
  ];
  
  static const List<DocumentFormat> allDocumentFormats = [
    DocumentFormat.auto,
    DocumentFormat.isoA,
    DocumentFormat.usLetter,
    DocumentFormat.usLegal,
    DocumentFormat.square,
    DocumentFormat.receipt,
    DocumentFormat.businessCard,
  ];
  
  static const List<PdfResolution> allPdfResolutions = [
    PdfResolution.original,
    PdfResolution.quality,
    PdfResolution.size,
  ];
  
  static const List<DocumentType> allDocumentTypes = [
    DocumentType.receipt,
    DocumentType.manual,
    DocumentType.document,
    DocumentType.other,
  ];
}

/// Test assertion helpers
class TestAssertions {
  /// Asserts that a PDF is valid
  static void assertValidPdf(Uint8List pdfData) {
    expect(pdfData, isNotNull);
    expect(pdfData!.isNotEmpty, isTrue);
    expect(pdfData.length, greaterThan(4));
    
    final header = String.fromCharCodes(pdfData.sublist(0, 4));
    expect(header, equals('%PDF'));
  }
  
  /// Asserts that an image is valid (PNG or JPEG)
  static void assertValidImage(Uint8List imageData) {
    expect(imageData, isNotNull);
    expect(imageData!.isNotEmpty, isTrue);
    expect(imageData.length, greaterThan(8));
    
    // Check for PNG signature
    if (imageData.length >= 8) {
      final pngSignature = imageData.sublist(0, 8);
      final expectedPngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
      if (pngSignature.every((byte) => expectedPngSignature.contains(byte))) {
        return; // Valid PNG
      }
    }
    
    // Check for JPEG signature
    if (imageData.length >= 2) {
      if (imageData[0] == 0xFF && imageData[1] == 0xD8) {
        return; // Valid JPEG
      }
    }
    
    fail('Invalid image data: not a valid PNG or JPEG');
  }
  
  /// Asserts that execution time is within bounds
  static void assertPerformance(Duration elapsed, Duration maxDuration) {
    expect(elapsed.inMilliseconds, lessThan(maxDuration.inMilliseconds),
        reason: 'Operation took ${elapsed.inMilliseconds}ms, expected less than ${maxDuration.inMilliseconds}ms');
  }
}

/// Mock data generators for testing
class MockDataGenerator {
  /// Creates mock corner points for testing
  static List<Offset> createMockCorners({
    double width = TestDataConfig.defaultTestImageWidth,
    double height = TestDataConfig.defaultTestImageHeight,
    double margin = TestDataConfig.defaultMargin,
  }) {
    return [
      Offset(margin, margin),
      Offset(width - margin, margin),
      Offset(width - margin, height - margin),
      Offset(margin, height - margin),
    ];
  }
  
  /// Creates mock corner points with perspective distortion
  static List<Offset> createPerspectiveCorners({
    double width = TestDataConfig.defaultTestImageWidth,
    double height = TestDataConfig.defaultTestImageHeight,
    double distortion = 20.0,
  }) {
    return [
      Offset(distortion, distortion),
      Offset(width - distortion, distortion * 0.5),
      Offset(width - distortion * 0.5, height - distortion * 0.5),
      Offset(distortion * 0.5, height - distortion),
    ];
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
      'generator': TestSuiteInfo.packageName,
      'version': TestSuiteInfo.version,
    };
    
    if (additionalData != null) {
      metadata.addAll(additionalData);
    }
    
    return metadata;
  }
}