import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:document_scanner_example/app.dart';

void main() {
  testWidgets('Document scanner showcase home renders key flows', (
    tester,
  ) async {
    await tester.pumpWidget(const DocumentScannerShowcaseApp());
    await tester.pumpAndSettle();

    // Check that the app builds and shows default (Quick Scan) content
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Single Page Capture'), findsOneWidget);

    // Multi-Page and Capabilities Lab are not visible by default (different tabs)
    expect(find.text('Multi-Page Session'), findsNothing);
    expect(find.text('Capabilities Lab'), findsNothing);
  });

  testWidgets(
    'Navigation destinations are ordered correctly - Quick Scan first',
    (tester) async {
      await tester.pumpWidget(const DocumentScannerShowcaseApp());
      await tester.pumpAndSettle();

      // Verify the navigation bar destinations exist and are in the correct order
      final quickScanDestination = find.text('Quick Scan');
      final multiScanDestination = find.text('Multi Scan');
      final labDestination = find.text('Lab');

      expect(quickScanDestination, findsOneWidget);
      expect(multiScanDestination, findsOneWidget);
      expect(labDestination, findsOneWidget);

      // Verify Quick Scan is the default selected tab (first tab)
      expect(find.text('Quick Scan'), findsOneWidget);

      // Get the NavigationBar widget to check selectedIndex
      final navigationBar = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(
        navigationBar.selectedIndex,
        equals(0),
      ); // Quick Scan should be selected by default
    },
  );

  testWidgets('First scan banner appears on initial single page screen', (
    tester,
  ) async {
    await tester.pumpWidget(const DocumentScannerShowcaseApp());
    await tester.pumpAndSettle();

    // Verify the first scan banner is present when no scan has been performed
    expect(find.text('First scan?'), findsOneWidget);
    expect(
      find.text(
        'Start quick with camera capture or gallery import. For longer documents, switch to the Multi Scan tab.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try the quick actions below'), findsOneWidget);
    expect(find.text('Multi Scan for multiple pages'), findsOneWidget);
  });

  testWidgets('Navigation structure works correctly', (tester) async {
    await tester.pumpWidget(const DocumentScannerShowcaseApp());
    await tester.pumpAndSettle();

    // Verify navigation bar exists and has correct structure
    expect(find.byType(NavigationBar), findsOneWidget);

    // Verify Quick Scan is selected by default
    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.selectedIndex, equals(0));

    // Test navigation between tabs
    await tester.tap(find.text('Multi Scan'));
    await tester.pumpAndSettle();

    final navigationBarAfterTap = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBarAfterTap.selectedIndex, equals(1));

    await tester.tap(find.text('Lab'));
    await tester.pumpAndSettle();

    final navigationBarAfterSecondTap = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBarAfterSecondTap.selectedIndex, equals(2));
  });
}
