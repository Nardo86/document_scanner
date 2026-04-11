# Document Scanner Example

Showcase app for the `document_scanner` Flutter package. Exercises every public API surface through three tabs and a floating action menu.

## Screens

### Quick Scan
Single-page capture via `DocumentScannerWidget` (guided flow) or direct camera/gallery import. Includes image editing, PDF preview, and metadata display.

### Multi Scan
Multi-page session using `MultiPageScannerWidget`. Capture multiple pages, reorder them, and finalize into a single PDF. Shows a page grid with thumbnails, timestamps, and a metadata dialog.

### Lab
Interactive playground for `DocumentProcessingOptions`. Toggle grayscale, contrast, perspective correction, compression, DPI, and output format, then call `scanDocumentWithProcessing` / `importDocumentWithProcessing` directly.

### Shared features
- **Storage configuration** — tap the FAB menu to set app name, custom directory, and default filename. All tabs respect these settings.
- **Scan history** — every flow records results in a shared timeline accessible from the FAB menu.
- **PDF preview** — all screens use the shared `openPdfPreview` helper to load and display PDFs via `PdfPreviewWidget`.

## Getting started

1. Install Flutter 3+ and Android tooling.
2. From the repo root:
   ```bash
   cd example
   flutter pub get
   flutter run
   ```
3. Grant camera and storage permissions when prompted.

> The app requires a physical device or emulator with camera support for capture flows. Gallery import works on emulators.

## Project structure

```
lib/
  helpers/
    pdf_preview_helper.dart   # Shared PDF preview navigation
  screens/
    single_page_screen.dart   # Quick Scan tab
    multi_page_screen.dart    # Multi Scan tab
    capabilities_lab_screen.dart  # Lab tab
    pdf_preview_screen.dart   # PDF preview route
  state/
    showcase_state.dart       # App state via InheritedNotifier
  widgets/
    empty_state.dart          # Empty placeholder widget
    scan_result_details.dart  # Result card with metadata
    section_header.dart       # Section title widget
  app.dart                    # Tab shell, config dialog, history dialog
  main.dart                   # Entry point
```

## Testing

```bash
flutter analyze
flutter test
```

Formatting and analysis also run in CI as part of the main package workflow.
