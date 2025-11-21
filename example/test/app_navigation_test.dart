import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:document_scanner_example/app.dart';

void main() {
  testWidgets('App structure and basic navigation test', (tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(const DocumentScannerShowcaseApp());
    await tester.pumpAndSettle();

    // Verify the app title
    expect(find.text('Document Scanner Showcase'), findsOneWidget);

    // Verify navigation destinations exist in correct order
    expect(find.text('Quick Scan'), findsOneWidget);
    expect(find.text('Multi Scan'), findsOneWidget);
    expect(find.text('Lab'), findsOneWidget);

    // Verify the NavigationBar exists
    expect(find.byType(NavigationBar), findsOneWidget);

    // Verify the first tab (Quick Scan) is selected by default
    final navigationBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigationBar.selectedIndex, equals(0));

    // Verify the single page screen content is shown
    expect(find.text('Single Page Capture'), findsOneWidget);
    expect(find.text('First scan?'), findsOneWidget);
    expect(find.text('Start quick with camera capture or gallery import. For longer documents, switch to the Multi Scan tab.'), findsOneWidget);

    // Test navigation to second tab
    await tester.tap(find.text('Multi Scan'));
    await tester.pumpAndSettle();
    
    // Verify navigation bar updated
    final navigationBarAfterTap = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigationBarAfterTap.selectedIndex, equals(1));

    // Test navigation to third tab
    await tester.tap(find.text('Lab'));
    await tester.pumpAndSettle();
    
    // Verify navigation bar updated
    final navigationBarAfterSecondTap = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigationBarAfterSecondTap.selectedIndex, equals(2));
  });
}