# `Agents.md` - Document Scanner Package

## Development Guidelines

### The Golden Rule  
When unsure about implementation details, ALWAYS ask the developer.  

## Project Context  
Document Scanner is a reusable Flutter package for document scanning with multi-page support, image processing, and PDF generation. Designed to be framework-agnostic and usable across multiple projects.

## Modern Architecture Overview

### App Shell Structure
The example app now follows a modular architecture with:
- **Bootstrap Entry Point**: `example/lib/main.dart` handles initialization and bootstraps `DocumentScannerShowcaseApp`
- **App Shell**: `example/lib/app.dart` contains the main app structure with scoped state management
- **Modular Screens**: Individual feature screens in `example/lib/screens/` directory
- **Shared State**: Centralized state management via `example/lib/state/showcase_state.dart`
- **Reusable Widgets**: Common UI components in `example/lib/widgets/` directory

### Navigation Architecture
The app uses a tab-based navigation system with prioritized scanning flows:
- **Quick Scan** (Primary): Single-page document scanning with lightning icon
- **Multi Scan** (Secondary): Multi-page document sessions with camera icon  
- **Lab** (Tertiary): Capabilities exploration and testing with science icon

Navigation is driven by an ordered enum `_ShowcaseTab` that ensures consistent ordering between `NavigationBar` destinations and `IndexedStack` children.

### State Management
- **Scoped State**: Uses `ShowcaseState` with `ShowcaseStateScope` for dependency injection
- **State Notifier Pattern**: Centralized state management for scan results and app state
- **First Scan Detection**: Conditional UI elements that appear when `_lastResult == null`

### PDF Preview Overhaul
- **Enhanced Preview Screen**: Modern PDF preview with improved navigation and controls
- **Multi-page Support**: Full support for multi-page document preview and editing
- **Streamlined Workflow**: Better integration between scanning and preview phases

### Upcoming Auto-Crop Pipeline
- **Advanced Edge Detection**: Planned automatic document boundary detection
- **Smart Cropping**: AI-powered perspective correction and cropping
- **Processing Pipeline**: Background processing for improved performance

## Code Style and Patterns  

### Anchor Comments  
Add specially formatted comments throughout the codebase for inline knowledge:  
- Use `AIDEV-NOTE:`, `AIDEV-TODO:`, or `AIDEV-QUESTION:` (all-caps prefix)
- **Always grep for existing anchors** `AIDEV-*` before scanning files  
- **Update relevant anchors** when modifying associated code  
- **Do not remove `AIDEV-NOTE`s** without explicit instruction  

### Modern Widget Patterns
- **Enum-Driven Navigation**: Use enums for consistent tab ordering and navigation
- **Helper Methods**: Separate navigation building logic from main widget structure
- **Conditional Rendering**: Use state-based conditions for UI elements like first-scan banners
- **Scoped Dependencies**: Leverage `ShowcaseStateScope` for state management

## Package Development Rules

### Documentation Requirements
- **README.md must ALWAYS be kept updated** with:
  - New features and API changes
  - Updated usage examples
  - Version compatibility information
  - File naming conventions and examples
  - Performance considerations

### Version Management & Releases

#### Tag and Release Protocol
1. **Every tag creation MUST be accompanied by a corresponding GitHub release**
2. **Release notes MUST be generated from commit messages** since last tag
3. **No separate CHANGELOG.md** - use commit messages and GitHub releases
4. **Semantic versioning** must be followed (MAJOR.MINOR.PATCH)

#### Version Increment Rules:
- **PATCH** (1.0.1): Bug fixes, small improvements, documentation updates
- **MINOR** (1.1.0): New features, new API methods, backwards-compatible changes  
- **MAJOR** (2.0.0): Breaking changes, major API restructuring

#### Version Synchronization (CRITICAL):
**ALL version numbers MUST ALWAYS be synchronized across the entire project:**
- `pubspec.yaml` (main package version) - **THIS IS THE SOURCE OF TRUTH FOR GITHUB ACTIONS**
- `example/pubspec.yaml` (example app version) 
- Git tags (v1.x.x format)
- GitHub releases
- Documentation references

