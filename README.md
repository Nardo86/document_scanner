# Document Scanner

A Flutter package for scanning documents, receipts, and manuals with
manual/automatic cropping, perspective correction, image processing, and PDF
generation.

## Features

- **Document scanning** via a guided camera (draggable A4 trapezoid overlay) or
  gallery import
- **Automatic edge detection** (Otsu white-blob) and **real perspective
  correction** (homography + bilinear), with a manual crop editor
- **Image processing**: grayscale, contrast enhancement, adaptive B&W (Otsu),
  histogram equalisation (CLAHE-inspired)
- **PDF generation** with configurable page format, resolution and metadata
- **Multi-page scanning** sessions with page reorder/delete
- **QR code scanning** to download documents from URLs (hardened: HTTPS-only,
  size-capped, SSRF-guarded)
- **Image editing UI**: rotation, crop, colour filters, format selection
- **PDF preview** widget with native rendering
- **Configurable, scoped storage** — no special Android storage permission

## Installation

```yaml
dependencies:
  document_scanner:
    git:
      url: https://github.com/Nardo86/document_scanner.git
      ref: v3.0.0
```

> Upgrading from 1.x/2.x? See [MIGRATION.md](MIGRATION.md) — 3.0.0 has breaking
> changes.

## Quick Start

### 1. Configure storage (optional)

```dart
import 'package:document_scanner/document_scanner.dart';

// Shared instance used by the widgets unless you pass your own.
DocumentScannerService.instance.configureStorage(
  appName: 'MyApp',
  // Or an explicit directory (you handle its permissions):
  // customStorageDirectory: '/storage/emulated/0/Documents/MyApp',
);
```

### 2. Scan a document

```dart
final result = await DocumentScannerService.instance.scanDocumentWithProcessing(
  documentType: DocumentType.receipt,
  customFilename: 'Receipt_001',
);

if (result.success) {
  final doc = result.document!;
  print('PDF: ${doc.pdfPath}');
}
```

### 3. Import from gallery

```dart
final result = await DocumentScannerService.instance.importDocumentWithProcessing(
  documentType: DocumentType.document,
);
```

### 4. Use the scanner widget

```dart
DocumentScannerWidget(
  documentType: DocumentType.receipt,
  onScanComplete: (result) {
    if (result.success) {
      // Handle scanned document
    }
  },
  // Optional: a service configured with a custom storage directory.
  // service: myConfiguredService,
);
```

### 5. Multi-page scanning

```dart
MultiPageScannerWidget(
  documentType: DocumentType.document,
  onScanComplete: (result) {
    // result.document contains the merged multi-page PDF
  },
);
```

### 6. QR code → download

```dart
// Needs a BuildContext to present the scanner UI.
final result = await DocumentScannerService.instance.scanQRCodeAndDownload(context);
```

## API Reference

### DocumentScannerService

Use `DocumentScannerService.instance` for a shared, app-wide configuration, or
construct your own `DocumentScannerService()` for an isolated one.

| Method | Description |
|--------|-------------|
| `configureStorage()` | Set storage directory and app name (per instance) |
| `scanDocument()` | Scan via camera (optional `autoProcess`) |
| `importDocument()` | Import from gallery |
| `scanDocumentWithProcessing()` | Scan + auto-process + save |
| `importDocumentWithProcessing()` | Import + auto-process + save |
| `finalizeScanResult()` | Generate PDF and save after editing |
| `finalizeMultiPageSession()` | Merge a multi-page session into a PDF |
| `showImageEditorFlow()` | Full edit → preview → save flow |
| `scanQRCode(context)` | Scan a QR code (needs context) |
| `scanQRCodeAndDownload(context)` | Scan a QR code and download the linked file |
| `downloadManualFromUrl()` | Download a document from a URL (HTTPS-only) |

### DocumentType

| Value | Default Processing |
|-------|-------------------|
| `receipt` | Grayscale, high contrast, 300 DPI |
| `manual` | Colour preserved, 300 DPI |
| `document` | Balanced, 300 DPI |
| `other` | Same as `document` |

### DocumentProcessingOptions

```dart
DocumentProcessingOptions(
  convertToGrayscale: true,
  enhanceContrast: true,
  autoCorrectPerspective: true,
  compressionQuality: 0.8,
  outputFormat: ImageFormat.jpeg,
  generatePdf: true,
  saveImageFile: false,
  pdfResolution: PdfResolution.quality,  // 300 DPI
  documentFormat: DocumentFormat.isoA,   // A4
);
```

### PDF Formats

| Format | Size |
|--------|------|
| `isoA` | A4 (210 × 297 mm) |
| `usLetter` | 8.5 × 11 in |
| `usLegal` | 8.5 × 14 in |
| `square` | 210 × 210 mm |
| `receipt` | 80 × 297 mm |
| `businessCard` | 85 × 55 mm |

### Colour Filters (`DocumentColorFilter`)

| Filter | Algorithm |
|--------|-----------|
| `none` | Original colours |
| `blackAndWhite` | Otsu adaptive thresholding |
| `highContrast` | Per-channel histogram equalisation (CLAHE-inspired) |

## Widgets

| Widget | Purpose |
|--------|---------|
| `DocumentScannerWidget` | Single-page scan UI (guided camera) |
| `MultiPageScannerWidget` | Multi-page scan session UI |
| `ImageEditingWidget` | Rotation, crop, filters, format |
| `PdfPreviewWidget` | Native PDF preview |
| `DocumentCameraScreen` | Guided camera with A4 trapezoid overlay |
| `QRScannerScreen` | QR scanner screen (via `QRScannerService`) |

## Android Permissions

The library uses scoped, app-specific storage, so **no storage permission is
required**. Add only:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
<!-- Android 13+ gallery import -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

## Architecture

```
lib/src/
  models/
    scanned_document.dart    # Domain models and enums
    scan_result.dart         # Result types
  services/
    document_scanner_service.dart  # Public orchestrator
    camera_service.dart            # Camera/gallery + permissions
    image_processor.dart           # Filters, perspective, quality (off-thread)
    image_processing_isolate.dart  # Background processing pipeline (compute)
    auto_cropper.dart              # Otsu white-blob detection + homography warp
    pdf_generator.dart             # PDF creation with metadata
    qr_scanner_service.dart        # QR scanning + hardened downloads
    storage_helper.dart            # Scoped file I/O and safe naming
  ui/
    document_scanner_widget.dart
    multi_page_scanner_widget.dart
    image_editing_widget.dart
    pdf_preview_widget.dart
    document_camera_screen.dart
```

## Requirements

- Flutter ≥ 3.32.0, Dart SDK ≥ 3.8.1
- Android or iOS device (camera features require a physical device)

## License

MIT
