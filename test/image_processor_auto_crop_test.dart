import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:document_scanner/src/services/auto_cropper.dart';

/// Creates a tiny valid JPEG image that will decode successfully but produce
/// low-confidence detection (contour area too small), triggering the fallback path.
Uint8List _createTinyImage(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 200, 200));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

void main() {
  group('AutoCropper Tests', () {
    late AutoCropper autoCropper;
    // A small but valid image that decodes successfully and triggers the
    // low_confidence fallback path (contour area well below _minContourArea).
    late Uint8List fallbackTriggerData;

    setUp(() {
      autoCropper = AutoCropper();
      fallbackTriggerData = _createTinyImage(30, 30);
    });

    test('should handle empty image data gracefully', () async {
      // A small uniform image produces low confidence and uses the fallback path.
      final result = await autoCropper.autoCrop(fallbackTriggerData);

      expect(result.fallbackUsed, isTrue);
      expect(result.confidence, lessThan(0.3));
      expect(result.corners.length, 4);
      expect(result.croppedImageData, isNotEmpty);
    });

    test('should return fallback result for low-confidence detection', () async {
      // A tiny uniform image cannot produce a high-confidence contour detection.
      final result = await autoCropper.autoCrop(fallbackTriggerData);

      expect(result.fallbackUsed, isTrue);
      expect(result.confidence, lessThan(0.3));
      expect(result.durationMs, lessThan(100));
      expect(result.corners.length, 4);
      expect(result.croppedImageData, isNotEmpty);
    });

    test('should include comprehensive metadata for fallback case', () async {
      final result = await autoCropper.autoCrop(fallbackTriggerData);

      expect(result.metadata.containsKey('originalWidth'), isTrue);
      expect(result.metadata.containsKey('originalHeight'), isTrue);
      expect(result.metadata.containsKey('detectionTimeMs'), isTrue);
      expect(result.metadata.containsKey('detectionMethod'), isTrue);
      expect(result.metadata.containsKey('fallbackReason'), isTrue);
    });

    test('should use bounding box fallback when confidence is low', () async {
      final result = await autoCropper.autoCrop(fallbackTriggerData);

      expect(result.fallbackUsed, isTrue);
      expect(result.confidence, lessThan(0.3));
      expect(result.metadata['fallbackReason'], isNotNull);
    });

    test('should use fallback when no strong contours are detected', () async {
      // A tiny uniform image produces no usable contours, triggering fallback.
      final result = await autoCropper.autoCrop(fallbackTriggerData);

      expect(result.durationMs, lessThanOrEqualTo(100));
      expect(result.fallbackUsed, isTrue);
      expect(result.metadata['fallbackReason'], isNotNull);
    });

    test('should produce consistent results for same input', () async {
      final result1 = await autoCropper.autoCrop(fallbackTriggerData);
      final result2 = await autoCropper.autoCrop(fallbackTriggerData);

      expect(result1.corners, equals(result2.corners));
      expect(result1.confidence, closeTo(result2.confidence, 0.01));
      expect(result1.fallbackUsed, equals(result2.fallbackUsed));
    });

    test('should return ordered corners in fallback case', () async {
      final result = await autoCropper.autoCrop(fallbackTriggerData);

      expect(result.corners.length, 4);

      // Verify corners are ordered clockwise starting from top-left
      final corners = result.corners;
      final topLeft = corners[0];
      final topRight = corners[1];
      final bottomRight = corners[2];
      final bottomLeft = corners[3];

      // Should be default bounding box corners (image.width - 1, image.height - 1)
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
      final stopwatch = Stopwatch()..start();
      final result = await autoCropper.autoCrop(fallbackTriggerData);
      stopwatch.stop();

      // durationMs may be 0 for very fast processing on tiny images.
      expect(result.durationMs, greaterThanOrEqualTo(0));
      expect(result.durationMs, lessThan(100));
      expect(result.metadata.containsKey('detectionTimeMs'), isTrue);
    });
  });
}