**⚠️ CRITICAL BUG PREVENTION:**
The GitHub Actions workflow reads the version from the **ROOT `pubspec.yaml`** file to:
- Name the APK file: `document_scanner_example_v{VERSION}.apk`
- Create the GitHub Release title: "Document Scanner v{VERSION}"
- Generate git reference in docs: `ref: v{VERSION}`

**If the root `pubspec.yaml` version is NOT updated, the workflow will use the OLD version even if the tag is newer!**

**NEVER create tags or releases without updating ALL version numbers first!**

#### Release Process:
```bash
# 1. Ensure all changes are committed
git add . && git commit -m "Feature: description"

# 2. UPDATE ALL VERSION NUMBERS FIRST (VERIFY EACH FILE):
#    - pubspec.yaml (main package) ← CRITICAL: GitHub Actions reads THIS
#    - example/pubspec.yaml (example app) 
#    - Any documentation references
# 
# ⚠️ ALWAYS verify the main pubspec.yaml was actually updated:
grep "^version:" pubspec.yaml
git add . && git commit -m "Bump version to 1.1.0"

# 3. Push all commits to remote
git push origin main

# 4. Create and push tag ONLY (GitHub Action handles the rest)
git tag v1.1.0
git push origin v1.1.0

# 5. ✅ GitHub Action automatically:
#    - Builds APK
#    - Generates release notes from commits
#    - Creates GitHub Release
#    - Uploads APK as asset
```

#### ⚠️ CRITICAL: Let GitHub Actions Handle Releases

**DO NOT create releases manually** with `gh release create`! The project has a configured GitHub Action (`.github/workflows/build-and-release.yml`) that automatically:

1. **Triggers on tag push** (`on: push: tags: - 'v*'`)
2. **Builds the APK** from example app
3. **Generates release notes** from commit messages since last tag
4. **Creates GitHub Release** with proper title and content
5. **Uploads APK** as release asset

**Manual release creation causes conflicts** and incorrect content. Always use the tag-only approach above.

### Code Quality Standards

#### Flutter/Dart Specific
- Follow Flutter package conventions
- Use proper dependency injection patterns (scoped state)
- Implement comprehensive error handling
- Write widget tests for UI components
- Unit tests for business logic
- Integration tests for document processing

#### Modern App Architecture
- **App Shell Pattern**: Separate bootstrap logic from main app structure
- **Modular Screens**: Individual feature screens with clear responsibilities
- **State Management**: Use scoped state with proper lifecycle management
- **Navigation**: Enum-driven tab navigation with consistent ordering
- **Reusable Widgets**: Extract common UI components for maintainability

#### Service Architecture
- **DocumentScannerService**: Main API interface
- **ImageProcessor**: Image manipulation and optimization
- **PdfGenerator**: PDF creation and multi-page handling
- **QRScannerService**: QR code scanning and URL processing

### Performance Requirements
- **Memory management**: Process images individually for multi-page
- **Background processing**: Image processing off main thread
- **Progressive loading**: Optimize thumbnail generation
- **Storage optimization**: PDF compression for file size reduction

### API Design Principles
- **Framework-agnostic**: Keep core logic independent of Flutter widgets
- **Backward compatibility**: Maintain API stability within major versions
- **Extensible**: Design for easy addition of new document types
- **Error handling**: Comprehensive error types and messages

## What AI Must NEVER Do  

1. **Never modify test files** - Tests encode human intent  
2. **Never remove AIDEV- comments** - They're there for a reason
3. **Never create releases without updating README.md** - Documentation first
4. **Never create tags without updating ALL version numbers first** - ROOT pubspec.yaml is GitHub Actions source of truth
5. **Never create releases manually** - Always use GitHub Actions via tag push only
6. **Never use hardcoded file paths** - Use configurable storage locations
7. **Never ignore error handling** - Every operation must handle failures
8. **Never break backward compatibility** without major version bump
9. **Never commit without considering multi-platform compatibility**
10. **Never run Flutter commands** (flutter analyze, flutter build, flutter test, etc.) - These waste tokens, developer runs them manually and provides results

