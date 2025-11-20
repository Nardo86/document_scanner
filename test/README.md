# Test Coverage

This directory contains comprehensive tests for the Document Scanner package, focusing on service-level testing with mocks and fakes.

## Test Files

### 1. camera_service_test.dart
Tests the `CameraService` class which handles permission handling and camera/gallery capture operations.

**Coverage:**
- ✅ Successful camera capture with image data
- ✅ User cancellation during capture
- ✅ Camera access failures
- ✅ Gallery import success
- ✅ Gallery import cancellation
- ✅ Gallery import failures
- ✅ Custom image quality parameter handling

### 2. storage_helper_test.dart
Tests the `StorageHelper` class which manages file storage operations and file naming.

**Coverage:**
- ✅ Filename generation with custom names
- ✅ Filename generation from metadata (suggestedFilename, product brand/model)
- ✅ Timestamp-based filename fallback
- ✅ Invalid character cleaning in filenames
- ✅ Document type suffix generation (Receipt, Manual, Document, Scan)
- ✅ Image file saving
- ✅ PDF file saving
- ✅ Saving both image and PDF files
- ✅ Selective file saving (image-only or PDF-only)
- ✅ Custom directory configuration
- ✅ Directory creation when not exists

### 3. document_scanner_service_test.dart
Tests the `DocumentScannerService` orchestrator which coordinates all scanning operations.

**Coverage:**

#### Basic Scanning Operations:
- ✅ Successful document scan with capture
- ✅ User cancellation handling
- ✅ Permission denial (camera permission denied)
- ✅ Auto-processing when enabled
- ✅ Gallery import success
- ✅ Gallery import cancellation

#### Processing Workflows:
- ✅ Full processing pipeline (scan + process + save)
- ✅ Automatic PDF generation
- ✅ Image processing integration
- ✅ Error propagation through pipeline

#### Storage Configuration:
- ✅ Custom storage directory configuration
- ✅ Custom app name configuration
- ✅ Storage helper configuration propagation

#### Finalization:
- ✅ Scan result finalization with PDF generation
- ✅ External storage saving
- ✅ Metadata preservation during finalization

#### Multi-Page Workflows:
- ✅ Multi-page session finalization
- ✅ Combining pages into single PDF
- ✅ Page metadata preservation
- ✅ Empty session rejection (no pages)
- ✅ Storage permission check during finalization
- ✅ Multi-page document metadata (page count, session info)

## Test Coverage Summary

The test suite covers the following critical scenarios as specified in the ticket:

### ✅ Permission Denial
- Camera permission denial during capture
- Storage permission denial during processing
- Permission checks in multi-page finalization

### ✅ Capture Failure
- Camera hardware failures
- User cancellations
- Gallery import failures
- Image processing failures
- PDF generation failures

### ✅ Storage Overrides
- Custom storage directory configuration
- Custom app name configuration
- Custom filename handling
- Metadata-driven file naming

### ✅ Multi-Page Finalization
- Successful multi-page PDF generation
- Empty session handling
- Invalid page data handling
- Permission checks
- Metadata preservation

## Running Tests

### Run all tests:
```bash
flutter test
```

### Run specific test file:
```bash
flutter test test/camera_service_test.dart
flutter test test/storage_helper_test.dart
flutter test test/document_scanner_service_test.dart
```

### Generate test coverage:
```bash
flutter test --coverage
```

## Test Architecture

The tests use **Mockito** for mocking dependencies and follow these patterns:

1. **Service Isolation**: Each service is tested in isolation with mocked dependencies
2. **Mock Generation**: Mocks are generated using `@GenerateMocks` annotation
3. **Test Organization**: Tests are grouped by functionality using `group()` blocks
4. **Comprehensive Coverage**: Each test covers both success and failure scenarios

## Dependencies

- `flutter_test`: Flutter testing framework
- `mockito`: Mocking framework for Dart
- `build_runner`: Code generation for mocks

## Generating Mocks

After adding new mock annotations, run:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This will generate `.mocks.dart` files for the test files.
