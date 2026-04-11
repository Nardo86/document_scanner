# Changelog

## 2.2.0

### Fixed
- **Tests**: rewrote `document_scanner_service_test.dart` to stub
  `processImageWithAutoCrop` (the actual method called by the refactored
  pipeline); added missing mock methods (`processImageWithAutoCrop`,
  `clearEdgeCache`, `dispose`) to generated mocks file; added
  `importDocumentWithProcessing` test group (15 test cases total).
- **CI**: removed `continue-on-error: true` from the test step in
  `build-and-release.yml` so test failures now block releases.

### Refactored
- **DocumentScannerService**: eliminated code duplication between scan/import
  methods via unified `_captureAndProcess` pipeline; removed all `print()`
  debugging statements; improved ID generation (microseconds).
- **ImageProcessingIsolateService**: extracted magic numbers to named constants;
  cleaned up misleading "isolate" comments; simplified fallback chain.
- **ImageProcessor**: reduced from 1021 to ~700 lines; replaced `luminanceMap`
  HashMap with flat `Float64List`; extracted all threshold / dimension constants;
  improved fallback corners to use actual image dimensions; consolidated WebP
  fallback.
- **StorageHelper**: replaced hardcoded `/storage/emulated/0/Documents` path
  with `path_provider` lookup; added `_ensureDirectory` helper.
- **CameraService**: extracted `_captureMaxLongEdge` and `_resizeJpegQuality`
  constants.
- **QRScannerService**: cleaned up `scanQRCode()` docs; removed dead comment.

### Removed
- Spurious `tatus` file (accidental `git log` output).
- RobaMia-specific documentation files:
  `CRITICAL_BUG_SOLUTION.md`, `ROBAMIA_INTEGRATION_EXAMPLE.md`,
  `IMPLEMENTATION_SUMMARY.md`, `PDF_GENERATOR_ENHANCEMENTS.md`.
- All `print()` / emoji debug statements from production code.
- Internal development files: `Agents.md`, `CONTRIBUTING.md`, `test/README.md`.

### Added
- `analysis_options.yaml` with `flutter_lints` rules.

### Documentation
- Complete README rewrite for publication readiness.
- Added CHANGELOG.md.

## 2.1.1

- Fix: version alignment across pubspec.yaml and README.

## 2.1.0

### Added
- Auto-crop pipeline: Canny edge detection, dilation, contour extraction,
  perspective warp with confidence scoring and bounding-box fallback.
- Tab-driven example app with Quick Scan, Multi Scan, and Lab screens.
- PDF preview widget using `pdfx` for native rendering.
- Image editing quick-action flow via `showImageEditorFlow()`.
- Improved B&W filter (Otsu's method) and Enhanced filter (CLAHE-inspired
  histogram equalization).
- 90-degree rotation enforcement in image editor.

## 2.0.0

### Added
- Complete architecture rewrite with separated services.
- `CameraService` for camera/gallery with automatic image resizing.
- `ImageProcessingIsolateService` for background processing.
- `StorageHelper` for configurable external storage.
- `PdfGenerator` with format, DPI, and metadata support.
- Multi-page scanning sessions with `MultiPageScanSession`.
- `scanDocumentWithProcessing()` / `importDocumentWithProcessing()` methods.
- `autoProcess` parameter for backward-compatible direct processing.
- Performance optimisation: 20s -> < 3s processing pipeline.
- 51 unit and widget tests.
