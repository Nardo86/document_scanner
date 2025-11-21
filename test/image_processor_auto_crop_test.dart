import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/src/services/auto_cropper.dart';

void main() {
  group('AutoCropper Tests', () {
    late AutoCropper autoCropper;

    setUp(() {
      autoCropper = AutoCropper();
    });

    test('should handle empty image data gracefully', () async {
      final emptyData = Uint8List(0);
      
      final result = await autoCropper.autoCrop(emptyData);
      
      expect(result.fallbackUsed, isTrue);
      expect(result.confidence, lessThan(0.3));
      expect(result.corners.length, 4);
      expect(result.croppedImageData, isNotEmpty);
    });

    test('should return fallback result for invalid image data', () async {
      final invalidData = Uint8List.fromList([0xFF, 0xD8, 0xFF]); // Invalid JPEG header
      
      final result = await autoCropper.autoCrop(invalidData);
      
      expect(result.fallbackUsed, isTrue);
      expect(result.confidence, lessThan(0.3));
      expect(result.durationMs, lessThan(100));
      expect(result.corners.length, 4);
      expect(result.croppedImageData, isNotEmpty);
    });

    test('should include comprehensive metadata for fallback case', () async {
      final invalidData = Uint8List.fromList([0xFF, 0xD8, 0xFF]); // Invalid JPEG header
      
      final result = await autoCropper.autoCrop(invalidData);
      
      expect(result.metadata.containsKey('originalWidth'), isTrue);
      expect(result.metadata.containsKey('originalHeight'), isTrue);
      expect(result.metadata.containsKey('detectionTimeMs'), isTrue);
      expect(result.metadata.containsKey('detectionMethod'), isTrue);
      expect(result.metadata.containsKey('fallbackReason'), isTrue);
    });

    test('should use bounding box fallback when confidence is low', () async {
      final invalidData = Uint8List.fromList([0xFF, 0xD8, 0xFF]); // Invalid JPEG header
      
      final result = await autoCropper.autoCrop(invalidData);
      
      expect(result.fallbackUsed, isTrue);
      expect(result.confidence, lessThan(0.3));
      expect(result.metadata['fallbackReason'], isNotNull);
    });

    test('should handle timeout gracefully', () async {
      // Create invalid data that will trigger fallback
      final invalidData = Uint8List.fromList([0xFF, 0xD8, 0xFF]); // Invalid JPEG header
      
      final result = await autoCropper.autoCrop(invalidData);
      
      expect(result.durationMs, lessThanOrEqualTo(100));
      expect(result.fallbackUsed, isTrue);
      expect(result.metadata['fallbackReason'], contains('error'));
    });

    test('should produce consistent results for same input', () async {
      final invalidData = Uint8List.fromList([0xFF, 0xD8, 0xFF]); // Invalid JPEG header
      
      final result1 = await autoCropper.autoCrop(invalidData);
      final result2 = await autoCropper.autoCrop(invalidData);
      
      expect(result1.corners, equals(result2.corners));
      expect(result1.confidence, closeTo(result2.confidence, 0.01));
      expect(result1.fallbackUsed, equals(result2.fallbackUsed));
    });

    test('should return ordered corners in fallback case', () async {
      final invalidData = Uint8List.fromList([0xFF, 0xD8, 0xFF]); // Invalid JPEG header
      
      final result = await autoCropper.autoCrop(invalidData);
      
      expect(result.corners.length, 4);
      
      // Verify corners are ordered clockwise starting from top-left
      final corners = result.corners;
      final topLeft = corners[0];
      final topRight = corners[1];
      final bottomRight = corners[2];
      final bottomLeft = corners[3];
      
      // Should be default bounding box corners
      expect(topLeft.dx, equals(0.0));
      expect(topLeft.dy, equals(0.0));
      expect(topRight.dx, greaterThan(0.0));
      expect(topRight.dy, equals(0.0));
      expect(bottomRight.dx, greaterThan(0.0));
      expect(bottomRight.dy, greaterThan(0.0));
      expect(bottomLeft.dx, equals(0.0));
      expect(bottomLeft.dy, greaterThan(0.0));
    });

    test('should report processing duration', () async {
      final invalidData = Uint8List.fromList([0xFF, 0xD8, 0xFF]); // Invalid JPEG header
      
      final stopwatch = Stopwatch()..start();
      final result = await autoCropper.autoCrop(invalidData);
      stopwatch.stop();
      
      expect(result.durationMs, greaterThan(0));
      expect(result.durationMs, lessThan(100));
      expect(result.metadata.containsKey('detectionTimeMs'), isTrue);
    });
  });
}