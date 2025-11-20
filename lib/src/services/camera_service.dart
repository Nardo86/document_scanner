import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Result of a camera/gallery capture operation
class CaptureResult {
  final bool success;
  final Uint8List? imageData;
  final String? path;
  final String? error;
  final bool cancelled;

  const CaptureResult({
    required this.success,
    this.imageData,
    this.path,
    this.error,
    this.cancelled = false,
  });

  factory CaptureResult.success({
    required Uint8List imageData,
    required String path,
  }) {
    return CaptureResult(
      success: true,
      imageData: imageData,
      path: path,
    );
  }

  factory CaptureResult.error(String error) {
    return CaptureResult(
      success: false,
      error: error,
    );
  }

  factory CaptureResult.cancelled() {
    return const CaptureResult(
      success: false,
      cancelled: true,
    );
  }
}

/// Service for handling camera and gallery operations
/// Wraps permission handling and image capture
class CameraService {
  final ImagePicker _imagePicker;

  CameraService({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  /// Check if camera permission is granted
  Future<bool> hasCameraPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Check if storage permission is granted
  Future<bool> hasStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.status;
      return status.isGranted;
    }
    return true; // iOS doesn't need explicit storage permission
  }

  /// Request camera permission
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isDenied) {
      final result = await Permission.camera.request();
      return result.isGranted;
    }
    return status.isGranted;
  }

  /// Request storage permission
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.status;
      if (status.isDenied) {
        final result = await Permission.manageExternalStorage.request();
        return result.isGranted;
      }
      return status.isGranted;
    }
    return true; // iOS doesn't need explicit storage permission
  }

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
      return CaptureResult.success(
        imageData: imageData,
        path: image.path,
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
      return CaptureResult.success(
        imageData: imageData,
        path: image.path,
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
}
