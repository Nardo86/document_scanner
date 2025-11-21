import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:document_scanner_example/app.dart';

void main() {
  testWidgets('Navigation destinations are ordered correctly - Quick Scan first', (tester) async {
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
    final navigationBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigationBar.selectedIndex, equals(0)); // Quick Scan should be selected by default
  });

  testWidgets('First scan banner appears on initial single page screen', (tester) async {
    await tester.pumpWidget(const DocumentScannerShowcaseApp());
    await tester.pumpAndSettle();

    // Verify the first scan banner is present when no scan has been performed
    expect(find.text('First scan?'), findsOneWidget);
    expect(find.text('Start quick with camera capture or gallery import. For longer documents, switch to the Multi Scan tab.'), findsOneWidget);
    expect(find.text('Try the quick actions below'), findsOneWidget);
    expect(find.text('Multi Scan for multiple pages'), findsOneWidget);
  });
}