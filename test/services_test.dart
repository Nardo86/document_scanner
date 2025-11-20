import 'package:flutter_test/flutter_test.dart';

// Import test configuration
import 'test_config.dart';

// Import service tests
import 'src/services/image_processor_test.dart';
import 'src/services/pdf_generator_test.dart';

/// Main test runner for document scanner services
/// 
/// This file runs all unit tests for the core services:
/// - ImageProcessor: Edge detection, perspective correction, rotation, filters, resizing
/// - PdfGenerator: Single/multi-page PDF generation, DPI control, metadata
void main() {
  // Set up global test configuration
  setUpGlobalTests();
  
  group('Document Scanner Services Test Suite', () {
    // Test suite metadata
    test('verify test suite is loaded', () {
      expect(TestSuiteInfo.packageName, equals('document_scanner'));
      expect(TestSuiteInfo.testCategories, contains('ImageProcessor'));
      expect(TestSuiteInfo.testCategories, contains('PdfGenerator'));
    });
    
    test('verify performance benchmarks are defined', () {
      expect(PerformanceBenchmarks.maxEdgeDetectionTime, isNotNull);
      expect(PerformanceBenchmarks.maxDocumentProcessingTime, isNotNull);
      expect(PerformanceBenchmarks.maxSinglePagePdfTime, isNotNull);
      expect(PerformanceBenchmarks.maxMultiPagePdfTime, isNotNull);
    });
    
    test('verify test data configurations are valid', () {
      expect(TestDataConfig.validRotations, containsAll([0, 90, 180, 270]));
      expect(TestDataConfig.allColorFilters, isNotEmpty);
      expect(TestDataConfig.allDocumentFormats, isNotEmpty);
      expect(TestDataConfig.allPdfResolutions, isNotEmpty);
      expect(TestDataConfig.allDocumentTypes, isNotEmpty);
    });
  });
}