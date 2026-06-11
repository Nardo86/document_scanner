import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/scanned_document.dart';
import '../models/scan_result.dart';
import '../services/document_scanner_service.dart';
import '../services/image_processor.dart';
import 'document_camera_screen.dart';

/// Main widget for document scanning functionality
class DocumentScannerWidget extends StatefulWidget {
  final DocumentType documentType;
  final DocumentProcessingOptions? processingOptions;
  final String? customFilename;
  final Function(ScanResult) onScanComplete;
  final Function(String)? onError;
  final bool showQROption;
  final bool showImportOption;
  final Widget? customHeader;
  final Widget? customFooter;

  /// Optional scanner service (e.g. one configured with a custom storage
  /// directory). Defaults to [DocumentScannerService.instance].
  final DocumentScannerService? service;

  const DocumentScannerWidget({
    super.key,
    required this.documentType,
    required this.onScanComplete,
    this.processingOptions,
    this.customFilename,
    this.onError,
    this.showQROption = false,
    this.showImportOption = true,
    this.customHeader,
    this.customFooter,
    this.service,
  });

  @override
  State<DocumentScannerWidget> createState() => _DocumentScannerWidgetState();
}

class _DocumentScannerWidgetState extends State<DocumentScannerWidget> {
  late final DocumentScannerService _scannerService =
      widget.service ?? DocumentScannerService.instance;

  bool _isScanning = false;
  String? _currentError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Custom header if provided
          if (widget.customHeader != null) widget.customHeader!,

          // Main content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Document type info
                  _buildDocumentTypeInfo(),

                  const SizedBox(height: 24),

                  // Scan options
                  _buildScanOptions(),

                  const SizedBox(height: 16),

                  // Error display
                  if (_currentError != null) _buildErrorDisplay(),

                  const Spacer(),