## Documentation Standards

### README.md Sections (Must Maintain):
- **Features**: Complete list with multi-page capabilities
- **Installation**: Package dependency information  
- **Usage Examples**: Single-page, multi-page, QR scanning
- **File Naming**: Complete convention with examples
- **API Reference**: All public methods and classes
- **Performance**: Memory and optimization considerations
- **Disclaimer**: Vibe-coding development notice

### Code Documentation:
- Public APIs must have comprehensive dartdoc comments
- Complex algorithms need inline explanations
- Service classes need architecture notes
- UI widgets need usage examples
- Modern architecture patterns need clear documentation

## Testing Requirements

### Required Test Coverage:
- **Unit Tests**: All service methods and business logic
- **Widget Tests**: All public UI components  
- **Integration Tests**: End-to-end document processing workflows
- **Platform Tests**: Android and iOS compatibility

### Modern Testing Patterns:
- **Navigation Tests**: Verify tab ordering and navigation behavior
- **State Management Tests**: Test scoped state and lifecycle management
- **First Scan Banner Tests**: Verify conditional UI elements
- **App Shell Tests**: Test bootstrap and initialization logic

### Test Categories:
- **Single-page scanning**: Camera, gallery, processing
- **Multi-page workflows**: Session management, page operations
- **QR code scanning**: URL detection, manual download
- **File operations**: Storage, naming, external directory access
- **Error scenarios**: Permission denied, storage full, invalid files
- **Navigation**: Tab switching, enum-driven navigation
- **State Management**: Scoped state, lifecycle, conditional rendering

## Release Quality Gates

Before any release:
1. **All tests pass** on target platforms
2. **README.md updated** with new features/changes
3. **Example app works** with new features (verify app shell and navigation)
4. **Performance benchmarks** meet requirements
5. **Memory usage** stays within acceptable limits
6. **Cross-platform compatibility** verified
7. **Modern architecture patterns** properly implemented and tested

## Issue Management

### Issue Types:
- **Bug**: Functionality not working as intended
- **Enhancement**: New feature or improvement
- **Documentation**: README or code documentation updates
- **Performance**: Optimization and memory management
- **Breaking Change**: API changes requiring major version
- **Architecture**: Modern app shell and navigation improvements

### Issue Resolution:
- **Link commits to issues** in commit messages
- **Close issues via commit messages** when appropriate
- **Update documentation** as part of issue resolution
- **Add tests** for bug fixes and new features
- **Consider modern architecture impact** when implementing changes

## Future Development Considerations

### Planned Features:
- **Auto-Crop Pipeline**: Advanced edge detection and smart cropping
- **OCR Integration**: Text extraction from scanned documents
- **Cloud Storage**: Google Drive, OneDrive integration
- **Batch Processing**: Multiple document workflows
- **Document Templates**: Specific document type handling
- **Enhanced Navigation**: More sophisticated app shell patterns

### Architecture Evolution:
- **State Management**: Continue refining scoped state patterns
- **Modular Design**: Further separation of concerns
- **Performance**: Optimized image processing pipelines
- **Testing**: Enhanced coverage for modern architecture patterns

### Backward Compatibility:
- Maintain API stability within major versions
- Deprecate features before removal
- Provide migration guides for breaking changes
- Support multiple Flutter versions when possible
- Preserve modern architecture benefits while maintaining compatibility

## UX Expectations

### Modern App Experience:
- **Prioritized Navigation**: Scanning flows prominently featured
- **First-Scan Guidance**: Helpful banners and contextual help
- **Consistent State**: Reliable state management across navigation
- **Responsive Design**: Adaptive UI for different screen sizes
- **Performance**: Smooth transitions and background processing

### User Guidance:
- **Clear Onboarding**: First-scan banners provide helpful context
- **Intuitive Navigation**: Tab ordering reflects user priorities
- **Contextual Help**: Appropriate guidance at each stage
- **Error Handling**: Clear error messages and recovery options

Remember: This package is designed for reusability across projects. Every decision should consider the impact on external users and maintain the highest quality standards while embracing modern Flutter architecture patterns.