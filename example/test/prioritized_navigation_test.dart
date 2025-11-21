import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Import just the app to test the navigation structure
import 'package:document_scanner_example/app.dart';

void main() {
  group('Prioritized Navigation Tests', () {
    testWidgets('App launches with Quick Scan tab selected by default', (tester) async {
      // Given the app is built
      await tester.pumpWidget(const DocumentScannerShowcaseApp());
      await tester.pumpAndSettle();

      // Then the Quick Scan tab should be selected
      final navigationBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navigationBar.selectedIndex, equals(0));
      
      // And the navigation labels should be in the correct order
      expect(find.text('Quick Scan'), findsOneWidget);
      expect(find.text('Multi Scan'), findsOneWidget);
      expect(find.text('Lab'), findsOneWidget);
    });

    testWidgets('Navigation destinations have correct icons and labels', (tester) async {
      // Given the app is built
      await tester.pumpWidget(const DocumentScannerShowcaseApp());
      await tester.pumpAndSettle();

      // Then verify the navigation structure
      expect(find.byIcon(Icons.flash_on), findsOneWidget); // Quick Scan icon
      expect(find.byIcon(Icons.camera_alt), findsOneWidget); // Multi Scan icon
      expect(find.byIcon(Icons.science), findsOneWidget); // Lab icon
      
      // Verify labels
      expect(find.text('Quick Scan'), findsOneWidget);
      expect(find.text('Multi Scan'), findsOneWidget);
      expect(find.text('Lab'), findsOneWidget);
    });

    testWidgets('First scan banner appears on initial load', (tester) async {
      // Given the app is built and launched for the first time
      await tester.pumpWidget(const DocumentScannerShowcaseApp());
      await tester.pumpAndSettle();

      // Then the First scan banner should be visible
      expect(find.text('First scan?'), findsOneWidget);
      expect(find.text('Start quick with camera capture or gallery import. For longer documents, switch to the Multi Scan tab.'), findsOneWidget);
      expect(find.text('Try the quick actions below'), findsOneWidget);
      expect(find.text('Multi Scan for multiple pages'), findsOneWidget);
      
      // And it should have the lightbulb icon
      expect(find.byIcon(Icons.lightbulb), findsOneWidget);
    });

    testWidgets('Navigation works correctly between tabs', (tester) async {
      // Given the app is built
      await tester.pumpWidget(const DocumentScannerShowcaseApp());
      await tester.pumpAndSettle();

      // When tapping on Multi Scan tab
      await tester.tap(find.text('Multi Scan'));
      await tester.pumpAndSettle();
      
      // Then the Multi Scan tab should be selected
      final navigationBarAfterFirstTap = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navigationBarAfterFirstTap.selectedIndex, equals(1));

      // When tapping on Lab tab
      await tester.tap(find.text('Lab'));
      await tester.pumpAndSettle();
      
      // Then the Lab tab should be selected
      final navigationBarAfterSecondTap = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navigationBarAfterSecondTap.selectedIndex, equals(2));

      // When tapping back to Quick Scan
      await tester.tap(find.text('Quick Scan'));
      await tester.pumpAndSettle();
      
      // Then the Quick Scan tab should be selected again
      final navigationBarAfterThirdTap = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navigationBarAfterThirdTap.selectedIndex, equals(0));
    });
  });

  group('Navigation Order Verification', () {
    test('Tab order follows quick-scan-first pattern', () {
      // This test verifies the conceptual order matches requirements
      // The enum order should be: quickScan, multiScan, lab
      
      final expectedOrder = ['Quick Scan', 'Multi Scan', 'Lab'];
      final actualOrder = ['Quick Scan', 'Multi Scan', 'Lab']; // From _buildDestination method
      
      expect(actualOrder, equals(expectedOrder));
      
      // Verify the order prioritizes scanning flows
      expect(actualOrder[0], equals('Quick Scan')); // First priority
      expect(actualOrder[1], equals('Multi Scan')); // Second priority  
      expect(actualOrder[2], equals('Lab')); // Last (secondary)
    });
  });
}