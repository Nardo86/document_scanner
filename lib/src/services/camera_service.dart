import 'dart:io';
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

  /// Resize image to ensure long edge is at most 2000px
  /// Returns the resized image data and resize information
  (Uint8List, ImageResizeInfo) _resizeImageIfNeeded(Uint8List imageData) {
    const maxLongEdge = 2000;
    
    // Decode image to get dimensions
    final image = img.decodeImage(imageData);
    if (image == null) {
      return (imageData, ImageResizeInfo(
        originalWidth: 0,
        originalHeight: 0,
        resizedWidth: 0,
        resizedHeight: 0,
        resizeRatio: 1.0,
      ));
    }

    final originalWidth = image.width;
    final originalHeight = image.height;
    
    // Check if resize is needed
    final maxDimension = math.max(originalWidth, originalHeight);
    if (maxDimension <= maxLongEdge) {
      // No resize needed
      final jpegData = img.encodeJpg(image, quality: 95);
      return (jpegData, ImageResizeInfo(
        originalWidth: originalWidth,
        originalHeight: originalHeight,
        resizedWidth: originalWidth,
        resizedHeight: originalHeight,
        resizeRatio: 1.0,
      ));
    }

    // Calculate new dimensions
    final resizeRatio = maxLongEdge / maxDimension;
    final newWidth = (originalWidth * resizeRatio).round();
    final newHeight = (originalHeight * resizeRatio).round();
    
    // Resize image
    final resizedImage = img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.average,
    );
    
    // Encode back to JPEG
    final resizedImageData = img.encodeJpg(resizedImage, quality: 95);
    
    return (resizedImageData, ImageResizeInfo(
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      resizedWidth: newWidth,
      resizedHeight: newHeight,
      resizeRatio: resizeRatio,
    ));
  }
}
