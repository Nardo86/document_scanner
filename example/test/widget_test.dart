import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:document_scanner_example/main.dart';

void main() {
  testWidgets('Document Scanner Example app loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DocumentScannerExampleApp());

    // Verify that the app title is displayed.
    expect(find.text('Document Scanner Example'), findsOneWidget);
    
    // Verify that the document scanner icon is displayed.
    expect(find.byIcon(Icons.document_scanner), findsOneWidget);
    
    // Verify that the ready message is displayed.
    expect(find.textContaining('Ready to test'), findsOneWidget);
  });
}