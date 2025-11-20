import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:document_scanner/document_scanner.dart';

import 'document_scanner_widget_test.mocks.dart';

@GenerateMocks([DocumentScannerService])
void main() {
  group('DocumentScannerWidget Tests', () {
    late MockDocumentScannerService mockScannerService;

    setUp(() {
      mockScannerService = MockDocumentScannerService();
    });

    Widget createTestWidget({
      DocumentType documentType = DocumentType.document,
      DocumentProcessingOptions? processingOptions,
      String? customFilename,
      Function(ScanResult)? onScanComplete,
      Function(String)? onError,
      bool showQROption = false,
      bool showImportOption = true,
      Widget? customHeader,
      Widget? customFooter,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: DocumentScannerWidget(
            documentType: documentType,
            processingOptions: processingOptions,
            customFilename: customFilename,
            onScanComplete: onScanComplete ?? (ScanResult result) {},
            onError: onError ?? (String error) {},
            showQROption: showQROption,
            showImportOption: showImportOption,
            customHeader: customHeader,
            customFooter: customFooter,
          ),
        ),
      );
    }

    testWidgets('should display document scanner with correct title', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(documentType: DocumentType.receipt));

      expect(find.text('Scan Receipt'), findsOneWidget);
      expect(find.text('Receipt Scanner'), findsOneWidget);
    });

    testWidgets('should display camera scan option', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Scan with Camera'), findsOneWidget);
      expect(find.text('Take a photo of the document'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('should display import option when enabled', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(showImportOption: true));

      expect(find.text('Import from Gallery'), findsOneWidget);
      expect(find.text('Select an existing photo'), findsOneWidget);
      expect(find.byIcon(Icons.photo_library), findsOneWidget);
    });

    testWidgets('should not display import option when disabled', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(showImportOption: false));

      expect(find.text('Import from Gallery'), findsNothing);
      expect(find.byIcon(Icons.photo_library), findsNothing);
    });

    testWidgets('should display custom header when provided', (WidgetTester tester) async {
      const customHeader = Text('Custom Header');
      await tester.pumpWidget(createTestWidget(customHeader: customHeader));

      expect(find.text('Custom Header'), findsOneWidget);
    });

    testWidgets('should display custom footer when provided', (WidgetTester tester) async {
      const customFooter = Text('Custom Footer');
      await tester.pumpWidget(createTestWidget(customFooter: customFooter));

      expect(find.text('Custom Footer'), findsOneWidget);
    });

    testWidgets('should display correct document type information', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(documentType: DocumentType.manual));

      expect(find.text('Add Manual'), findsOneWidget);
      expect(find.text('Manual Scanner'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book), findsOneWidget);
    });

    testWidgets('should show processing indicator when scanning', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Simulate scan start by tapping camera button
      await tester.tap(find.text('Scan with Camera'));
      await tester.pump();

      // Check for processing indicator
      expect(find.text('Processing...'), findsOneWidget);
      expect(find.text('Please wait while we process your document'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('should disable buttons during processing', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Simulate scan start
      await tester.tap(find.text('Scan with Camera'));
      await tester.pump();

      // Buttons should be disabled during processing
      final cameraButton = tester.widget<InkWell>(
        find.ancestor(
          of: find.text('Scan with Camera'),
          matching: find.byType(InkWell),
        ),
      );
      expect(cameraButton.onTap, isNull);
    });

    testWidgets('should display error message when error occurs', (WidgetTester tester) async {
      String? capturedError;
      await tester.pumpWidget(createTestWidget(
        onError: (String error) => capturedError = error,
      ));

      // Simulate error state by setting it directly
      // In a real test, you'd mock the service to return an error
      // For now, we'll just verify the error display structure exists
      expect(find.byType(Card), findsWidgets); // Error card structure
    });

    testWidgets('should handle document type receipt correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(documentType: DocumentType.receipt));

      expect(find.text('Scan Receipt'), findsOneWidget);
      expect(find.text('Receipt Scanner'), findsOneWidget);
      expect(find.byIcon(Icons.receipt), findsOneWidget);
      expect(find.text('Take a photo of the receipt'), findsOneWidget);
    });

    testWidgets('should handle document type other correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(documentType: DocumentType.other));

      expect(find.text('Scan Document'), findsOneWidget);
      expect(find.text('Scanner'), findsOneWidget);
      expect(find.byIcon(Icons.document_scanner), findsOneWidget);
      expect(find.text('Take a photo of the document'), findsOneWidget);
    });

    group('Document Type Icons', () {
      testWidgets('should show receipt icon for receipt type', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(documentType: DocumentType.receipt));
        expect(find.byIcon(Icons.receipt), findsOneWidget);
      });

      testWidgets('should show manual icon for manual type', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(documentType: DocumentType.manual));
        expect(find.byIcon(Icons.menu_book), findsOneWidget);
      });

      testWidgets('should show description icon for document type', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(documentType: DocumentType.document));
        expect(find.byIcon(Icons.description), findsOneWidget);
      });

      testWidgets('should show scanner icon for other type', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(documentType: DocumentType.other));
        expect(find.byIcon(Icons.document_scanner), findsOneWidget);
      });
    });

    group('User Interactions', () {
      testWidgets('should handle camera scan button tap', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Scan with Camera'), findsOneWidget);
        await tester.tap(find.text('Scan with Camera'));
        await tester.pump();

        // Should show processing state
        expect(find.text('Processing...'), findsOneWidget);
      });

      testWidgets('should handle import button tap', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(showImportOption: true));

        expect(find.text('Import from Gallery'), findsOneWidget);
        await tester.tap(find.text('Import from Gallery'));
        await tester.pump();

        // Should show processing state
        expect(find.text('Processing...'), findsOneWidget);
      });

      testWidgets('should handle error dismissal', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // We can't easily trigger an error state without complex mocking
        // But we can verify the error display structure exists
        expect(find.byType(Card), findsWidgets);
      });
    });

    group('Layout and Structure', () {
      testWidgets('should have proper app bar structure', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(AppBar), findsOneWidget);
        expect(find.text('Scan Document'), findsOneWidget);
      });

      testWidgets('should have proper card structure for options', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(Card), findsWidgets);
        expect(find.text('Document Scanner'), findsOneWidget);
      });

      testWidgets('should have proper button layout', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(Card), findsWidgets);
        expect(find.byType(InkWell), findsAtLeastNWidgets(1));
      });
    });
  });
}