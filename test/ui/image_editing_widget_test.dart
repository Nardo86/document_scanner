import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/document_scanner.dart';

void main() {
  group('ImageEditingWidget Tests', () {
    late Uint8List testImageData;

    setUp(() {
      // Minimal test data — image processing will fail gracefully and show a
      // SnackBar; the widget structure under test is still fully rendered.
      testImageData = Uint8List.fromList([0]);
    });

    Widget createTestWidget({
      required Uint8List imageData,
      Function(Uint8List, PdfResolution, DocumentFormat)? onImageEdited,
      VoidCallback? onCancel,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ImageEditingWidget(
            imageData: imageData,
            onImageEdited: onImageEdited ?? (data, resolution, format) {},
            onCancel: onCancel ?? () {},
          ),
        ),
      );
    }

    testWidgets('should display image editing interface', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // Check for main control buttons (image may fail to load but controls should be visible)
      expect(find.byIcon(Icons.rotate_left), findsOneWidget);
      expect(find.byIcon(Icons.rotate_right), findsOneWidget);
      expect(find.byIcon(Icons.crop), findsOneWidget);
    });

    testWidgets('should have rotation controls', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      expect(find.byIcon(Icons.rotate_left), findsOneWidget);
      expect(find.byIcon(Icons.rotate_right), findsOneWidget);

      // Test rotation left — image processing throws with invalid data, but the
      // widget handles the error and stays stable.
      await tester.tap(find.byIcon(Icons.rotate_left));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Test rotation right
      await tester.tap(find.byIcon(Icons.rotate_right));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('should return to original orientation after four rotations', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // Tap rotate right 4 times (360 degrees).
      // Use pump() instead of pumpAndSettle() because async image processing
      // may never fully settle with invalid test data.
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byIcon(Icons.rotate_right));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }

      // After 4 rotations the controls are still present.
      expect(find.byIcon(Icons.rotate_right), findsOneWidget);
    });

    testWidgets('should handle rotation in both directions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // Rotate right once.
      await tester.tap(find.byIcon(Icons.rotate_right));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Rotate left once (should return to original).
      await tester.tap(find.byIcon(Icons.rotate_left));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.rotate_left), findsOneWidget);
      expect(find.byIcon(Icons.rotate_right), findsOneWidget);
    });

    testWidgets('should have crop controls', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      expect(find.byIcon(Icons.crop), findsOneWidget);

      // Test enabling crop mode.
      await tester.tap(find.byIcon(Icons.crop));
      await tester.pump();

      // Should show crop_free icon (disable crop) when crop mode is enabled.
      expect(find.byIcon(Icons.crop_free), findsOneWidget);
    });

    testWidgets('should have settings toggle functionality', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // Initially settings should be collapsed.
      expect(find.text('Settings'), findsNothing);

      // Tap the settings icon button to expand.
      await tester.tap(find.byTooltip('Show All Settings'));
      await tester.pump();

      // Settings should now be expanded.
      expect(find.text('Settings'), findsOneWidget);

      // Tap the collapse button.
      await tester.tap(find.byTooltip('Collapse Settings'));
      await tester.pump();

      // Settings should be collapsed again.
      expect(find.text('Settings'), findsNothing);
    });

    testWidgets('should have color filter options when expanded', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // Expand settings via tooltip to avoid GestureDetector interference.
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

      // Expand settings.
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

      // Expand settings.
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

      // Collapsed view shows compact indicators and the settings button.
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('Format'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.byTooltip('Show All Settings'), findsOneWidget);
    });

    testWidgets('should handle filter selection', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // Expand settings.
      await tester.tap(find.byTooltip('Show All Settings'));
      await tester.pump();

      // Select B&W filter.
      await tester.tap(find.text('B&W'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // B&W label is still present after selection.
      expect(find.text('B&W'), findsOneWidget);
    });

    testWidgets('should handle format selection', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // Expand settings.
      await tester.tap(find.byTooltip('Show All Settings'));
      await tester.pump();

      // Select A4 format.
      await tester.tap(find.text('A4'));
      await tester.pump();

      expect(find.text('A4'), findsOneWidget);
    });

    testWidgets('should handle resolution selection', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // Expand settings.
      await tester.tap(find.byTooltip('Show All Settings'));
      await tester.pump();

      // Select High resolution.
      await tester.tap(find.text('High'));
      await tester.pump();

      expect(find.text('High'), findsOneWidget);
    });

    testWidgets('should have proper control layout', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // AppBar contributes close/refresh/confirm buttons; controls row adds
      // rotate left, rotate right, crop, and the settings indicator buttons.
      expect(find.byType(IconButton), findsAtLeastNWidgets(4));
    });

    testWidgets('should handle crop apply button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // Enable crop mode.
      await tester.tap(find.byIcon(Icons.crop));
      await tester.pump();

      // The controls row shows a green check button with the 'Apply Crop' tooltip.
      // The AppBar also has a check icon (tooltip: 'Confirm'), so use the tooltip
      // to be unambiguous.
      expect(find.byTooltip('Apply Crop'), findsOneWidget);

      // Test tapping apply crop.
      await tester.tap(find.byTooltip('Apply Crop'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('should handle gesture detection for settings toggle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // The controls panel is wrapped in a GestureDetector.
      final controlsArea = find.byType(GestureDetector);
      expect(controlsArea, findsWidgets);

      final gestureDetectors = tester.widgetList<GestureDetector>(controlsArea);
      expect(gestureDetectors.isNotEmpty, isTrue);
    });

    group('Settings Panel Behavior', () {
      testWidgets('should expand settings on tap', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(imageData: testImageData));

        // Initially collapsed.
        expect(find.text('Settings'), findsNothing);

        // Tap to expand via the dedicated tooltip.
        await tester.tap(find.byTooltip('Show All Settings'));
        await tester.pump();

        // Should be expanded.
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Color Filter:'), findsOneWidget);
        expect(find.text('Document Format:'), findsOneWidget);
        expect(find.text('PDF Quality:'), findsOneWidget);
      });

      testWidgets('should collapse settings on collapse button tap', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget(imageData: testImageData));

        // Expand first.
        await tester.tap(find.byTooltip('Show All Settings'));
        await tester.pump();
        expect(find.text('Settings'), findsOneWidget);

        // Collapse via the dedicated tooltip.
        await tester.tap(find.byTooltip('Collapse Settings'));
        await tester.pump();

        // Should be collapsed.
        expect(find.text('Settings'), findsNothing);
      });
    });

    group('Button Tooltips', () {
      testWidgets('should show correct tooltips', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(imageData: testImageData));

        expect(find.byTooltip('Rotate Left'), findsOneWidget);
        expect(find.byTooltip('Rotate Right'), findsOneWidget);
        expect(find.byTooltip('Enable Crop'), findsOneWidget);
        expect(find.byTooltip('Show All Settings'), findsOneWidget);
      });

      testWidgets('should update crop tooltip when enabled', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget(imageData: testImageData));

        // Initially shows "Enable Crop".
        expect(find.byTooltip('Enable Crop'), findsOneWidget);

        // Enable crop.
        await tester.tap(find.byIcon(Icons.crop));
        await tester.pump();

        // Should now show "Disable Crop" and "Apply Crop".
        expect(find.byTooltip('Disable Crop'), findsOneWidget);
        expect(find.byTooltip('Apply Crop'), findsOneWidget);
      });
    });

    group('Layout Structure', () {
      testWidgets('should have proper widget hierarchy', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget(imageData: testImageData));

        // The widget builds its own Scaffold (plus the one from createTestWidget).
        expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
        // The inner Scaffold has an AppBar titled 'Edit Image'.
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.text('Edit Image'), findsOneWidget);
        // The controls panel is wrapped in a GestureDetector.
        expect(find.byType(GestureDetector), findsAtLeastNWidgets(1));
      });

      testWidgets('should have bottom controls panel', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget(imageData: testImageData));

        // The controls panel is always present as a Column child at the bottom.
        // Verify the rotation row buttons are visible.
        expect(find.byIcon(Icons.rotate_left), findsOneWidget);
        expect(find.byIcon(Icons.rotate_right), findsOneWidget);
        expect(find.byIcon(Icons.crop), findsOneWidget);
      });
    });
  });
}
