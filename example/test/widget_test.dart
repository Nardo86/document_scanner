import 'package:flutter_test/flutter_test.dart';

import 'package:document_scanner_example/app.dart';

void main() {
  testWidgets('Phase 2 showcase home renders key flows', (tester) async {
    await tester.pumpWidget(const DocumentScannerShowcaseApp());
    await tester.pumpAndSettle();

    expect(find.text('Phase 2 Showcase'), findsOneWidget);
    expect(find.text('Single Page Capture'), findsOneWidget);
    expect(find.text('Multi-Page Session'), findsOneWidget);
    expect(find.text('PDF Review'), findsOneWidget);
    expect(find.text('Capabilities Lab'), findsOneWidget);
  });
}
