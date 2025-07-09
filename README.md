# Document Scanner

A Flutter package for scanning documents, receipts, and manuals with automatic cropping, filtering, and PDF generation. **Now with Multi-Page Support!**

## Features

- **🔸 Single & Multi-Page Scanning**: Scan individual pages or combine multiple pages into one document
- **📸 Document Scanning**: Camera and gallery support for document capture
- **🎨 Advanced Image Processing**: Automatic cropping, grayscale conversion, contrast enhancement
- **📄 PDF Generation**: Optimized single and multi-page PDF output with metadata
- **📱 QR Code Scanning**: Automatic manual download from QR codes
- **📋 Multiple Document Types**: Receipts, manuals, documents with specific processing
- **💾 External Storage**: Safe storage outside app directory with descriptive naming
- **⚙️ Customizable Processing**: Configurable image processing options
- **🔄 Page Management**: Add, remove, reorder, and preview pages in multi-page documents

## Installation

Add this package to your Flutter project:

```yaml
dependencies:
  document_scanner:
    path: packages/document_scanner
```

## Usage

### Single Page Scanning

```dart
import 'package:document_scanner/document_scanner.dart';

// Scan a single receipt
final result = await DocumentScannerService().scanDocument(
  documentType: DocumentType.receipt,
  processingOptions: DocumentProcessingOptions.receipt,
  customFilename: 'MyReceipt',
);

if (result.success) {
  print('Document saved: ${result.document?.pdfPath}');
} else {
  print('Error: ${result.error}');
}
```

### Multi-Page Scanning

```dart
// Use the multi-page scanner widget
MultiPageScannerWidget(
  documentType: DocumentType.manual,
  customFilename: 'ProductManual',
  onScanComplete: (result) {
    if (result.success) {
      print('Multi-page document created: ${result.document?.pdfPath}');
      print('Pages scanned: ${result.document?.pages.length}');
    }
  },
)
```

### Multi-Page Workflow

1. **Start Scanning**: Scan the first page
2. **Add More Pages**: Continue scanning additional pages
3. **Preview & Manage**: View thumbnails, preview pages, reorder, or delete pages
4. **Finalize**: Combine all pages into a single optimized PDF

### Using the Single Page UI Widget

```dart
DocumentScannerWidget(
  documentType: DocumentType.receipt,
  showQROption: true,
  onScanComplete: (result) {
    if (result.success) {
      // Handle successful scan
    } else {
      // Handle error
    }
  },
)
```

### QR Code Scanning for Manuals

```dart
// Scan QR code
final qrResult = await DocumentScannerService().scanQRCode();

if (qrResult.success && qrResult.contentType == QRContentType.manualLink) {
  // Download manual from QR code URL
  final downloadResult = await DocumentScannerService().downloadManualFromUrl(
    url: qrResult.qrData,
    customFilename: 'ProductManual',
  );
}
```

### Custom Processing Options

```dart
final customOptions = DocumentProcessingOptions(
  convertToGrayscale: true,
  enhanceContrast: true,
  autoCorrectPerspective: true,
  removeBackground: true,
  compressionQuality: 0.9,
  generatePdf: true,
);

final result = await DocumentScannerService().scanDocument(
  documentType: DocumentType.document,
  processingOptions: customOptions,
);
```

## Multi-Page Features

### Page Management
- **Add Pages**: Continue scanning additional pages seamlessly
- **Page Thumbnails**: Visual grid view of all scanned pages
- **Page Preview**: Fullscreen preview with zoom and navigation
- **Delete Pages**: Remove unwanted pages from the document
- **Reorder Pages**: Drag and drop to change page order

### Processing Options
- **Individual Processing**: Each page processed with same settings
- **Batch Processing**: Efficient processing of multiple pages
- **Unified PDF**: All pages combined into single optimized PDF
- **Metadata Preservation**: Page numbers, scan times, and processing info

### UI Components
```dart
// Multi-page scanner with full page management
MultiPageScannerWidget(
  documentType: DocumentType.manual,
  processingOptions: DocumentProcessingOptions.manual,
  onScanComplete: (result) {
    // Handle completed multi-page document
  },
)
```

## Document Types

### Receipt Processing
- **Grayscale conversion** for better text readability
- **Background removal** for clean, professional appearance
- **High contrast** enhancement for faded receipts
- **Automatic cropping** to document boundaries
- **Multi-page support** for long receipts

