import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

import '../models/scanned_document.dart';
import '../models/scan_result.dart';
import '../services/document_scanner_service.dart';
import '../services/qr_scanner_service.dart';

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

  const DocumentScannerWidget({
    Key? key,
    required this.documentType,
    required this.onScanComplete,
    this.processingOptions,
    this.customFilename,
    this.onError,
    this.showQROption = false,
    this.showImportOption = true,
    this.customHeader,
    this.customFooter,
  }) : super(key: key);

  @override
  State<DocumentScannerWidget> createState() => _DocumentScannerWidgetState();
}

class _DocumentScannerWidgetState extends State<DocumentScannerWidget> {
  final DocumentScannerService _scannerService = DocumentScannerService();
  final QRScannerService _qrService = QRScannerService();
  
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
          if (widget.customHeader != null)
            widget.customHeader!,
          
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
                  if (_currentError != null)
                    _buildErrorDisplay(),
                  
                  const Spacer(),
                  
                  // Processing indicator
                  if (_isScanning)
                    _buildProcessingIndicator(),
                ],
              ),
            ),
          ),
          
          // Custom footer if provided
          if (widget.customFooter != null)
            widget.customFooter!,
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
        if (widget.showQROption)
          _buildOptionCard(
            icon: Icons.qr_code_scanner,
            title: 'Scan QR Code',
            description: 'Scan QR code to download manual',
            onTap: _scanQRCode,
          ),
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
                color: _isScanning ? Colors.grey : Theme.of(context).primaryColor,
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
            Icon(
              Icons.error_outline,
              color: Colors.red.shade700,
            ),
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
              icon: Icon(
                Icons.close,
                color: Colors.red.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build processing indicator
  Widget _buildProcessingIndicator() {
    return Card(
      color: Theme.of(context).primaryColor.withOpacity(0.1),
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

  /// Scan document with camera
  Future<void> _scanWithCamera() async {
    setState(() {
      _isScanning = true;
      _currentError = null;
    });

    try {
      final result = await _scannerService.scanDocument(
        documentType: widget.documentType,
        processingOptions: widget.processingOptions,
        customFilename: widget.customFilename,
      );

      widget.onScanComplete(result);
    } catch (e) {
      _handleError('Failed to scan document: $e');
    } finally {
      setState(() => _isScanning = false);
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

      widget.onScanComplete(result);
    } catch (e) {
      _handleError('Failed to import document: $e');
    } finally {
      setState(() => _isScanning = false);
    }
  }

  /// Scan QR code
  Future<void> _scanQRCode() async {
    setState(() {
      _isScanning = true;
      _currentError = null;
    });

    try {
      // Navigate to QR scanner screen
      final result = await Navigator.push<QRScanResult>(
        context,
        MaterialPageRoute(
          builder: (context) => const QRScannerScreen(),
        ),
      );

      if (result != null && result.success) {
        // Process QR result
        if (result.contentType == QRContentType.pdfLink ||
            result.contentType == QRContentType.manualLink) {
          // Download manual from URL
          final downloadResult = await _scannerService.downloadManualFromUrl(
            url: result.qrData,
            customFilename: widget.customFilename,
          );
          
          widget.onScanComplete(downloadResult);
        } else {
          _handleError('QR code does not contain a valid manual link');
        }
      } else if (result != null) {
        _handleError(result.error ?? 'QR scan failed');
      }
    } catch (e) {
      _handleError('Failed to scan QR code: $e');
    } finally {
      setState(() => _isScanning = false);
    }
  }

  /// Handle error
  void _handleError(String error) {
    setState(() => _currentError = error);
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

/// QR Scanner Screen
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  final QRScannerService _qrService = QRScannerService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'Point camera at QR code to scan manual link',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null) {
        // Process QR data
        final result = _qrService.processQRData(scanData.code!);
        
        // Return result to previous screen
        Navigator.pop(context, result);
      }
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}

// AIDEV-NOTE: This widget provides a complete UI for document scanning
// with support for camera, gallery, and QR code scanning modes