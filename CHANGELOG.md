# Changelog

## 3.0.0

Major remediation release. Establishes a single, correct version line (the
earlier `1.x` tags and the never-tagged/withdrawn `2.x` line are superseded).
**This release contains breaking API changes — see [MIGRATION.md](MIGRATION.md).**

### Breaking changes
- Renamed the public enum `ColorFilter` → `DocumentColorFilter` to stop colliding
  with Flutter's `dart:ui`/`material` `ColorFilter`.
- The barrel (`package:document_scanner/document_scanner.dart`) now exports only
  the intended public surface (models, `ScanResult`, `DocumentScannerService`,
  `QRScannerService`, and the widgets). Internal services
  (`ImageProcessor`, `StorageHelper`, `PdfGenerator`,
  `ImageProcessingIsolateService`, `CameraService`) are no longer exported.
- `DocumentScannerService` is no longer a hard singleton: `DocumentScannerService()`
  now creates an independent instance with its own storage config. Use
  `DocumentScannerService.instance` for a shared instance. Widgets accept an
  optional `service:` to target a specific instance.
- `DocumentScannerService.scanQRCode(...)` and `scanQRCodeAndDownload(...)` now
  require a `BuildContext` (they present the scanner UI).
- Storage now uses **scoped, app-specific** storage by default; the
  `MANAGE_EXTERNAL_STORAGE` permission is no longer used or required.

### Security
- `downloadManualFromUrl` is hardened: HTTPS-only by default (opt-in cleartext),
  streamed download with a configurable size cap (DoS guard), request timeout,
  SSRF guard rejecting private/loopback/link-local hosts, per-hop redirect
  re-validation, and payload validation by magic bytes (not just Content-Type).
- Filenames (`customFilename`, `suggestedFilename`, brand/model) are sanitized
  to a safe basename and writes are asserted to stay within the target
  directory (path-traversal fix).

### Fixed
- **Auto-crop** (`AutoCropper`) rewritten around a correct Otsu white-blob
  detector with a real homography + bilinear perspective warp. Removed the
  broken Canny/contour fallback (shared-`List.filled` row aliasing, unbounded
  recursion, fake 2-corner affine "perspective", and an unrealistic 100 ms
  timeout that made auto-crop a silent no-op). Failures now return the original
  image explicitly instead of pretending to crop.
- **Image editor** (`ImageEditingWidget`) rewritten with a declarative state
  model rendered from the original image each time. Resolves issues
  #30/#31/#32: rotation keeps the crop tool available and re-detects edges in
  the new orientation; reset-crop is reliable (no double-rotation); changing the
  document format no longer auto-commits a crop; switching filters no longer
  compounds; cumulative JPEG re-encoding is eliminated.
- Document-edge detection now actually runs the detector off the UI thread
  (previously always returned empty, forcing a proportional fallback).
- Lifecycle/leak fixes: `mounted` guards before post-`await` `setState`;
  `PdfController` is disposed; `Image.memory` has `errorBuilder`; multi-page
  finalize no longer force-unwraps missing page data; empty `pdfPath` no longer
  spins forever; page ids are monotonic so reorder keys stay unique.
- `DocumentProcessingOptions.toJson`/`fromJson` now round-trips `documentFormat`.
- PDF generation preserves image aspect ratio (no `BoxFit.fill` distortion).

### Changed
- Image processing (decode/detect/warp/encode) runs in a background isolate via
  `compute`; `ImageProcessingIsolateService` now matches its name.

### Build / tooling
- Single source of truth for the version across `pubspec.yaml`, README and this
  changelog, matching the `v3.0.0` tag.
- Dependencies: removed unused `printing` and `file_picker`; bumped `camera` to
  `^0.12.0+1`; fixed the contradictory environment constraint
  (`flutter: ">=3.32.0"` to match `sdk: ^3.8.1`); aligned example `flutter_lints`.
- CI: added a PR/branch `ci.yml` (format, analyze, test, `pub publish --dry-run`,
  pana), regenerate mocks via `build_runner`, assert tag == pubspec version on
  release, and `dependabot.yml` for actions/pub. Package `pubspec.lock` is no
  longer committed.

### Tests
- Added real coverage: auto-crop accuracy on a synthetic sheet, download
  security (SSRF/size-cap/magic-byte/cleartext), filename path-traversal, model
  JSON round-trip, and real PDF (`%PDF`) output assertions.

---

## 1.2.0
- Guided camera screen with a draggable A4 trapezoid overlay; the guide corners
  drive a perspective warp before the editor.

## 1.1.x
- Smart auto-crop groundwork, reset-crop button, rotation/crop reworks
  (issues #30/#31/#32 — fully resolved in 3.0.0).

## 1.0.0
- Initial public line: camera/gallery scan, image editor (rotate/crop/filters),
  PDF generation, multi-page sessions, QR scanning + manual download, configurable
  external storage.
