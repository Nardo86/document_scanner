# `Claude.md` - Document Scanner Package

## Development Guidelines

### The Golden Rule  
When unsure about implementation details, ALWAYS ask the developer.  

## Project Context  
Document Scanner is a reusable Flutter package for document scanning with multi-page support, image processing, and PDF generation. Designed to be framework-agnostic and usable across multiple projects.

## Code Style and Patterns  

### Anchor Comments  
Add specially formatted comments throughout the codebase for inline knowledge:  
- Use `AIDEV-NOTE:`, `AIDEV-TODO:`, or `AIDEV-QUESTION:` (all-caps prefix)
- **Always grep for existing anchors** `AIDEV-*` before scanning files  
- **Update relevant anchors** when modifying associated code  
- **Do not remove `AIDEV-NOTE`s** without explicit instruction  

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
- Use proper dependency injection patterns
- Implement comprehensive error handling
- Write widget tests for UI components
- Unit tests for business logic
- Integration tests for document processing

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

## Testing Requirements

### Required Test Coverage:
- **Unit Tests**: All service methods and business logic
- **Widget Tests**: All public UI components  
- **Integration Tests**: End-to-end document processing workflows
- **Platform Tests**: Android and iOS compatibility

### Test Categories:
- **Single-page scanning**: Camera, gallery, processing
- **Multi-page workflows**: Session management, page operations
- **QR code scanning**: URL detection, manual download
- **File operations**: Storage, naming, external directory access
- **Error scenarios**: Permission denied, storage full, invalid files

## Release Quality Gates

Before any release:
1. **All tests pass** on target platforms
2. **README.md updated** with new features/changes
3. **Example app works** with new features
4. **Performance benchmarks** meet requirements
5. **Memory usage** stays within acceptable limits
6. **Cross-platform compatibility** verified

## Issue Management

### Issue Types:
- **Bug**: Functionality not working as intended
- **Enhancement**: New feature or improvement
- **Documentation**: README or code documentation updates
- **Performance**: Optimization and memory management
- **Breaking Change**: API changes requiring major version

### Issue Resolution:
- **Link commits to issues** in commit messages
- **Close issues via commit messages** when appropriate
- **Update documentation** as part of issue resolution
- **Add tests** for bug fixes and new features

## Future Development Considerations

### Planned Features:
- Advanced edge detection for document boundaries
- OCR integration for text extraction
- Cloud storage integration (Google Drive, OneDrive)
- Batch processing for multiple documents
- Document templates for specific types

### Backward Compatibility:
- Maintain API stability within major versions
- Deprecate features before removal
- Provide migration guides for breaking changes
- Support multiple Flutter versions when possible

Remember: This package is designed for reusability across projects. Every decision should consider the impact on external users and maintain the highest quality standards.