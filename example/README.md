# Document Scanner Example (Phase 2 Showcase)

This example application has been rewritten to act as the Phase 2 showcase for the rebuilt `document_scanner` APIs. Instead of a single demo screen, the app now exposes dedicated experiences that mirror production scenarios and exercise every public surface area of the library.

## Features at a glance

- **Single Page Capture** – launches `DocumentScannerWidget`, walks through the image editor, PDF preview, and surfaces metadata/paths after saving.  
  _Placeholder GIF_: `![Single page flow](docs/images/showcase_single_page.gif)`
- **Multi-Page Session Lab** – highlights `MultiPageScannerWidget`, page management, preview/reorder flows, and final PDF generation.  
  _Placeholder GIF_: `![Multi-page flow](docs/images/showcase_multi_page.gif)`
- **PDF Review Center** – feeds saved `ScannedDocument` instances into `PdfPreviewWidget`, reloads bytes from disk, and displays metadata in dialogs.  
  _Placeholder image_: `![PDF preview screen](docs/images/showcase_pdf_preview.png)`
- **Capabilities Lab** – interactive playground for `DocumentProcessingOptions` that calls `DocumentScannerService.scanDocumentWithProcessing` / `importDocumentWithProcessing` directly so you can toggle grayscale, compression, DPI, output formats, and filenames.  
  _Placeholder GIF_: `![Capabilities lab](docs/images/showcase_capabilities.gif)`

Each flow records its results in a shared timeline on the home screen so you can hop back into previews or re-run tests quickly.

## Getting started (Android-only)

1. Install Flutter 3+ and Android tooling.
2. From the repo root run:
   ```bash
   cd example
   flutter pub get
   flutter run
   ```
3. The home screen lets you call `DocumentScannerService().configureStorage()` with an app name, optional custom directory, and a default filename. Update these fields first so every flow writes into a predictable location.

> ⚠️ **Permissions**: Camera + storage permissions must be granted (emulator or device) for capture, multi-page, and capabilities lab flows. The PDF review screen requires that at least one document was previously saved so the preview widget can read bytes from disk.

## Flow walkthroughs

### Single Page Capture
1. Configure an optional filename in the top text field.
2. Pick the document type chip (document, receipt, or manual).
3. Tap **Launch scanner** to fire `DocumentScannerWidget`.
4. Go through the editor (rotation, filters, perspective); when you confirm, `PdfPreviewWidget` is shown before saving.
5. Back on the showcase screen you’ll see: preview thumbnail, pdf/process paths, metadata table, processing options, and a button that re-opens the PDF preview.

### Multi-Page Session Lab
1. Enter a session-specific filename (defaults to metadata-driven naming if blank).
2. Tap **Start multi-page session** to open `MultiPageScannerWidget`.
3. Capture at least two pages, open the preview grid, reorder them, and finalize the document.
4. The screen renders the aggregated `ScanResultDetails` plus a card per page (with timestamps and metadata) so you can verify ordering.

### PDF Review Center
1. After running any scan, navigate to **PDF Review** from the home screen.
2. Each saved document appears with type, page count, and absolute PDF path.
3. Tap **Preview PDF** to push `PdfPreviewWidget`. The widget loads in-memory bytes when available, otherwise it reads directly from `document.pdfPath`.
4. Use the info icon to view raw metadata (custom filenames, sizes, timestamps) in an alert dialog.

### Capabilities Lab
1. Toggle switches to control grayscale, contrast, perspective, PDF generation, and whether to emit an image alongside the PDF.
2. Adjust compression and pick the `PdfResolution` / `DocumentFormat` combos.
3. Optionally override the filename per run.
4. Use **Capture with camera** or **Import from gallery**; both call the processing-first service methods.
5. Inspect the resulting `ScanResult` with metadata, preview, and the global timeline to confirm the toggles behaved as expected.

## Manual test checklist

Run these steps on a physical device or emulator to validate the showcase:

1. Apply a custom `appName`, storage directory, and default filename. Capture a single page and verify the resulting files land in the custom directory using the configured name.
2. Launch Single Page Capture, go through the editor, finish via the PDF preview, and confirm the metadata/paths/preview render on the detail card.
3. Launch a multi-page session with at least three pages, reorder them once, and finalize the PDF. Ensure the page list reflects the correct count and ordering.
4. Open the PDF Review screen and preview both of the above scans via `PdfPreviewWidget`.
5. In the Capabilities Lab, disable grayscale, enable “save processed image”, set DPI to `original`, and run both camera + gallery experiments. Confirm the result card shows two output paths (PDF + image).
6. Trigger an error (deny a permission or cancel mid-flow) and verify it is recorded in the home timeline with the correct status chip.

These mirror the checklist surfaced inside the app (tap the clipboard icon in the home app bar).

## Testing

From the repo root or the `example` directory you can run:

```bash
flutter test
```

All example code uses `flutter_lints`, so you can optionally format/analyze with:

```bash
flutter format lib
flutter analyze
```

(Formatting/linting will run automatically inside CI as part of the main package.)

## Screenshot / GIF placeholders

Replace the placeholder references above with your own capture assets under `example/docs/images/`. Suggested filenames:

- `showcase_single_page.gif`
- `showcase_multi_page.gif`
- `showcase_pdf_preview.png`
- `showcase_capabilities.gif`

Keeping the assets in that directory allows both the example README and the root README to embed the same visuals.
