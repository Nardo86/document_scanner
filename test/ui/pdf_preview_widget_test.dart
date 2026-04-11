import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/document_scanner.dart';

void main() {
  group('PdfPreviewWidget Tests', () {
    late Uint8List testPdfData;
    late Uint8List testImageData;

    setUp(() {
      // Create test PDF data (minimal valid PDF header)
      testPdfData = Uint8List.fromList([
        0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34, // %PDF-1.4
        0x0A, 0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A, 0x0A, // Binary comment
        0x31, 0x20, 0x30, 0x20, 0x6F, 0x62, 0x6A, 0x0A, // 1 0 obj
        0x3C, 0x3C, 0x2F, 0x54, 0x69, 0x74, 0x6C, 0x65, // </Title
        0x20, 0x28, 0x54, 0x65, 0x73, 0x74, 0x29, 0x2F, //  (Test)/
        0x50, 0x61, 0x67, 0x65, 0x73, 0x20, 0x31, 0x20, // Pages 1
        0x30, 0x20, 0x52, 0x3E, 0x3E, 0x0A, 0x65, 0x6E, //  0 R>>.en
        0x64, 0x6F, 0x62, 0x6A, 0x0A, 0x32, 0x20, 0x30, // dobj.2 0
        0x20, 0x6F, 0x62, 0x6A, 0x0A, 0x3C, 0x3C, 0x2F, //  obj.</
        0x54, 0x79, 0x70, 0x65, 0x20, 0x2F, 0x43, 0x61, // Type /Ca
        0x74, 0x61, 0x6C, 0x6F, 0x67, 0x2F, 0x50, 0x61, // talog/Pa
        0x67, 0x65, 0x73, 0x20, 0x33, 0x20, 0x30, 0x20, // ges 3 0
        0x52, 0x3E, 0x3E, 0x0A, 0x65, 0x6E, 0x64, 0x6F, //  R>>.endo
        0x62, 0x6A, 0x0A, 0x33, 0x20, 0x30, 0x20, 0x6F, // bj.3 0 o
        0x62, 0x6A, 0x0A, 0x3C, 0x3C, 0x2F, 0x54, 0x79, // bj.</Ty
        0x70, 0x65, 0x20, 0x2F, 0x50, 0x61, 0x67, 0x65, // pe /Page
        0x73, 0x2F, 0x4B, 0x69, 0x64, 0x73, 0x5B, 0x34, // s/Kids[4
        0x20, 0x30, 0x20, 0x52, 0x5D, 0x2F, 0x43, 0x6F, //  0 R]/Co
        0x75, 0x6E, 0x74, 0x20, 0x31, 0x3E, 0x3E, 0x0A, // unt 1>>.
        0x65, 0x6E, 0x64, 0x6F, 0x62, 0x6A, 0x0A, 0x34, // endobj.4
        0x20, 0x30, 0x20, 0x6F, 0x62, 0x6A, 0x0A, 0x3C, //  0 obj.<
        0x3C, 0x2F, 0x54, 0x79, 0x70, 0x65, 0x20, 0x2F, // </Type /
        0x50, 0x61, 0x67, 0x65, 0x2F, 0x50, 0x61, 0x72, // Page/Par
        0x65, 0x6E, 0x74, 0x20, 0x35, 0x20, 0x30, 0x20, // ent 5 0
        0x52, 0x2F, 0x52, 0x65, 0x73, 0x6F, 0x75, 0x72, // R/Resou
        0x63, 0x65, 0x73, 0x3C, 0x3C, 0x2F, 0x46, 0x6F, // rces</Fo
        0x6E, 0x74, 0x3C, 0x3C, 0x2F, 0x46, 0x31, 0x20, // nt</F1
        0x36, 0x20, 0x30, 0x20, 0x52, 0x3E, 0x3E, 0x3E, //  6 0 R>>>>
        0x3E, 0x3E, 0x0A, 0x65, 0x6E, 0x64, 0x6F, 0x62, // >>.endob
        0x6A, 0x0A, 0x35, 0x20, 0x30, 0x20, 0x6F, 0x62, // j.5 0 ob
        0x6A, 0x0A, 0x3C, 0x3C, 0x2F, 0x54, 0x79, 0x70, // j.</Typ
        0x65, 0x20, 0x2F, 0x50, 0x61, 0x67, 0x65, 0x73, // e /Pages
        0x2F, 0x43, 0x6F, 0x75, 0x6E, 0x74, 0x20, 0x31, // /Count 1
        0x2F, 0x4B, 0x69, 0x64, 0x73, 0x5B, 0x34, 0x20, // /Kids[4
        0x30, 0x20, 0x52, 0x5D, 0x3E, 0x3E, 0x0A, 0x65, //  0 R]>>.e
        0x6E, 0x64, 0x6F, 0x62, 0x6A, 0x0A, 0x36, 0x20, // ndobj.6
        0x30, 0x20, 0x6F, 0x62, 0x6A, 0x0A, 0x3C, 0x3C, //  0 obj.<
        0x2F, 0x54, 0x79, 0x70, 0x65, 0x20, 0x2F, 0x46, // /Type /F
        0x6F, 0x6E, 0x74, 0x2F, 0x53, 0x75, 0x62, 0x74, // ont/Subt
        0x79, 0x70, 0x65, 0x20, 0x2F, 0x54, 0x79, 0x70, // ype /Typ
        0x65, 0x31, 0x2F, 0x42, 0x61, 0x73, 0x65, 0x46, // e1/BaseF
        0x6F, 0x6E, 0x74, 0x2F, 0x48, 0x65, 0x6C, 0x76, // ont/Helv
        0x65, 0x74, 0x69, 0x63, 0x61, 0x3E, 0x3E, 0x0A, // etica>>.
        0x65, 0x6E, 0x64, 0x6F, 0x62, 0x6A, 0x0A, 0x78, // endobj.x
        0x72, 0x65, 0x66, 0x0A, 0x30, 0x20, 0x37, 0x0A, // ref.0 7.
        0x30, 0x20, 0x30, 0x20, 0x30, 0x20, 0x30, 0x20, // 0 0 0 0
        0x0A, 0x74, 0x72, 0x61, 0x69, 0x6C, 0x65, 0x72, // .trailer
        0x0A, 0x3C, 0x3C, 0x2F, 0x53, 0x69, 0x7A, 0x65, // .</Siz
        0x20, 0x37, 0x2F, 0x52, 0x6F, 0x6F, 0x74, 0x20, // e 7/Root
        0x32, 0x20, 0x30, 0x20, 0x52, 0x3E, 0x3E, 0x0A, //  2 0 R>>.
        0x73, 0x74, 0x61, 0x72, 0x74, 0x78, 0x72, 0x65, // startxre
        0x66, 0x0A, 0x33, 0x36, 0x34, 0x0A, 0x25, 0x25, // f.364.%%
        0x45, 0x4F, 0x46, 0x0A, // EOF
      ]);

      // Create test image data (simple 1x1 PNG)
      testImageData = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG header
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
        0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
        0x54, 0x08, 0x99, 0x63, 0xF8, 0x0F, 0x00, 0x00,
        0x01, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D, 0xB4,
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
        0xAE, 0x42, 0x60, 0x82,
      ]);
    });

    Widget createTestWidget({
      Uint8List? pdfData,
      String? pdfPath,
      String title = 'Test PDF Preview',
      VoidCallback? onConfirm,
      VoidCallback? onCancel,
      bool isLoading = false,
      Uint8List? fallbackImage,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: PdfPreviewWidget(
            pdfData: pdfData,
            pdfPath: pdfPath,
            title: title,
            onConfirm: onConfirm,
            onCancel: onCancel,
            isLoading: isLoading,
            fallbackImage: fallbackImage,
          ),
        ),
      );
    }

    // ---------------------------------------------------------------------------
    // App bar title
    // ---------------------------------------------------------------------------

    testWidgets('should display custom title in app bar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(title: 'Document Preview'));
      await tester.pump();

      // The widget.title is shown in the AppBar.
      expect(find.text('Document Preview'), findsOneWidget);
    });

    // ---------------------------------------------------------------------------
    // Preview header (always rendered, regardless of PDF data / loading state)
    // ---------------------------------------------------------------------------

    testWidgets('should display preview header with PDF icon and instructions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('PDF Preview'), findsOneWidget);
      expect(
        find.text(
          'Review your document before saving. You can zoom in/out and pan to check the quality.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.picture_as_pdf), findsAtLeastNWidgets(1));
    });

    // ---------------------------------------------------------------------------
    // AppBar Save action
    // ---------------------------------------------------------------------------

    testWidgets(
      'should display Save button in app bar when not loading and onConfirm provided',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(onConfirm: () {}));
        await tester.pump();

        // AppBar action: TextButton.icon with label 'Save' and Icons.check
        expect(find.text('Save'), findsOneWidget);
        expect(find.byIcon(Icons.check), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'should not display Save button in app bar when isLoading is true',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(isLoading: true, onConfirm: () {}),
        );
        await tester.pump();

        // AppBar hides the Save action while loading.
        expect(find.text('Save'), findsNothing);
      },
    );

    testWidgets(
      'should not display Save button in app bar when onConfirm is null',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.text('Save'), findsNothing);
      },
    );

    // ---------------------------------------------------------------------------
    // Bottom action bar (visible only when isLoading == false)
    // ---------------------------------------------------------------------------

    testWidgets(
      'should display bottom action bar with Cancel and Save Document when not loading',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(onConfirm: () {}, onCancel: () {}),
        );
        await tester.pump();

        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Save Document'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);
      },
    );

    testWidgets('should hide bottom action bar when isLoading is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(isLoading: true, onConfirm: () {}, onCancel: () {}),
      );
      await tester.pump();

      // The entire bottom bar (including Cancel and Save Document) is not built.
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Save Document'), findsNothing);
    });

    // ---------------------------------------------------------------------------
    // Loading state (isLoading: true → body shows spinner + text)
    // ---------------------------------------------------------------------------

    testWidgets('should show loading spinner and text when isLoading is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(isLoading: true));
      await tester.pump();

      expect(find.text('Loading PDF preview...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    // ---------------------------------------------------------------------------
    // No-data state
    // ---------------------------------------------------------------------------

    testWidgets('should show no data state when no PDF data or path provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('No PDF Data Available'), findsOneWidget);
      expect(
        find.text('No PDF data or file path provided for preview.'),
        findsOneWidget,
      );
    });

    testWidgets('should show PDF icon in no-data state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byIcon(Icons.picture_as_pdf), findsAtLeastNWidgets(1));
    });

    // ---------------------------------------------------------------------------
    // Callback tests (bottom bar is present when isLoading == false)
    // ---------------------------------------------------------------------------

    testWidgets(
      'should invoke onConfirm callback when Save Document is tapped',
      (WidgetTester tester) async {
        bool confirmCalled = false;
        await tester.pumpWidget(
          createTestWidget(onConfirm: () => confirmCalled = true),
        );
        await tester.pump();

        await tester.tap(find.text('Save Document'));
        await tester.pump();

        expect(confirmCalled, isTrue);
      },
    );

    testWidgets('should invoke onCancel callback when Cancel is tapped', (
      WidgetTester tester,
    ) async {
      bool cancelCalled = false;
      await tester.pumpWidget(
        createTestWidget(onCancel: () => cancelCalled = true),
      );
      await tester.pump();

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(cancelCalled, isTrue);
    });

    testWidgets(
      'should invoke onConfirm callback when app bar Save is tapped',
      (WidgetTester tester) async {
        bool confirmCalled = false;
        await tester.pumpWidget(
          createTestWidget(onConfirm: () => confirmCalled = true),
        );
        await tester.pump();

        await tester.tap(find.text('Save'));
        await tester.pump();

        expect(confirmCalled, isTrue);
      },
    );

    // ---------------------------------------------------------------------------
    // Layout structure
    // ---------------------------------------------------------------------------

    testWidgets('should have AppBar with at least one IconButton', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(IconButton), findsAtLeastNWidgets(1));
    });

    testWidgets('should have Scaffold, Column, and Container in widget tree', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byType(Scaffold), findsWidgets);
      expect(find.byType(Column), findsAtLeastNWidgets(1));
      expect(find.byType(Container), findsAtLeastNWidgets(1));
    });

    testWidgets('should have Expanded widget for PDF content area', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byType(Expanded), findsAtLeastNWidgets(1));
    });

    // ---------------------------------------------------------------------------
    // Error States with Fallback
    // ---------------------------------------------------------------------------

    group('Error States with Fallback', () {
      testWidgets(
        'should show fallback image and unavailability notice when PDF loading fails with fallback provided',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            createTestWidget(
              pdfData: null,
              pdfPath: '/nonexistent/path.pdf',
              fallbackImage: testImageData,
            ),
          );
          await tester.pumpAndSettle(const Duration(seconds: 2));

          expect(find.text('PDF Rendering Unavailable'), findsOneWidget);
          expect(find.text('Showing processed image instead'), findsOneWidget);
          expect(find.byType(Image), findsOneWidget);
        },
      );

      testWidgets(
        'should show error state without fallback when no fallback image is provided',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            createTestWidget(pdfData: null, pdfPath: '/nonexistent/path.pdf'),
          );
          await tester.pumpAndSettle(const Duration(seconds: 2));

          expect(find.text('Error Loading PDF'), findsOneWidget);
          expect(find.byIcon(Icons.error_outline), findsOneWidget);
        },
      );

      testWidgets('should have Retry button with refresh icon in error state', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(pdfData: null, pdfPath: '/nonexistent/path.pdf'),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));

        expect(find.byIcon(Icons.refresh), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });
    });

    // ---------------------------------------------------------------------------
    // Button States
    // ---------------------------------------------------------------------------

    group('Button States', () {
      testWidgets('should style Cancel button with red foreground', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(onConfirm: () {}, onCancel: () {}),
        );
        await tester.pump();

        final cancelButton = tester.widget<OutlinedButton>(
          find.ancestor(
            of: find.text('Cancel'),
            matching: find.byType(OutlinedButton),
          ),
        );
        expect(cancelButton.style?.foregroundColor?.resolve({}), Colors.red);
      });

      testWidgets('should style Save Document button with green background', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(onConfirm: () {}, onCancel: () {}),
        );
        await tester.pump();

        final saveButton = tester.widget<ElevatedButton>(
          find.ancestor(
            of: find.text('Save Document'),
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(saveButton.style?.backgroundColor?.resolve({}), Colors.green);
      });

      testWidgets('should show Save Document text when isLoading is false', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget(isLoading: false));
        await tester.pump();

        expect(find.text('Save Document'), findsOneWidget);
      });

      testWidgets(
        'should not show Save Document button when isLoading is true',
        (WidgetTester tester) async {
          await tester.pumpWidget(createTestWidget(isLoading: true));
          await tester.pump();

          // Bottom action bar is completely hidden when isLoading is true.
          expect(find.text('Save Document'), findsNothing);
        },
      );
    });

    // ---------------------------------------------------------------------------
    // Content Areas
    // ---------------------------------------------------------------------------

    group('Content Areas', () {
      testWidgets('should always render preview header area', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.text('PDF Preview'), findsOneWidget);
        expect(find.byIcon(Icons.picture_as_pdf), findsAtLeastNWidgets(1));
      });

      testWidgets('should have PDF content area with Expanded widget', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byType(Expanded), findsAtLeastNWidgets(1));
      });

      testWidgets('should render bottom action area when not loading', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(onConfirm: () {}, onCancel: () {}),
        );
        await tester.pump();

        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Save Document'), findsOneWidget);
      });
    });

    // ---------------------------------------------------------------------------
    // Accessibility
    // ---------------------------------------------------------------------------

    group('Accessibility', () {
      testWidgets('should have proper button labels in bottom bar', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(onConfirm: () {}, onCancel: () {}),
        );
        await tester.pump();

        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Save Document'), findsOneWidget);
      });

      testWidgets('should show Save label in app bar when onConfirm provided', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget(onConfirm: () {}));
        await tester.pump();

        expect(find.text('Save'), findsOneWidget);
      });

      testWidgets('should have PDF icon in preview header', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byIcon(Icons.picture_as_pdf), findsAtLeastNWidgets(1));
      });
    });

    // ---------------------------------------------------------------------------
    // Fallback Image Feature
    // ---------------------------------------------------------------------------

    group('Fallback Image Feature', () {
      testWidgets('should accept fallbackImage parameter without error', (
        WidgetTester tester,
      ) async {
        // When pdfData is provided, the widget attempts to load the PDF normally.
        // The fallback is only used on error; the widget tree itself must not crash.
        await tester.pumpWidget(
          createTestWidget(pdfData: testPdfData, fallbackImage: testImageData),
        );
        await tester.pump();

        // At minimum the outer Scaffolds (MaterialApp + PdfPreviewWidget) are present.
        expect(find.byType(Scaffold), findsWidgets);
      });

      testWidgets('should display fallback image when PDF rendering fails', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            pdfData: null,
            pdfPath: '/invalid/path.pdf',
            fallbackImage: testImageData,
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));

        expect(find.text('PDF Rendering Unavailable'), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
      });
    });

    // ---------------------------------------------------------------------------
    // PDF Loading States (native PDF rendering required for full verification)
    // ---------------------------------------------------------------------------

    group('PDF Loading States', () {
      testWidgets('should show loading state during PDF initialization', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget(pdfData: testPdfData));

        // Should show loading immediately (or attempt to load)
        // Note: Actual PDF rendering requires native platform support
        expect(find.byType(Scaffold), findsOneWidget);
      }, skip: true); // Skip PDF rendering test - requires native platform

      testWidgets('should transition from loading to display state', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget(pdfData: testPdfData));

        // Initially loading
        await tester.pump(const Duration(milliseconds: 100));

        // Should have successfully loaded
        expect(find.byType(Scaffold), findsOneWidget);
      }, skip: true); // Skip PDF rendering test - requires native platform
    });
  });
}
