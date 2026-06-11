# Migration guide

## → 3.0.0 (from 1.x / 2.x)

`3.0.0` is a breaking release. Update your `pubspec.yaml` ref and apply the
changes below.

```yaml
dependencies:
  document_scanner:
    git:
      url: https://github.com/Nardo86/document_scanner.git
      ref: v3.0.0
```

### 1. `ColorFilter` → `DocumentColorFilter`
The public enum was renamed to avoid colliding with Flutter's `ColorFilter`.

```dart
// before
ColorFilter.blackAndWhite
// after
DocumentColorFilter.blackAndWhite
```
Most apps never referenced this enum directly and need no change.

### 2. Trimmed public API (barrel exports)
Internal services are no longer exported: `ImageProcessor`, `StorageHelper`,
`PdfGenerator`, `ImageProcessingIsolateService`, `CameraService`.
If you imported any of these, refactor to use `DocumentScannerService` (and the
widgets / `QRScannerService`) instead. `PdfPreviewWidget`, `ImageEditingWidget`,
`DocumentScannerWidget`, `MultiPageScannerWidget`, `DocumentCameraScreen` and
`QRScannerService` remain public.

### 3. `DocumentScannerService` is no longer a global singleton
`DocumentScannerService()` now returns a **new** instance with its own storage
configuration.

```dart
// before — the call returned a shared singleton
DocumentScannerService().configureStorage(appName: 'MyApp');
final r = await DocumentScannerService().scanDocument(...);

// after — use the shared instance, or pass your own to the widgets
DocumentScannerService.instance.configureStorage(appName: 'MyApp');
final r = await DocumentScannerService.instance.scanDocument(...);

// or isolate config per feature:
final svc = DocumentScannerService()..configureStorage(appName: 'Receipts');
DocumentScannerWidget(documentType: ..., onScanComplete: ..., service: svc);
```

### 4. QR scan methods need a `BuildContext`
They present the scanner UI, so they now take a context.

```dart
// before
await DocumentScannerService().scanQRCode();
await DocumentScannerService().scanQRCodeAndDownload();
// after
await DocumentScannerService.instance.scanQRCode(context);
await DocumentScannerService.instance.scanQRCodeAndDownload(context);
```
`QRScannerService().scanQRCodeWithUI(context)` is unchanged.

### 5. Storage & Android permissions
The library now writes to **scoped, app-specific** storage and needs no storage
permission. Remove these from your `AndroidManifest.xml`:

```xml
<!-- no longer needed -->
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
```
Keep `CAMERA`, `INTERNET`, and (for Android 13+ gallery import) `READ_MEDIA_IMAGES`.
If you need files in a user-visible/shared folder, pass an explicit
`customStorageDirectory` to `configureStorage` and handle that location's
permissions yourself.

### 6. Manual download is HTTPS-only by default
`downloadManualFromUrl` rejects cleartext `http://` and private/loopback hosts,
caps the response size, and validates the payload by magic bytes. To allow
cleartext (not recommended) pass `allowInsecureHttp: true`. To raise/lower the
size cap pass `maxBytes:`.

### 7. Removed dependencies
`printing` and `file_picker` were unused and removed. If your app relied on them
transitively, add them to your own `pubspec.yaml`.

### Behaviour improvements (no action required)
- Auto-crop actually detects bright sheets now and applies a real perspective
  correction; low-confidence scans return the original image.
- The editor's rotation/crop/reset/filter interactions are fixed (#30/#31/#32).
- Heavy image work runs off the UI thread.
