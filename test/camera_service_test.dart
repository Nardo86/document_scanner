import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:document_scanner/src/services/camera_service.dart';

@GenerateMocks([ImagePicker])
import 'camera_service_test.mocks.dart';

class TestCameraService extends CameraService {
  bool cameraPermissionGranted;
  bool storagePermissionGranted;

  TestCameraService({
    required ImagePicker imagePicker,
    this.cameraPermissionGranted = true,
    this.storagePermissionGranted = true,
  }) : super(imagePicker: imagePicker);

  @override
  Future<bool> requestCameraPermission() async => cameraPermissionGranted;

  @override
  Future<bool> requestStoragePermission() async => storagePermissionGranted;
}

/// Creates a minimal valid JPEG in a temp file and returns the [XFile].
/// The caller is responsible for deleting the file after use.
XFile _createTempImageFile(String suffix) {
  final image = img.Image(width: 10, height: 10);
  img.fill(image, color: img.ColorRgb8(255, 0, 0));
  final jpegBytes = Uint8List.fromList(img.encodeJpg(image, quality: 80));

  final tmpFile = File(
    '${Directory.systemTemp.path}/camera_service_test_$suffix.jpg',
  );
  tmpFile.writeAsBytesSync(jpegBytes);
  return XFile(tmpFile.path);
}

void main() {
  late MockImagePicker mockImagePicker;
  late TestCameraService cameraService;

  setUp(() {
    mockImagePicker = MockImagePicker();
    cameraService = TestCameraService(imagePicker: mockImagePicker);
  });

  group('CameraService - captureFromCamera', () {
    test(
      'returns success result with image data on successful capture',
      () async {
        final mockXFile = _createTempImageFile('camera_success');

        when(
          mockImagePicker.pickImage(
            source: ImageSource.camera,
            imageQuality: 95,
          ),
        ).thenAnswer((_) async => mockXFile);

        final result = await cameraService.captureFromCamera();

        expect(result.success, true);
        expect(result.imageData, isNotNull);
        expect(result.path, mockXFile.path);
        expect(result.cancelled, false);

        File(mockXFile.path).deleteSync();
      },
    );

    test('returns cancelled result when user cancels capture', () async {
      when(
        mockImagePicker.pickImage(source: ImageSource.camera, imageQuality: 95),
      ).thenAnswer((_) async => null);

      final result = await cameraService.captureFromCamera();

      expect(result.success, false);
      expect(result.cancelled, true);
      expect(result.imageData, isNull);
    });

    test('returns error result when capture fails', () async {
      when(
        mockImagePicker.pickImage(source: ImageSource.camera, imageQuality: 95),
      ).thenThrow(Exception('Camera access failed'));

      final result = await cameraService.captureFromCamera();

      expect(result.success, false);
      expect(result.error, contains('Failed to capture from camera'));
    });
  });

  group('CameraService - importFromGallery', () {
    test(
      'returns success result with image data on successful import',
      () async {
        final mockXFile = _createTempImageFile('gallery_success');

        when(
          mockImagePicker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 95,
          ),
        ).thenAnswer((_) async => mockXFile);

        final result = await cameraService.importFromGallery();

        expect(result.success, true);
        expect(result.imageData, isNotNull);
        expect(result.path, mockXFile.path);

        File(mockXFile.path).deleteSync();
      },
    );

    test('returns cancelled result when user cancels import', () async {
      when(
        mockImagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 95,
        ),
      ).thenAnswer((_) async => null);

      final result = await cameraService.importFromGallery();

      expect(result.success, false);
      expect(result.cancelled, true);
    });

    test('returns error result when import fails', () async {
      when(
        mockImagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 95,
        ),
      ).thenThrow(Exception('Gallery access failed'));

      final result = await cameraService.importFromGallery();

      expect(result.success, false);
      expect(result.error, contains('Failed to import from gallery'));
    });
  });

  group('CameraService - custom image quality', () {
    test('uses custom image quality parameter', () async {
      final mockXFile = _createTempImageFile('custom_quality');

      when(
        mockImagePicker.pickImage(source: ImageSource.camera, imageQuality: 80),
      ).thenAnswer((_) async => mockXFile);

      await cameraService.captureFromCamera(imageQuality: 80);

      verify(
        mockImagePicker.pickImage(source: ImageSource.camera, imageQuality: 80),
      ).called(1);

      File(mockXFile.path).deleteSync();
    });
  });
}