                  // Processing indicator
                  if (_isScanning) _buildProcessingIndicator(),
                ],
              ),
            ),
          ),

          // Custom footer if provided
          if (widget.customFooter != null) widget.customFooter!,
        ],
      ),
    );
  }

  /// Build document type information section
  Widget _buildDocumentTypeInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getDocumentTypeIcon(),
                  size: 32,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Text(
                  _getDocumentTypeTitle(),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getDocumentTypeDescription(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// Build scan options section
  Widget _buildScanOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Camera scan option
        _buildOptionCard(
          icon: Icons.camera_alt,
          title: 'Scan with Camera',
          description: 'Take a photo of the ${_getDocumentTypeName()}',
          onTap: _scanWithCamera,
        ),

        const SizedBox(height: 12),

        // Import from gallery option
        if (widget.showImportOption)
          _buildOptionCard(
            icon: Icons.photo_library,
            title: 'Import from Gallery',
            description: 'Select an existing photo',
            onTap: _importFromGallery,
          ),

        const SizedBox(height: 12),

        // QR code scan option (for manuals)
        // QR option removed - use QRScannerService.scanQRCodeWithUI() directly from your app
      ],
    );
  }

  /// Build option card
  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: _isScanning ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: _isScanning
                    ? Colors.grey
                    : Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _isScanning ? Colors.grey : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _isScanning ? Colors.grey : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isScanning)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build error display
  Widget _buildErrorDisplay() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentError!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _currentError = null),
              icon: Icon(Icons.close, color: Colors.red.shade700),
            ),
          ],
        ),
      ),
    );
  }

  /// Build processing indicator
  Widget _buildProcessingIndicator() {
    return Card(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Processing...',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Please wait while we process your document',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Scan document with guided camera overlay.
  ///
  /// Opens a custom camera screen with a draggable A4 trapezoid guide.
  /// After capture, applies perspective warp using the guide corners and
  /// passes the corrected image to the editor.
  Future<void> _scanWithCamera() async {
    setState(() {
      _isScanning = true;
      _currentError = null;
    });

    try {
      // Open guided camera screen
      final guideResult = await Navigator.push<CameraGuideResult>(
        context,
        MaterialPageRoute(builder: (context) => const DocumentCameraScreen()),
      );

      if (guideResult == null) {
        // User cancelled
        if (mounted) setState(() => _isScanning = false);
        return;
      }

      // Decode image dimensions off the UI thread for corner mapping.
      final size = await compute(_decodeImageSize, guideResult.imageData);
      if (size.length < 2) {
        _handleError('Failed to decode captured image');
        return;
      }

      final imgW = size[0].toDouble();
      final imgH = size[1].toDouble();

      // Convert fractional guide corners to pixel coordinates
      final pixelCorners = guideResult.corners
          .map((f) => Offset(f.dx * imgW, f.dy * imgH))
          .toList();

      // Apply perspective warp using the guide corners. Use the quad's own
      // aspect ratio (auto); the user can still pick a paper format in the editor.
      final imageProcessor = ImageProcessor();
      Uint8List? warpedData;
      try {
        warpedData = await imageProcessor.applyImageEditing(
          guideResult.imageData,
          ImageEditingOptions(
            cropCorners: pixelCorners,
            documentFormat: DocumentFormat.auto,
          ),
        );
      } catch (_) {
        // Perspective warp failed — continue with raw image only
      }

      final options =
          widget.processingOptions ?? const DocumentProcessingOptions();

      final document = ScannedDocument(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        type: widget.documentType,
        originalPath: '',
        scanTime: DateTime.now(),
        processingOptions: options,
        rawImageData: guideResult.imageData,
        processedImageData: warpedData,
        metadata: {
          'source': 'guided_camera',
          'guideCorners': guideResult.corners
              .map((o) => {'dx': o.dx, 'dy': o.dy})
              .toList(),
        },
      );

      await _showImageEditor(document);
    } catch (e) {
      _handleError('Failed to scan document: $e');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  /// Import document from gallery
  Future<void> _importFromGallery() async {
    setState(() {
      _isScanning = true;
      _currentError = null;
    });

    try {
      final result = await _scannerService.importDocument(
        documentType: widget.documentType,
        processingOptions: widget.processingOptions,
        customFilename: widget.customFilename,
      );

      if (result.success && result.document != null) {
        // Show image editor automatically after import
        await _showImageEditor(result.document!);
      } else {
        widget.onScanComplete(result);
      }
    } catch (e) {
      _handleError('Failed to import document: $e');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  /// Scan QR code - removed, use QRScannerService.scanQRCodeWithUI() directly
  // This method has been removed to avoid conflicts with the new QR implementation

  /// Show image editor automatically after scan/import
  Future<void> _showImageEditor(ScannedDocument document) async {
    if (!mounted) return;
    // Use the shared helper method from DocumentScannerService
    final result = await _scannerService.showImageEditorFlow(
      context: context,
      document: document,
      customFilename: widget.customFilename,
      processingOptions: widget.processingOptions,
    );

    // Call the completion callback with the final result
    if (mounted) widget.onScanComplete(result);
  }

  /// Handle error
  void _handleError(String error) {
    if (mounted) setState(() => _currentError = error);
    widget.onError?.call(error);
  }

  /// Get screen title based on document type
  String _getTitle() {
    switch (widget.documentType) {
      case DocumentType.receipt:
        return 'Scan Receipt';
      case DocumentType.manual:
        return 'Add Manual';
      case DocumentType.document:
        return 'Scan Document';
      case DocumentType.other:
        return 'Scan Document';
    }
  }

  /// Get document type icon
  IconData _getDocumentTypeIcon() {
    switch (widget.documentType) {
      case DocumentType.receipt:
        return Icons.receipt;
      case DocumentType.manual:
        return Icons.menu_book;
      case DocumentType.document:
        return Icons.description;
      case DocumentType.other:
        return Icons.document_scanner;
    }
  }

  /// Get document type title
  String _getDocumentTypeTitle() {
    switch (widget.documentType) {
      case DocumentType.receipt:
        return 'Receipt Scanner';
      case DocumentType.manual:
        return 'Manual Scanner';
      case DocumentType.document:
        return 'Document Scanner';
      case DocumentType.other:
        return 'Scanner';
    }
  }

  /// Get document type description
  String _getDocumentTypeDescription() {
    switch (widget.documentType) {
      case DocumentType.receipt:
        return 'Scan receipts and convert them to optimized PDF files with automatic cropping and filtering.';
      case DocumentType.manual:
        return 'Scan or download instruction manuals. QR codes can be scanned to automatically download PDFs.';
      case DocumentType.document:
        return 'Scan any document with automatic optimization and PDF conversion.';
      case DocumentType.other:
        return 'Scan documents with automatic processing and PDF generation.';
    }
  }

  /// Get document type name
  String _getDocumentTypeName() {
    switch (widget.documentType) {
      case DocumentType.receipt:
        return 'receipt';
      case DocumentType.manual:
        return 'manual';
      case DocumentType.document:
        return 'document';
      case DocumentType.other:
        return 'document';
    }
  }
}

// QR Scanner Screen removed - now implemented in qr_scanner_service.dart

// with support for camera, gallery, and QR code scanning modes

/// Top-level entry for `compute`: decode just the pixel dimensions of an
/// encoded image. Returns `[width, height]`, or empty on failure.
List<int> _decodeImageSize(Uint8List data) {
  final image = img.decodeImage(data);
  if (image == null) return const [];
  return [image.width, image.height];
}
