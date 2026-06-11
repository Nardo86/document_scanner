import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:document_scanner/src/services/auto_cropper.dart';

/// A dark background with a bright rectangular "sheet" — the case issue #30
/// targets. Returns the encoded JPEG plus the sheet rectangle bounds.
({Uint8List bytes, double left, double top, double right, double bottom})
_sheetOnDarkBackground() {
  const w = 400, h = 400;
  const left = 80, top = 60, right = 320, bottom = 340;
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(18, 18, 18));
  img.fillRect(
    image,
    x1: left,
    y1: top,
    x2: right - 1,
    y2: bottom - 1,
    color: img.ColorRgb8(244, 244, 244),
  );
  return (
    bytes: Uint8List.fromList(img.encodeJpg(image, quality: 95)),
    left: left.toDouble(),
    top: top.toDouble(),
    right: (right - 1).toDouble(),
    bottom: (bottom - 1).toDouble(),
  );
}

void main() {
  group('AutoCropper - real detection (issue #30)', () {
    test(
      'detects a bright sheet on a dark background with high confidence',
      () async {
        final fixture = _sheetOnDarkBackground();
        final result = await AutoCropper().autoCrop(fixture.bytes);

        expect(
          result.fallbackUsed,
          isFalse,
          reason: 'a clear sheet should not fall back',
        );
        expect(result.confidence, greaterThanOrEqualTo(0.5));
        expect(result.corners.length, 4);
        expect(result.croppedImageData, isNotEmpty);
        expect(result.metadata['detectionMethod'], 'otsu_white_blob');
      },
    );

    test('detected corners are close to the sheet rectangle', () async {
      final fixture = _sheetOnDarkBackground();
      final result = AutoCropper().detectCorners(fixture.bytes);

      expect(result, isNotNull);
      final corners = result!.corners; // TL, TR, BR, BL
      const tol = 12.0;
      expect(corners[0].dx, closeTo(fixture.left, tol));
      expect(corners[0].dy, closeTo(fixture.top, tol));
      expect(corners[1].dx, closeTo(fixture.right, tol));
      expect(corners[1].dy, closeTo(fixture.top, tol));
      expect(corners[2].dx, closeTo(fixture.right, tol));
      expect(corners[2].dy, closeTo(fixture.bottom, tol));
      expect(corners[3].dx, closeTo(fixture.left, tol));
      expect(corners[3].dy, closeTo(fixture.bottom, tol));
    });

    test('uniform image falls back (no document)', () async {
      final image = img.Image(width: 60, height: 60);
      img.fill(image, color: img.ColorRgb8(200, 200, 200));
      final bytes = Uint8List.fromList(img.encodeJpg(image, quality: 90));

      final result = await AutoCropper().autoCrop(bytes);
      expect(result.fallbackUsed, isTrue);
      expect(result.confidence, lessThan(0.5));
      // Fallback returns the original bytes unchanged.
      expect(result.croppedImageData, equals(bytes));
      expect(result.corners.length, 4);
    });

    test('detectCorners returns null for a uniform image', () {
      final image = img.Image(width: 60, height: 60);
      img.fill(image, color: img.ColorRgb8(128, 128, 128));
      final bytes = Uint8List.fromList(img.encodeJpg(image, quality: 90));
      expect(AutoCropper().detectCorners(bytes), isNull);
    });
  });
}
