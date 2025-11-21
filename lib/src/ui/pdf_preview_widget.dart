import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// Widget for lightweight PDF preview before final saving
class PdfPreviewWidget extends StatefulWidget {
  final Uint8List? pdfData;
  final String? pdfPath;
  final String title;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isLoading;
  final Uint8List? fallbackImage;

  const PdfPreviewWidget({
    Key? key,
    this.pdfData,
    this.pdfPath,
    required this.title,
    this.onConfirm,
    this.onCancel,
    this.isLoading = false,
    this.fallbackImage,
  }) : super(key: key);

  @override
  State<PdfPreviewWidget> createState() => _PdfPreviewWidgetState();
}

class _PdfPreviewWidgetState extends State<PdfPreviewWidget> {
  String? _error;
  late Future<PdfDocument> _documentFuture;
  late PdfController _pdfController;
  bool _pdfLoading = false;

  @override
  void initState() {
    super.initState();
    _documentFuture = _loadPdf();
    _pdfController = PdfController(document: _documentFuture);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<PdfDocument> _loadPdf() async {
    setState(() {
      _pdfLoading = true;
      _error = null;
    });

    try {
      PdfDocument? document;

      if (widget.pdfData != null) {
        document = await PdfDocument.openData(widget.pdfData!);
      } else if (widget.pdfPath != null && widget.pdfPath!.isNotEmpty) {
        final file = File(widget.pdfPath!);
        if (!await file.exists()) {
          throw Exception('PDF file not found at path: ${widget.pdfPath}');
        }
        document = await PdfDocument.openFile(widget.pdfPath!);
      }

      if (mounted) {
        setState(() {
          _pdfLoading = false;
        });
      }
      
      if (document == null) {
        throw Exception('No PDF data provided');
      }
      return document;
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load PDF: ${e.toString()}';
          _pdfLoading = false;
        });
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (!widget.isLoading && widget.onConfirm != null)
            TextButton.icon(
              onPressed: widget.onConfirm,
              icon: const Icon(Icons.check),
              label: const Text('Save'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Preview header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf,
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PDF Preview',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Review your document before saving. You can zoom in/out and pan to check the quality.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
          
          // PDF content or loading/error state
          Expanded(
            child: _buildPdfContent(),
          ),
          
          // Bottom action bar
          if (!widget.isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel button
                  OutlinedButton.icon(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                  
                  // Confirm button
                  ElevatedButton.icon(
                    onPressed: widget.isLoading ? null : widget.onConfirm,
                    icon: widget.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(widget.isLoading ? 'Saving...' : 'Save Document'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPdfContent() {
    if (widget.isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (widget.pdfData == null && widget.pdfPath == null) {
      return _buildNoDataState();
    }

    if (_pdfLoading) {
      return _buildLoadingState();
    }

    return FutureBuilder<PdfDocument>(
      future: _documentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        
        if (snapshot.hasError) {
          setState(() {
            _error = 'Error: ${snapshot.error}';
          });
          return _buildErrorState();
        }
        
        if (!snapshot.hasData) {
          return _buildNoDataState();
        }

        return _buildPdfViewer();
      },
    );
  }

  Widget _buildPdfViewer() {
    return PdfView(
      controller: _pdfController,
      scrollDirection: Axis.vertical,
      onDocumentError: (error) {
        setState(() {
          _error = 'Error rendering PDF: $error';
        });
      },
      builders: PdfViewBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (context) => _buildLoadingState(),
        pageLoaderBuilder: (context) => _buildLoadingState(),
        errorBuilder: (context, error) => _buildErrorState(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading PDF preview...',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final hasFallback = widget.fallbackImage != null;
    
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (hasFallback) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      widget.fallbackImage!,
                      fit: BoxFit.contain,
                      height: 300,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'PDF Rendering Unavailable',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error ?? 'Failed to render PDF preview',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Showing processed image instead',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // No fallback image available
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error Loading PDF',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error ?? 'Unknown error occurred',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.red.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _documentFuture = _loadPdf();
                        _pdfController = PdfController(document: _documentFuture);
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No PDF Data Available',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'No PDF data or file path provided for preview.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
