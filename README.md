# Document Scanner

A Flutter package for scanning documents, receipts, and manuals with automatic cropping, image processing, and PDF generation.

## Features

- **Document scanning** via camera or gallery import
- **Automatic edge detection** and perspective correction (Canny + contour pipeline)
- **Image processing**: grayscale, contrast enhancement, adaptive B&W (Otsu), histogram equalization
- **PDF generation** with configurable page format, DPI, and metadata
- **Multi-page scanning** sessions with page reorder/delete
- **QR code scanning** to download documents from URLs
- **Image editing UI**: rotation, crop, colour filters, format selection
- **PDF preview** widget with native rendering
- **Configurable storage**: custom paths, metadata-driven filenames

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  document_scanner:
    git:
      url: https://github.com/Nardo86/document_scanner.git
      ref: v2.2.0
```

## Quick Start

### 1. Configure storage

```dart
import 'package:document_scanner/document_scanner.dart';

DocumentScannerService().configureStorage(
  appName: 'MyApp',
  customStorageDirectory: '/storage/emulated/0/Documents/MyApp',
);
```

### 2. Scan a document

```dart
// Camera scan with automatic processing (returns populated pdfPath)
final result = await DocumentScannerService().scanDocumentWithProcessing(
  documentType: DocumentType.receipt,
  processingOptions: DocumentProcessingOptions.receipt,
  customFilename: 'Receipt_001',
);

if (result.success) {
  final doc = result.document!;
  print('PDF: ${doc.pdfPath}');
}
```

### 3. Import from gallery

```dart
final result = await DocumentScannerService().importDocumentWithProcessing(
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

## API Reference

### DocumentScannerService

| Method | Description |
|--------|-------------|
| `configureStorage()` | Set storage directory and app name |
| `scanDocument()` | Scan via camera (optional `autoProcess`) |
| `importDocument()` | Import from gallery |
| `scanDocumentWithProcessing()` | Scan + auto-process + save |
| `importDocumentWithProcessing()` | Import + auto-process + save |
| `finalizeScanResult()` | Generate PDF and save after editing |
| `finalizeMultiPageSession()` | Merge multi-page session into PDF |
| `showImageEditorFlow()` | Full edit -> preview -> save flow |
| `scanQRCode()` | Scan QR code |
| `downloadManualFromUrl()` | Download document from URL |

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
| `isoA` | A4 (210 x 297 mm) |
| `usLetter` | 8.5 x 11 in |
| `usLegal` | 8.5 x 14 in |
| `square` | 210 x 210 mm |
| `receipt` | 80 x 297 mm |
| `businessCard` | 85 x 55 mm |

### Colour Filters

| Filter | Algorithm |
|--------|-----------|
| `blackAndWhite` | Otsu's adaptive thresholding |
| `highContrast` | Per-channel histogram equalization (CLAHE-inspired) |

## Widgets

| Widget | Purpose |
|--------|---------|
| `DocumentScannerWidget` | Single-page scan UI |
| `MultiPageScannerWidget` | Multi-page scan session UI |
| `ImageEditingWidget` | Rotation, crop, filters, format |
| `PdfPreviewWidget` | Native PDF preview |

## Android Permissions

Add to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.INTERNET" />
```

## Architecture

```
lib/src/
  models/
    scanned_document.dart    # Domain models and enums
    scan_result.dart         # Result types
  services/
    document_scanner_service.dart  # Main orchestrator
    camera_service.dart            # Camera/gallery + permissions
    image_processor.dart           # Filters, perspective, quality
    image_processing_isolate.dart  # Background processing pipeline
    auto_cropper.dart              # Canny edge detection pipeline
    pdf_generator.dart             # PDF creation with metadata
    qr_scanner_service.dart        # QR scanning + downloads
    storage_helper.dart            # File I/O and naming
  ui/
    document_scanner_widget.dart
    multi_page_scanner_widget.dart
    image_editing_widget.dart
    pdf_preview_widget.dart
```

## Requirements

- Flutter >= 3.0.0
- Dart SDK >= 3.8.1
- Android or iOS device (camera features require physical device)

## License

MIT
