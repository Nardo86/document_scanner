# Contributing to Document Scanner

Thank you for your interest in contributing to the document_scanner package! This guide will help you get started with contributing to this open-source project.

## 🚀 Quick Start

### Prerequisites
- Flutter 3.0+ SDK
- Dart SDK compatible with your Flutter version
- Git for version control
- A code editor (VS Code, Android Studio, or IntelliJ IDEA)
- Physical Android/iOS device for testing camera features

### Initial Setup

1. **Fork the Repository**
   ```bash
   # Fork the repository on GitHub, then clone your fork
   git clone https://github.com/yourusername/document_scanner.git
   cd document_scanner
   ```

2. **Set Up Development Environment**
   ```bash
   # Install dependencies
   flutter pub get
   
   # Install development dependencies
   flutter pub dev_dependencies
   
   # Generate mocks (if needed)
   flutter pub run build_runner build --delete-conflicting-outputs
   
   # Run tests to verify setup
   flutter test
   ```

3. **Run the Example App**
   ```bash
   cd example
   flutter pub get
   flutter run
   ```

## 📋 Development Workflow

### 1. Create a Branch
```bash
# Create a descriptive branch name
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

### 2. Make Your Changes
- Follow the existing code style and patterns
- Add tests for new functionality
- Update documentation as needed
- Ensure all tests pass

### 3. Test Your Changes
```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run integration tests
flutter test integration_test/

# Check code formatting
flutter format --set-exit-if-changed .

# Run static analysis
flutter analyze
```

### 4. Commit Your Changes
```bash
# Stage your changes
git add .

# Commit with a descriptive message
git commit -m "feat: add OCR integration for automatic text extraction"
```

### 5. Push and Create Pull Request
```bash
# Push to your fork
git push origin feature/your-feature-name

# Create a pull request on GitHub
```

## 🏗️ Project Architecture

### Directory Structure
```
document_scanner/
├── lib/
│   ├── src/
│   │   ├── models/          # Data models and classes
│   │   ├── services/        # Core business logic
│   │   ├── ui/             # UI widgets and components
│   │   └── utils/          # Utility functions
│   └── document_scanner.dart  # Main library export
├── example/                 # Example application
├── test/                   # Unit and widget tests
├── integration_test/       # Integration tests
└── docs/                   # Additional documentation
```

### Key Components

#### Services
- **DocumentScannerService**: Main orchestrator for scanning operations
- **CameraService**: Camera and gallery integration
- **ImageProcessor**: Image processing and filtering
- **PdfGenerator**: PDF creation and management
- **QRScannerService**: QR code scanning functionality
- **StorageHelper**: File storage and management

#### Models
- **ScannedDocument**: Represents a scanned document
- **ScanResult**: Result of scanning operations
- **DocumentProcessingOptions**: Configuration for processing
- **MultiPageScanSession**: Multi-page scanning state

#### UI Components
- **DocumentScannerWidget**: Single-page scanning interface
- **MultiPageScannerWidget**: Multi-page scanning interface
- **ImageEditingWidget**: Image editing and enhancement
- **PdfPreviewWidget**: PDF preview and review

## 🧪 Testing Guidelines

### Test Structure
- **Unit Tests**: Test individual classes and functions
- **Widget Tests**: Test UI components in isolation
- **Integration Tests**: Test complete user workflows

### Writing Tests

#### Unit Tests
```dart
// test/services/document_scanner_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:document_scanner/document_scanner.dart';

class MockCameraService extends Mock implements CameraService {}

void main() {
  group('DocumentScannerService', () {
    late DocumentScannerService service;
    late MockCameraService mockCameraService;

    setUp(() {
      mockCameraService = MockCameraService();
      service = DocumentScannerService(cameraService: mockCameraService);
    });

    test('should scan document successfully', () async {
      // Arrange
      when(mockCameraService.captureImage())
          .thenAnswer((_) async => CaptureResult.success(mockImageData));

      // Act
      final result = await service.scanDocument(
        documentType: DocumentType.receipt,
      );

      // Assert
      expect(result.success, true);
      verify(mockCameraService.captureImage()).called(1);
    });
  });
}
```

#### Widget Tests
```dart
// test/ui/document_scanner_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/document_scanner.dart';

