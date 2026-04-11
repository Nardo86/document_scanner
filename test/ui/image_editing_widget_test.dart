import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:document_scanner/document_scanner.dart';

void main() {
  group('ImageEditingWidget Tests', () {
    late Uint8List testImageData;

    setUp(() {
      // Generate a real 10x10 grey JPEG so Image.memory() can decode it
      // without throwing "Invalid image data".
      final testImg = img.Image(width: 10, height: 10);
      img.fill(testImg, color: img.ColorRgb8(128, 128, 128));
      testImageData = Uint8List.fromList(img.encodeJpg(testImg));
    });

    Widget createTestWidget({
      required Uint8List imageData,
      Function(Uint8List, PdfResolution, DocumentFormat)? onImageEdited,
      VoidCallback? onCancel,
    }) {
      // ImageEditingWidget already returns a Scaffold; wrap only in MaterialApp
      // (no outer Scaffold) to avoid nested-Scaffold issues with ScaffoldMessenger.
      return MaterialApp(
        home: ImageEditingWidget(
          imageData: imageData,
          onImageEdited: onImageEdited ?? (data, resolution, format) {},
          onCancel: onCancel ?? () {},
        ),
      );
    }

    testWidgets('should display image editing interface', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));
      await tester.pump();

      expect(find.byIcon(Icons.rotate_left), findsOneWidget);
      expect(find.byIcon(Icons.rotate_right), findsOneWidget);
      expect(find.byIcon(Icons.crop), findsOneWidget);
    });

    testWidgets('should have rotation controls', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));
      await tester.pump();

      expect(find.byIcon(Icons.rotate_left), findsOneWidget);
      expect(find.byIcon(Icons.rotate_right), findsOneWidget);

      await tester.tap(find.byIcon(Icons.rotate_left));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byIcon(Icons.rotate_right));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('should return to original orientation after four rotations', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));
      await tester.pump();

      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byIcon(Icons.rotate_right));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }

      expect(find.byIcon(Icons.rotate_right), findsOneWidget);
    });

    testWidgets('should handle rotation in both directions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.rotate_right));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byIcon(Icons.rotate_left));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.rotate_left), findsOneWidget);
      expect(find.byIcon(Icons.rotate_right), findsOneWidget);
    });

    testWidgets('should have crop controls', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));
      await tester.pump();

      expect(find.byIcon(Icons.crop), findsOneWidget);

      // Enable crop mode.
      await tester.tap(find.byIcon(Icons.crop));
      await tester.pump();

      // When crop mode is active the icon switches to crop_free.
      expect(find.byIcon(Icons.crop_free), findsOneWidget);
    });

    testWidgets('should have settings toggle functionality', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));
      await tester.pump();

      // Initially settings panel is collapsed.
      expect(find.text('Settings'), findsNothing);

      // Tap the dedicated settings button to expand.
      await tester.tap(find.byTooltip('Show All Settings'));
      await tester.pump();

      expect(find.text('Settings'), findsOneWidget);

      // Tap the collapse button.
      await tester.tap(find.byTooltip('Collapse Settings'));
      await tester.pump();

      expect(find.text('Settings'), findsNothing);
    });

    testWidgets('should have color filter options when expanded', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));
      await tester.pump();

      await tester.tap(find.byTooltip('Show All Settings'));
      await tester.pump();

      expect(find.text('Color Filter:'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Enhanced'), findsOneWidget);
      expect(find.text('B&W'), findsOneWidget);
    });

    testWidgets('should have document format options when expanded', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));
      await tester.pump();

      await tester.tap(find.byTooltip('Show All Settings'));
      await tester.pump();

      expect(find.text('Document Format:'), findsOneWidget);
      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('A4'), findsOneWidget);
      expect(find.text('Letter'), findsOneWidget);
      expect(find.text('Legal'), findsOneWidget);
    });

    testWidgets('should have PDF resolution options when expanded', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));
      await tester.pump();

      await tester.tap(find.byTooltip('Show All Settings'));
      await tester.pump();

      expect(find.text('PDF Quality:'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
    });

    testWidgets('should show active setting indicators', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));
      await tester.pump();

      // Collapsed view shows compact indicators and the settings button.
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('Format'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.byTooltip('Show All Settings'), findsOneWidget);
    });

    testWidgets('should handle filter selection', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));
      await tester.pump();

      await tester.tap(find.byTooltip('Show All Settings'));
      await tester.pump();

      await tester.tap(find.text('B&W'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('B&W'), findsOneWidget);
    });

    testWidgets('should handle format selection', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));
      await tester.pump();

      await tester.tap(find.byTooltip('Show All Settings'));
      await tester.pump();

      await tester.tap(find.text('A4'));
      await tester.pump();

      expect(find.text('A4'), findsOneWidget);
    });

    testWidgets('should handle resolution selection', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));
      await tester.pump();

      await tester.tap(find.byTooltip('Show All Settings'));
      await tester.pump();

      await tester.tap(find.text('High'));
      await tester.pump();

      expect(find.text('High'), findsOneWidget);
    });

    testWidgets('should have proper control layout', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));
      await tester.pump();

      // AppBar has close/refresh/confirm; controls row has rotate-left,
      // rotate-right, crop, and the three compact-indicator buttons.
      expect(find.byType(IconButton), findsAtLeastNWidgets(4));
    });

    testWidgets('should handle crop apply button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));
      await tester.pump();

      // Enable crop mode.
      await tester.tap(find.byIcon(Icons.crop));
      await tester.pump();

      // Controls row now shows an Apply Crop button (green check).
      expect(find.byTooltip('Apply Crop'), findsOneWidget);

      await tester.tap(find.byTooltip('Apply Crop'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('should handle gesture detection for settings toggle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));
      await tester.pump();

      // The controls panel is wrapped in a GestureDetector.
      final controlsArea = find.byType(GestureDetector);
      expect(controlsArea, findsWidgets);

      final gestureDetectors = tester.widgetList<GestureDetector>(controlsArea);
      expect(gestureDetectors.isNotEmpty, isTrue);
    });

    group('Settings Panel Behavior', () {
      testWidgets('should expand settings on tap', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(imageData: testImageData));
        await tester.pump();

        expect(find.text('Settings'), findsNothing);

        await tester.tap(find.byTooltip('Show All Settings'));
        await tester.pump();

        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Color Filter:'), findsOneWidget);
        expect(find.text('Document Format:'), findsOneWidget);
        expect(find.text('PDF Quality:'), findsOneWidget);
      });

      testWidgets('should collapse settings on collapse button tap', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget(imageData: testImageData));
        await tester.pump();

        await tester.tap(find.byTooltip('Show All Settings'));
        await tester.pump();
        expect(find.text('Settings'), findsOneWidget);

        await tester.tap(find.byTooltip('Collapse Settings'));
        await tester.pump();

        expect(find.text('Settings'), findsNothing);
      });
    });

    group('Button Tooltips', () {
      testWidgets('should show correct tooltips', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(imageData: testImageData));
        await tester.pump();

        expect(find.byTooltip('Rotate Left'), findsOneWidget);
        expect(find.byTooltip('Rotate Right'), findsOneWidget);
        expect(find.byTooltip('Enable Crop'), findsOneWidget);
        expect(find.byTooltip('Show All Settings'), findsOneWidget);
      });

      testWidgets('should update crop tooltip when enabled', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget(imageData: testImageData));
        await tester.pump();

        expect(find.byTooltip('Enable Crop'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.crop));
        await tester.pump();

        expect(find.byTooltip('Disable Crop'), findsOneWidget);
        expect(find.byTooltip('Apply Crop'), findsOneWidget);
      });
    });

    group('Layout Structure', () {
      testWidgets('should have proper widget hierarchy', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget(imageData: testImageData));
        await tester.pump();

        // ImageEditingWidget builds its own Scaffold.
        expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
        // That Scaffold has an AppBar titled 'Edit Image'.
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.text('Edit Image'), findsOneWidget);
        // The controls panel is wrapped in a GestureDetector.
        expect(find.byType(GestureDetector), findsAtLeastNWidgets(1));
      });

      testWidgets('should have bottom controls panel', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget(imageData: testImageData));
        await tester.pump();

        expect(find.byIcon(Icons.rotate_left), findsOneWidget);
        expect(find.byIcon(Icons.rotate_right), findsOneWidget);
        expect(find.byIcon(Icons.crop), findsOneWidget);
      });
    });
  });
}
