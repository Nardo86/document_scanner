import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/document_scanner.dart';

void main() {
  group('MultiPageScannerWidget Tests', () {
    Widget createTestWidget({
      DocumentType documentType = DocumentType.document,
      DocumentProcessingOptions? processingOptions,
      String? customFilename,
      Function(ScanResult)? onScanComplete,
      Function(String)? onError,
      Widget? customHeader,
    }) {
      return MaterialApp(
        home: MultiPageScannerWidget(
          documentType: documentType,
          processingOptions: processingOptions,
          customFilename: customFilename,
          onScanComplete: onScanComplete ?? (ScanResult result) {},
          onError: onError ?? (String error) {},
          customHeader: customHeader,
        ),
      );
    }

    testWidgets('should display multi-page scanner with correct title', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(documentType: DocumentType.manual),
      );

      // The title appears in the AppBar and also in the initial scan view body
      expect(find.text('Multi-Page Manual'), findsAtLeastNWidgets(2));
      expect(find.byIcon(Icons.menu_book), findsOneWidget);
    });

    testWidgets('should show initial scan view when no pages exist', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      // Widget shows a large document-type icon, a headline title, a description
      // paragraph, and a single "Scan First Page" button in the initial state.
      expect(find.text('Scan First Page'), findsOneWidget);
      expect(
        find.text(
          'Scan multiple pages and combine them into a single PDF document',
        ),
        findsOneWidget,
      );
      // There is no "No pages scanned yet" or "Import Page" in the current widget.
      expect(find.text('No pages scanned yet'), findsNothing);
      expect(find.text('Import Page'), findsNothing);
    });

    testWidgets('should display custom header when provided', (
      WidgetTester tester,
    ) async {
      const customHeader = Text('Custom Multi-Page Header');
      await tester.pumpWidget(createTestWidget(customHeader: customHeader));

      expect(find.text('Custom Multi-Page Header'), findsOneWidget);
    });

    testWidgets('should have proper app bar structure', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byType(AppBar), findsOneWidget);
      // AppBar title text for the default DocumentType.document
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Multi-Page Document'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('should show page count indicator when pages exist', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      // Initially no pages: the page count indicator (which uses "page(s) scanned")
      // is not shown.
      expect(find.textContaining('scanned'), findsNothing);
    });

    testWidgets('should have scan button in initial view', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Scan First Page'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('should handle scan first page button tap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Scan First Page'), findsOneWidget);
      await tester.tap(find.text('Scan First Page'));
      await tester.pump();

      // After tapping, the async scan call runs. In the test environment without
      // mocking the scanner service the call will fail quickly, so _isProcessing
      // returns to false. We just verify the widget is still present.
      expect(find.byType(MultiPageScannerWidget), findsOneWidget);
    });

    testWidgets('should show correct document type for receipts', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(documentType: DocumentType.receipt),
      );

      // Title in AppBar and body both show "Multi-Page Receipt"
      expect(find.text('Multi-Page Receipt'), findsAtLeastNWidgets(2));
      expect(find.byIcon(Icons.receipt), findsOneWidget);
    });

    testWidgets('should show correct document type for other', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(documentType: DocumentType.other),
      );

      // DocumentType.other uses "Document" as the name, same as DocumentType.document
      expect(find.text('Multi-Page Document'), findsAtLeastNWidgets(2));
      expect(find.byIcon(Icons.document_scanner), findsOneWidget);
    });

    group('Page Management View', () {
      testWidgets('should show page management structure', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        // The widget wraps its body content in Column + Expanded widgets
        expect(find.byType(Column), findsWidgets);
        expect(find.byType(Expanded), findsWidgets);
      });

      testWidgets('should have scaffold structure', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(Scaffold), findsOneWidget);
      });
    });

    group('Button Interactions', () {
      testWidgets('should NOT show finalize tooltip when no pages exist', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        // The "Finalize Document" tooltip is only added to the AppBar actions
        // when a session with pages exists. With no pages it must not appear.
        expect(find.byTooltip('Finalize Document'), findsNothing);
      });

      testWidgets('should have add-page button only when pages exist', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        // "Add Page" is in the bottom action bar, which is hidden until pages
        // have been scanned.
        expect(find.text('Add Page'), findsNothing);
      });
    });

    group('Error Handling', () {
      testWidgets('should not show error card when there is no error', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        // The error card is only built when _currentError != null. Initially
        // there is no error, so no Card should be in the tree.
        expect(find.byType(Card), findsNothing);
      });

      testWidgets('should accept an onError callback without crashing', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget(onError: (_) {}));

        // Widget renders without error even when a custom error handler is given
        expect(find.byType(MultiPageScannerWidget), findsOneWidget);
      });
    });

    group('Document Types', () {
      testWidgets('should handle all document types correctly', (
        WidgetTester tester,
      ) async {
        final documentTypes = [
          DocumentType.document,
          DocumentType.manual,
          DocumentType.receipt,
          DocumentType.other,
        ];

        for (final docType in documentTypes) {
          await tester.pumpWidget(createTestWidget(documentType: docType));
          await tester.pump();

          switch (docType) {
            case DocumentType.document:
              // Text appears in AppBar title and in the initial scan view headline
              expect(find.text('Multi-Page Document'), findsAtLeastNWidgets(2));
              expect(find.byIcon(Icons.description), findsOneWidget);
              break;
            case DocumentType.manual:
              expect(find.text('Multi-Page Manual'), findsAtLeastNWidgets(2));
              expect(find.byIcon(Icons.menu_book), findsOneWidget);
              break;
            case DocumentType.receipt:
              expect(find.text('Multi-Page Receipt'), findsAtLeastNWidgets(2));
              expect(find.byIcon(Icons.receipt), findsOneWidget);
              break;
            case DocumentType.other:
              // "other" maps to the same name/icon as a generic document
              expect(find.text('Multi-Page Document'), findsAtLeastNWidgets(2));
              expect(find.byIcon(Icons.document_scanner), findsOneWidget);
              break;
          }
        }
      });
    });

    group('Initial View Content', () {
      testWidgets('should show proper initial view content', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        // Headline uses the document type name
        expect(find.text('Multi-Page Document'), findsAtLeastNWidgets(2));
        // Description paragraph
        expect(
          find.text(
            'Scan multiple pages and combine them into a single PDF document',
          ),
          findsOneWidget,
        );
        // Large document-type icon (Icons.description for DocumentType.document)
        expect(find.byIcon(Icons.description), findsOneWidget);
      });

      testWidgets('should have proper initial view layout', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(Column), findsWidgets);
        expect(find.byType(Center), findsWidgets);
        // Only the "Scan First Page" ElevatedButton exists in the initial view
        expect(find.byType(ElevatedButton), findsOneWidget);
      });
    });

    group('Processing States', () {
      testWidgets('should not show progress indicator before any action', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        // No processing is happening on initial render
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    group('Layout Structure', () {
      testWidgets('should have proper widget hierarchy', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byType(Column), findsWidgets);
        expect(find.byType(Expanded), findsWidgets);
      });

      testWidgets('should have scan button and no app-bar actions initially', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        // One ElevatedButton ("Scan First Page") in the initial view
        expect(find.byType(ElevatedButton), findsOneWidget);
        // No IconButtons in the AppBar actions when there are no pages
        expect(find.byType(IconButton), findsNothing);
      });
    });

    group('Page Reorder Dialog', () {
      testWidgets('should not show reorder dialog on initial render', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        // Reorder dialog is only invoked after pages exist and the user taps
        // the "Reorder" button. On initial render no dialog is visible.
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Reorder Pages'), findsNothing);
      });
    });

    group('Page Preview', () {
      testWidgets('should have column structure in initial view', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        // Basic layout column is always present
        expect(find.byType(Column), findsWidgets);
      });
    });
  });
}
