import 'dart:typed_data';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Result of a camera/gallery capture operation
class CaptureResult {
  final bool success;
  final Uint8List? imageData;
  final String? path;
  final String? error;
  final bool cancelled;
  final ImageResizeInfo? resizeInfo;

  const CaptureResult({
    required this.success,
    this.imageData,
    this.path,
    this.error,
    this.cancelled = false,
    this.resizeInfo,
  });

  factory CaptureResult.success({
    required Uint8List imageData,
    required String path,
    ImageResizeInfo? resizeInfo,
  }) {
    return CaptureResult(
      success: true,
      imageData: imageData,
      path: path,
      resizeInfo: resizeInfo,
    );
  }

  factory CaptureResult.error(String error) {
    return CaptureResult(success: false, error: error);
  }

  factory CaptureResult.cancelled() {
    return const CaptureResult(success: false, cancelled: true);
  }
}

/// Information about image resizing performed during capture
class ImageResizeInfo {
  final int originalWidth;
  final int originalHeight;
  final int resizedWidth;
  final int resizedHeight;
  final double resizeRatio;

  const ImageResizeInfo({
    required this.originalWidth,
    required this.originalHeight,
    required this.resizedWidth,
    required this.resizedHeight,
    required this.resizeRatio,
  });

  Map<String, dynamic> toMetadata() {
    return {
      'originalWidth': originalWidth,
      'originalHeight': originalHeight,
      'resizedWidth': resizedWidth,
      'resizedHeight': resizedHeight,
      'resizeRatio': resizeRatio,
    };
  }
}

/// Maximum long-edge dimension for captured/imported images.
const int _captureMaxLongEdge = 2000;

/// JPEG quality used when re-encoding resized images.
const int _resizeJpegQuality = 95;

/// Service for handling camera and gallery operations.
/// Wraps permission handling and image capture.
class CameraService {
  final ImagePicker _imagePicker;

  CameraService({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  /// Check if camera permission is granted
  Future<bool> hasCameraPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Whether a storage permission is required/granted.
  ///
  /// The library writes to scoped, app-specific storage and imports via
  /// `image_picker`, neither of which needs a runtime storage permission on
  /// modern Android or iOS. Always true; kept for API compatibility.
  Future<bool> hasStoragePermission() async => true;

  /// Request camera permission.
  ///
  /// Returns false (without prompting) when permanently denied so callers can
  /// direct the user to app settings via [openAppSettings].
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied || status.isRestricted) return false;
    final result = await Permission.camera.request();
    return result.isGranted;
  }

  /// Request storage permission.
  ///
  /// No-op (returns true): scoped storage needs no runtime permission. Kept so
  /// existing call sites continue to compile.
  Future<bool> requestStoragePermission() async => true;

  /// Capture image from camera
  /// Returns CaptureResult with image data and path
  Future<CaptureResult> captureFromCamera({int imageQuality = 95}) async {
    try {
      final hasPermission = await requestCameraPermission();
      if (!hasPermission) {
        return CaptureResult.error('Camera permission denied');
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: imageQuality,
      );

      if (image == null) {
        return CaptureResult.cancelled();
      }

      final imageData = await image.readAsBytes();
      final (resizedImageData, resizeInfo) = _resizeImageIfNeeded(imageData);
      return CaptureResult.success(
        imageData: resizedImageData,
        path: image.path,
        resizeInfo: resizeInfo,
      );
    } catch (e) {
      return CaptureResult.error('Failed to capture from camera: $e');
    }
  }

  /// Import image from gallery
  /// Returns CaptureResult with image data and path
  Future<CaptureResult> importFromGallery({int imageQuality = 95}) async {
    try {
      final hasPermission = await requestStoragePermission();
      if (!hasPermission) {
        return CaptureResult.error('Storage permission denied');
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: imageQuality,
      );

      if (image == null) {
        return CaptureResult.cancelled();
      }

      final imageData = await image.readAsBytes();
      final (resizedImageData, resizeInfo) = _resizeImageIfNeeded(imageData);
      return CaptureResult.success(
        imageData: resizedImageData,
        path: image.path,
        resizeInfo: resizeInfo,
      );
    } catch (e) {
      return CaptureResult.error('Failed to import from gallery: $e');
    }
  }

  /// Check and request both camera and storage permissions
  Future<bool> requestAllPermissions() async {
    final cameraGranted = await requestCameraPermission();
    final storageGranted = await requestStoragePermission();
    return cameraGranted && storageGranted;
  }

  /// Resize image so that the long edge is at most [_captureMaxLongEdge] px.
  (Uint8List, ImageResizeInfo) _resizeImageIfNeeded(Uint8List imageData) {
    final image = img.decodeImage(imageData);
    if (image == null) {
      return (
        imageData,
        const ImageResizeInfo(
          originalWidth: 0,
          originalHeight: 0,
          resizedWidth: 0,
          resizedHeight: 0,
          resizeRatio: 1.0,
        ),
      );
    }

    final origW = image.width;
    final origH = image.height;
    final maxDim = math.max(origW, origH);

    if (maxDim <= _captureMaxLongEdge) {
      final jpegData = img.encodeJpg(image, quality: _resizeJpegQuality);
      return (
        jpegData,
        ImageResizeInfo(
          originalWidth: origW,
          originalHeight: origH,
          resizedWidth: origW,
          resizedHeight: origH,
          resizeRatio: 1.0,
        ),
      );
    }

    final ratio = _captureMaxLongEdge / maxDim;
    final newW = (origW * ratio).round();
    final newH = (origH * ratio).round();

    final resized = img.copyResize(
      image,
      width: newW,
      height: newH,
      interpolation: img.Interpolation.average,
    );

    final resizedData = img.encodeJpg(resized, quality: _resizeJpegQuality);
    return (
      resizedData,
      ImageResizeInfo(
        originalWidth: origW,
        originalHeight: origH,
        resizedWidth: newW,
        resizedHeight: newH,
        resizeRatio: ratio,
      ),
    );
  }
}
