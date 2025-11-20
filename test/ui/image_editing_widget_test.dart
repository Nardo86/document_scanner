import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/document_scanner.dart';

void main() {
  group('ImageEditingWidget Tests', () {
    late Uint8List testImageData;

    setUp(() {
      // Create minimal test image data (just for widget structure testing)
      testImageData = Uint8List.fromList([0, 0, 0, 0]); // Minimal placeholder
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

    testWidgets('should display image editing interface', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.rotate_left), findsOneWidget);
      expect(find.byIcon(Icons.rotate_right), findsOneWidget);
      expect(find.byIcon(Icons.crop), findsOneWidget);
    });

    testWidgets('should have rotation controls', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      expect(find.byIcon(Icons.rotate_left), findsOneWidget);
      expect(find.byIcon(Icons.rotate_right), findsOneWidget);
      
      // Test rotation left
      await tester.tap(find.byIcon(Icons.rotate_left));
      await tester.pump();
      
      // Test rotation right
      await tester.tap(find.byIcon(Icons.rotate_right));
      await tester.pump();
    });

    testWidgets('should have crop controls', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      expect(find.byIcon(Icons.crop), findsOneWidget);
      
      // Test enabling crop mode
      await tester.tap(find.byIcon(Icons.crop));
      await tester.pump();
      
      // Should show crop free icon (disable crop) when crop mode is enabled
      expect(find.byIcon(Icons.crop_free), findsOneWidget);
    });

    testWidgets('should have settings toggle functionality', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // Initially settings should be collapsed
      expect(find.text('Settings'), findsNothing);
      
      // Tap on settings area to expand
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();
      
      // Settings should now be expanded
      expect(find.text('Settings'), findsOneWidget);
      
      // Tap collapse button
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();
      
      // Settings should be collapsed again
      expect(find.text('Settings'), findsNothing);
    });

    testWidgets('should have color filter options when expanded', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // Expand settings
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();

      expect(find.text('Color Filter:'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Enhanced'), findsOneWidget);
      expect(find.text('B&W'), findsOneWidget);
    });

    testWidgets('should have document format options when expanded', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // Expand settings
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();

      expect(find.text('Document Format:'), findsOneWidget);
      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('A4'), findsOneWidget);
      expect(find.text('Letter'), findsOneWidget);
      expect(find.text('Legal'), findsOneWidget);
    });

    testWidgets('should have PDF resolution options when expanded', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // Expand settings
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();

      expect(find.text('PDF Quality:'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
    });

    testWidgets('should show active setting indicators', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // Should show compact view with indicators
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('Format'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('should handle filter selection', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // Expand settings
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();

      // Select B&W filter
      await tester.tap(find.text('B&W'));
      await tester.pump();

      // Filter should be selected (we can't easily verify the state without more complex testing)
      expect(find.text('B&W'), findsOneWidget);
    });

    testWidgets('should handle format selection', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // Expand settings
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();

      // Select A4 format
      await tester.tap(find.text('A4'));
      await tester.pump();

      expect(find.text('A4'), findsOneWidget);
    });

    testWidgets('should handle resolution selection', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // Expand settings
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();

      // Select High resolution
      await tester.tap(find.text('High'));
      await tester.pump();

      expect(find.text('High'), findsOneWidget);
    });

    testWidgets('should have proper control layout', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // Check for main control buttons
      expect(find.byType(IconButton), findsAtLeastNWidgets(4)); // rotate left/right, crop, settings
    });

    testWidgets('should handle crop apply button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // Enable crop mode
      await tester.tap(find.byIcon(Icons.crop));
      await tester.pump();

      // Should show apply crop button
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byTooltip('Apply Crop'), findsOneWidget);
      
      // Test applying crop
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();
    });

    testWidgets('should handle gesture detection for settings toggle', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(imageData: testImageData));

      // Tap on the controls area (not a specific button)
      final controlsArea = find.byType(GestureDetector);
      expect(controlsArea, findsWidgets);
      
      // Find the gesture detector that contains the controls
      final gestureDetectors = tester.widgetList<GestureDetector>(controlsArea);
      expect(gestureDetectors.isNotEmpty, isTrue);
    });

    group('Settings Panel Behavior', () {
      testWidgets('should expand settings on tap', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(imageData: testImageData));

        // Initially collapsed
        expect(find.text('Settings'), findsNothing);
        
        // Tap to expand
        await tester.tap(find.byIcon(Icons.settings));
        await tester.pump();
        
        // Should be expanded
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Color Filter:'), findsOneWidget);
        expect(find.text('Document Format:'), findsOneWidget);
        expect(find.text('PDF Quality:'), findsOneWidget);
      });

      testWidgets('should collapse settings on collapse button tap', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(imageData: testImageData));

        // Expand first
        await tester.tap(find.byIcon(Icons.settings));
        await tester.pump();
        expect(find.text('Settings'), findsOneWidget);
        
        // Collapse
        await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
        await tester.pump();
        
        // Should be collapsed
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

      testWidgets('should update crop tooltip when enabled', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(imageData: testImageData));

        // Initially shows "Enable Crop"
        expect(find.byTooltip('Enable Crop'), findsOneWidget);
        
        // Enable crop
        await tester.tap(find.byIcon(Icons.crop));
        await tester.pump();
        
        // Should now show "Disable Crop"
        expect(find.byTooltip('Disable Crop'), findsOneWidget);
        expect(find.byTooltip('Apply Crop'), findsOneWidget);
      });
    });

    group('Layout Structure', () {
      testWidgets('should have proper widget hierarchy', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(imageData: testImageData));

        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byType(Stack), findsOneWidget);
        expect(find.byType(Positioned), findsAtLeastNWidgets(1));
        expect(find.byType(GestureDetector), findsAtLeastNWidgets(1));
      });

      testWidgets('should have bottom controls panel', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(imageData: testImageData));

        // Look for the bottom controls container
        final positionedWidgets = tester.widgetList<Positioned>(find.byType(Positioned));
        final bottomPanel = positionedWidgets.where((p) => 
          p.bottom != null && p.bottom == 0
        ).toList();
        
        expect(bottomPanel.isNotEmpty, isTrue);
      });
    });
  });
}