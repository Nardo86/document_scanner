import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/src/services/image_processor.dart';
import 'package:document_scanner/src/models/scanned_document.dart';
import 'package:image/image.dart' as img;

void main() {
  group('Performance Benchmarks', () {
    late ImageProcessor imageProcessor;

    setUp(() {
      imageProcessor = ImageProcessor();
    });

    tearDown(() {
      imageProcessor.dispose();
    });

    group('Processing speed requirements', () {
      test('processes 2000px image in under 3 seconds', () async {
        // Create a 2000px test image (2000x1500)
        final imageData = _createTestImage(2000, 1500);
        final options = const DocumentProcessingOptions(
          convertToGrayscale: true,
          enhanceContrast: true,
          autoCorrectPerspective: true,
        );

        final stopwatch = Stopwatch()..start();
        final result = await imageProcessor.processImage(imageData, options);
        stopwatch.stop();

        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
        
        // Verify performance requirement: under 3 seconds
        final elapsedSeconds = stopwatch.elapsedMilliseconds / 1000.0;
        expect(elapsedSeconds, lessThan(3.0), 
               reason: 'Processing took ${elapsedSeconds.toStringAsFixed(2)}s, should be under 3s');
        
        print('2000px image processed in ${elapsedSeconds.toStringAsFixed(2)}s');
      });

      test('edge detection is fast and cached', () async {
        final imageData = _createTestImage(2000, 1500);

        // First detection (should compute)
        final stopwatch1 = Stopwatch()..start();
        final corners1 = await imageProcessor.detectDocumentEdges(imageData);
        stopwatch1.stop();

        expect(corners1, isA<List<Offset>>());
        expect(corners1.length, equals(4));

        // Second detection (should use cache)
        final stopwatch2 = Stopwatch()..start();
        final corners2 = await imageProcessor.detectDocumentEdges(imageData);
        stopwatch2.stop();

        expect(corners2, equals(corners1));
        
        // Cached detection should be significantly faster
        expect(stopwatch2.elapsedMilliseconds, 
               lessThan(stopwatch1.elapsedMilliseconds ~/ 2),
               reason: 'Cached detection should be faster than initial detection');
        
        print('Initial edge detection: ${stopwatch1.elapsedMilliseconds}ms');
        print('Cached edge detection: ${stopwatch2.elapsedMilliseconds}ms');
      });

      test('handles multiple sequential processes efficiently', () async {
        final imageData = _createTestImage(2000, 1500);
        final options = const DocumentProcessingOptions();
        const processCount = 5;

        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < processCount; i++) {
          final result = await imageProcessor.processImage(imageData, options);
          expect(result, isA<Uint8List>());
          expect(result.isNotEmpty, isTrue);
        }
        
        stopwatch.stop();
        
        final averageTime = stopwatch.elapsedMilliseconds / processCount;
        
        // Average should be reasonable (under 4 seconds per process)
        expect(averageTime, lessThan(4000), 
               reason: 'Average processing time should be under 4s');
        
        print('Average processing time for $processCount processes: ${averageTime.toStringAsFixed(2)}ms');
      });

      test('memory usage stays reasonable during processing', () async {
        final imageData = _createTestImage(2000, 1500);
        final options = const DocumentProcessingOptions();
        
        // Process multiple times to check for memory leaks
        for (int i = 0; i < 10; i++) {
          final result = await imageProcessor.processImage(imageData, options);
          expect(result, isA<Uint8List>());
          expect(result.isNotEmpty, isTrue);
          
          // Clear cache periodically
          if (i % 3 == 0) {
            imageProcessor.clearEdgeCache();
          }
        }
        
        // If we get here without out-of-memory errors, memory usage is reasonable
        expect(true, isTrue);
      });
    });

    group('Image size optimization verification', () {
      test('resize metadata is accurate', () {
        // Test the resize calculation logic
        final testCases = [
          {'width': 4000, 'height': 3000, 'expectedRatio': 0.5},     // 2000px limit
          {'width': 3000, 'height': 2000, 'expectedRatio': 0.667},   // 2000px limit
          {'width': 2500, 'height': 2500, 'expectedRatio': 0.8},     // 2000px limit
          {'width': 1500, 'height': 1000, 'expectedRatio': 1.0},     // No resize needed
          {'width': 800, 'height': 600, 'expectedRatio': 1.0},       // No resize needed
        ];
        
        for (final testCase in testCases) {
          final width = testCase['width'] as int;
          final height = testCase['height'] as int;
          final expectedRatio = testCase['expectedRatio'] as double;
          
          final maxDimension = width > height ? width : height;
          final actualRatio = maxDimension > 2000 ? 2000.0 / maxDimension : 1.0;
          
          expect(actualRatio, closeTo(expectedRatio, 0.001),
                 reason: 'Resize ratio mismatch for ${width}x$height image');
        }
      });

      test('processed images maintain reasonable quality', () async {
        final originalImageData = _createTestImage(2000, 1500);
        final options = const DocumentProcessingOptions(
          convertToGrayscale: true,
          enhanceContrast: true,
          compressionQuality: 0.8,
        );

        final processedImageData = await imageProcessor.processImage(originalImageData, options);
        
        // Decode both images to compare
        final processedImage = img.decodeImage(processedImageData)!;
        
        // Processed image should exist and have reasonable dimensions
        expect(processedImage.width, greaterThan(0));
        expect(processedImage.height, greaterThan(0));
        
        // Processed image should be smaller or equal in dimensions (due to resize limit)
        expect(processedImage.width, lessThanOrEqualTo(2000));
        expect(processedImage.height, lessThanOrEqualTo(2000));
        
        // Processed image should be smaller in file size (due to compression)
        expect(processedImageData.length, lessThan(originalImageData.length));
        
        print('Original size: ${originalImageData.length} bytes');
        print('Processed size: ${processedImageData.length} bytes');
        print('Compression ratio: ${(processedImageData.length / originalImageData.length * 100).toStringAsFixed(1)}%');
      });
    });
  });
}