### Manual Processing
- **Color preservation** for diagrams and illustrations
- **QR code support** for automatic download
- **URL validation** and metadata extraction
- **Multi-page support** for complex instruction manuals
- **Chapter organization** with page management

### Document Processing
- **Balanced processing** for general documents
- **Perspective correction** for angled scans
- **Adaptive processing** based on content type
- **Multi-page support** for contracts, forms, reports

## File Naming Convention

The package uses a structured naming convention:
- **Single Page**: `YYYY-MM-DD_Brand_Model_Receipt.pdf`
- **Multi-Page**: `YYYY-MM-DD_Brand_Model_Manual_5pages.pdf`
- **Custom Names**: `CustomName_Receipt.pdf`

## Storage Structure

Documents are stored in external storage for safety:
- **Android**: `/storage/emulated/0/Documents/RobaMia/`
- **iOS**: App documents directory
- **Organization**: Automatic folder creation and file management

## Multi-Page Session Management

```dart
// Create a multi-page session
final session = MultiPageScanSession(
  sessionId: 'unique_session_id',
  documentType: DocumentType.manual,
  processingOptions: DocumentProcessingOptions.manual,
  startTime: DateTime.now(),
);

// Add pages progressively
session = session.addPage(scannedPage1);
session = session.addPage(scannedPage2);

// Reorder pages
session = session.reorderPages(reorderedPageList);

// Convert to final document
final finalDocument = session.toScannedDocument();
```

## Permissions

The package requires the following permissions:

### Android
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS
```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan documents</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to import documents</string>
```

## Architecture

```
DocumentScannerService
├── ImageProcessor (cropping, filtering, enhancement)
├── PdfGenerator (single & multi-page PDF creation)
├── QRScannerService (QR scanning and manual download)
├── DocumentScannerWidget (single page UI)
└── MultiPageScannerWidget (multi-page UI with management)
```

## API Reference

### DocumentScannerService
- `scanDocument()` - Scan single page with camera
- `importDocument()` - Import single page from gallery
- `scanQRCode()` - Scan QR code for manual download
- `downloadManualFromUrl()` - Download manual from URL

### Multi-Page Classes
- `MultiPageScanSession` - Manages progressive scanning workflow
- `DocumentPage` - Represents individual pages in multi-page documents
- `MultiPageScannerWidget` - Complete UI for multi-page scanning

### DocumentProcessingOptions
- `convertToGrayscale` - Convert to grayscale
- `enhanceContrast` - Enhance contrast
- `autoCorrectPerspective` - Auto-correct perspective
- `removeBackground` - Remove background
- `compressionQuality` - JPEG compression quality
- `generatePdf` - Generate PDF output

### DocumentType
- `receipt` - Receipt processing (supports multi-page)
- `manual` - Manual processing (optimized for multi-page)
- `document` - General document processing
- `other` - Custom processing

## Multi-Page Best Practices

1. **Page Order**: Scan pages in the desired final order when possible
2. **Consistent Lighting**: Maintain consistent lighting across all pages
3. **Quality Check**: Preview each page before adding the next
4. **Page Limits**: Consider device memory when scanning many pages
5. **Error Handling**: Always handle scan failures gracefully

## Performance Considerations

- **Memory Management**: Pages are processed individually to minimize memory usage
- **Background Processing**: Image processing happens off the main thread
- **Progressive Loading**: Thumbnail generation is optimized for performance
- **Storage Optimization**: PDF compression reduces file sizes significantly

## Example App

The package includes an example app demonstrating all features:

```bash
cd example
flutter run
```

## Contributing

This package is designed to be reusable across multiple projects. When contributing:

1. Keep the API framework-agnostic
2. Add comprehensive tests for both single and multi-page functionality
3. Update documentation with examples
4. Follow Flutter package conventions
5. Test multi-page workflows thoroughly

## License

This package is open source and available under the MIT License.

---

### Multi-Page Scanning Demo

**Workflow Example:**
1. Tap "Scan First Page" → Camera opens
2. Scan page → Auto-processed and added to session
3. Tap "Add Page" → Scan additional pages
4. View thumbnail grid → Preview, reorder, or delete pages
5. Tap "Done" → All pages combined into single PDF

This multi-page capability makes the package perfect for scanning complex documents like instruction manuals, contracts, reports, and multi-page receipts.