void main() {
  testWidgets('DocumentScannerWidget should render correctly', (tester) async {
    // Arrange
    bool scanCompleted = false;

    // Act
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentScannerWidget(
            documentType: DocumentType.receipt,
            onScanComplete: (result) {
              scanCompleted = true;
            },
          ),
        ),
      ),
    );

    // Assert
    expect(find.byType(DocumentScannerWidget), findsOneWidget);
    expect(find.text('Scan Document'), findsOneWidget);
  });
}
```

### Test Coverage
- Aim for >80% code coverage
- Test all public APIs
- Test error conditions and edge cases
- Test platform-specific behavior

## 📝 Code Style & Conventions

### Dart/Flutter Standards
- Follow official [Flutter style guide](https://flutter.dev/docs/development/tools/formatting)
- Use `flutter format` for code formatting
- Use `flutter analyze` for static analysis
- Follow effective Dart guidelines

### Naming Conventions
- **Classes**: PascalCase (e.g., `DocumentScannerService`)
- **Methods**: camelCase (e.g., `scanDocument`)
- **Variables**: camelCase (e.g., `documentType`)
- **Constants**: SCREAMING_SNAKE_CASE (e.g., `DEFAULT_COMPRESSION_QUALITY`)
- **Files**: snake_case (e.g., `document_scanner_service.dart`)

### Documentation
- Use dartdoc comments for all public APIs
- Include parameter descriptions and return value details
- Provide usage examples for complex methods
- Document edge cases and error conditions

```dart
/// Scans a document using the device camera.
/// 
/// [documentType] specifies the type of document being scanned.
/// [processingOptions] controls how the image is processed.
/// [customFilename] allows overriding the default filename.
/// 
/// Returns a [ScanResult] containing the scanned document or error information.
/// 
/// Example:
/// ```dart
/// final result = await DocumentScannerService().scanDocument(
///   documentType: DocumentType.receipt,
///   processingOptions: DocumentProcessingOptions.receipt,
/// );
/// ```
Future<ScanResult> scanDocument({
  required DocumentType documentType,
  DocumentProcessingOptions? processingOptions,
  String? customFilename,
}) async {
  // Implementation
}
```

## 🐛 Bug Reports

### Reporting Bugs
1. **Use GitHub Issues**: Create a new issue with the "bug" label
2. **Provide Detailed Information**:
   - Flutter and Dart versions
   - Device/emulator information
   - Steps to reproduce
   - Expected vs actual behavior
   - Error messages and stack traces
   - Screenshots if applicable

### Bug Report Template
```markdown
## Bug Description
A clear and concise description of the bug.

## Steps to Reproduce
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

## Expected Behavior
A clear and concise description of what you expected to happen.

## Actual Behavior
A clear and concise description of what actually happened.

## Environment
- Flutter version: ...
- Dart version: ...
- Device: ...
- OS version: ...

## Additional Context
Add any other context about the problem here.
```

## 💡 Feature Requests

### Requesting Features
1. **Use GitHub Issues**: Create a new issue with the "enhancement" label
2. **Describe the Use Case**: Explain why this feature is needed
3. **Propose a Solution**: Suggest how the feature should work
4. **Consider Alternatives**: Discuss alternative approaches

### Feature Request Template
```markdown
## Feature Description
A clear and concise description of the feature you'd like to see added.

## Use Case
Describe the problem this feature would solve or the benefit it would provide.

## Proposed Solution
Describe how you envision this feature working.

## Alternatives Considered
Describe any alternative solutions or approaches you've considered.

## Additional Context
Add any other context, mockups, or examples about the feature request here.
```

## 🔧 Development Tips

### Debugging
- Use `debugPrint()` for debugging output
- Leverage Flutter DevTools for profiling
- Test on both Android and iOS devices
- Use physical devices for camera testing

### Performance
- Profile memory usage during image processing
- Optimize image sizes and compression
- Use background processing for heavy operations
- Monitor app startup time

### Platform-Specific Considerations
- **Android**: Test on various API levels and device manufacturers
- **iOS**: Test on different iOS versions and device sizes
- **Permissions**: Handle camera and storage permissions gracefully

## 📚 Resources

### Documentation
- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language Guide](https://dart.dev/guides)
- [Effective Dart](https://dart.dev/guides/language/effective-dart)

### Tools
- [Flutter DevTools](https://flutter.dev/docs/development/tools/devtools/overview)
- [Android Studio](https://developer.android.com/studio)
- [VS Code with Flutter extension](https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter)

### Community
- [Flutter Community](https://github.com/fluttercommunity)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/flutter)
- [Flutter Discord](https://discord.gg/flutter)

## 🤝 Getting Help

If you need help contributing:
1. Check existing issues and discussions
2. Read the documentation and code comments
3. Ask questions in GitHub discussions
4. Start with "good first issue" labels

## 📄 License

By contributing to this project, you agree that your contributions will be licensed under the same license as the project (MIT License).

---

Thank you for contributing to document_scanner! Your contributions help make this package better for everyone. 🙏