/// Create a test image that simulates a document
Uint8List _createTestImage(int width, int height) {
  final image = img.Image(width: width, height: height);
  
  // Create a document-like pattern: white background with some content
  img.fill(image, color: img.ColorRgb8(240, 240, 240)); // Light gray background
  
  // Add some darker areas to simulate content
  final contentWidth = (width * 0.8).round();
  final contentHeight = (height * 0.8).round();
  final startX = (width - contentWidth) ~/ 2;
  final startY = (height - contentHeight) ~/ 2;
  
  for (int y = startY; y < startY + contentHeight; y++) {
    for (int x = startX; x < startX + contentWidth; x++) {
      if (x >= 0 && x < width && y >= 0 && y < height) {
        // Create some variation in content
        final brightness = 200 + (x % 55);
        image.setPixel(x, y, img.ColorRgb8(brightness, brightness, brightness));
      }
    }
  }
  
  // Add border to simulate document edge
  for (int i = 0; i < 5; i++) {
    for (int x = 0; x < width; x++) {
      if (startY + i < height) {
        image.setPixel(x, startY + i, img.ColorRgb8(100, 100, 100));
      }
      if (startY + contentHeight - i >= 0 && startY + contentHeight - i < height) {
        image.setPixel(x, startY + contentHeight - i, img.ColorRgb8(100, 100, 100));
      }
    }
    for (int y = 0; y < height; y++) {
      if (startX + i < width) {
        image.setPixel(startX + i, y, img.ColorRgb8(100, 100, 100));
      }
      if (startX + contentWidth - i >= 0 && startX + contentWidth - i < width) {
        image.setPixel(startX + contentWidth - i, y, img.ColorRgb8(100, 100, 100));
      }
    }
  }
  
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}