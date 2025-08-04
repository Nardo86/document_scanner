import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../models/scanned_document.dart';
import '../models/scan_result.dart';
import '../services/document_scanner_service.dart';
import '../services/pdf_generator.dart';
import 'image_editing_widget.dart';

/// Widget for multi-page document scanning with page management
class MultiPageScannerWidget extends StatefulWidget {
  final DocumentType documentType;
  final DocumentProcessingOptions? processingOptions;
  final String? customFilename;
  final Function(ScanResult) onScanComplete;
  final Function(String)? onError;
  final Widget? customHeader;

  const MultiPageScannerWidget({
    Key? key,
    required this.documentType,
    required this.onScanComplete,
    this.processingOptions,
    this.customFilename,
    this.onError,
    this.customHeader,
  }) : super(key: key);

  @override
  State<MultiPageScannerWidget> createState() => _MultiPageScannerWidgetState();
}

class _MultiPageScannerWidgetState extends State<MultiPageScannerWidget> {
  final DocumentScannerService _scannerService = DocumentScannerService();
  final PdfGenerator _pdfGenerator = PdfGenerator();
  
  MultiPageScanSession? _currentSession;
  bool _isProcessing = false;
  String? _currentError;
  bool _isPreviewMode = false;
  int _selectedPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_currentSession != null && _currentSession!.pages.isNotEmpty)
            IconButton(
              onPressed: _isProcessing ? null : _finalizeDocument,
              icon: const Icon(Icons.check),
              tooltip: 'Finalize Document',
            ),
        ],
      ),
      body: Column(
        children: [
          // Custom header
          if (widget.customHeader != null)
            widget.customHeader!,
          
          // Page count indicator
          if (_currentSession != null && _currentSession!.pages.isNotEmpty)
            _buildPageCountIndicator(),
          
          // Main content
          Expanded(
            child: _currentSession == null || _currentSession!.pages.isEmpty
                ? _buildInitialScanView()
                : _buildPageManagementView(),
          ),
          
          // Bottom action bar
          if (_currentSession != null && _currentSession!.pages.isNotEmpty)
            _buildBottomActionBar(),
        ],
      ),
    );
  }

  /// Build page count indicator
  Widget _buildPageCountIndicator() {
    final pageCount = _currentSession!.pages.length;
    return Container(
      padding: const EdgeInsets.all(8),
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description,
            color: Theme.of(context).primaryColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            '$pageCount page${pageCount > 1 ? 's' : ''} scanned',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Build initial scan view (no pages yet)
  Widget _buildInitialScanView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getDocumentTypeIcon(),
            size: 80,
            color: Theme.of(context).primaryColor.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 24),
          Text(
            'Multi-Page ${_getDocumentTypeName()}',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Scan multiple pages and combine them into a single PDF document',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Scan first page button
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _scanFirstPage,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Scan First Page'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Processing indicator
          if (_isProcessing)
            const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing page...'),
              ],
            ),
          
          // Error display
          if (_currentError != null)
            _buildErrorCard(),
        ],
      ),
    );
  }

  /// Build page management view (with pages)
  Widget _buildPageManagementView() {
    return Column(
      children: [
        // Page preview/thumbnail grid
        Expanded(
          child: _isPreviewMode
              ? _buildPagePreview()
              : _buildPageThumbnailGrid(),
        ),
        
        // Error display
        if (_currentError != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildErrorCard(),
          ),
      ],
    );
  }

  /// Build page thumbnail grid
  Widget _buildPageThumbnailGrid() {
    final pages = _currentSession!.pages;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: pages.length,
        itemBuilder: (context, index) {
          final page = pages[index];
          return _buildPageThumbnail(page, index);
        },
      ),
    );
  }

  /// Build individual page thumbnail
  Widget _buildPageThumbnail(DocumentPage page, int index) {
    return Card(
      child: Column(
        children: [
          // Page number header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Text(
              'Page ${index + 1}',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Page image
          Expanded(
            child: GestureDetector(
              onTap: () => _previewPage(index),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: page.processedImageData != null
                    ? Image.memory(
                        page.processedImageData!,
                        fit: BoxFit.cover,
                      )
                    : const Center(
                        child: Icon(
                          Icons.image,
                          size: 40,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
          ),
          
          // Page actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () => _previewPage(index),
                icon: const Icon(Icons.visibility),
                tooltip: 'Preview',
              ),
              IconButton(
                onPressed: () => _deletePage(index),
                icon: const Icon(Icons.delete),
                tooltip: 'Delete',
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build page preview (fullscreen)
  Widget _buildPagePreview() {
    final page = _currentSession!.pages[_selectedPageIndex];
    
    return Column(
      children: [
        // Preview header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black87,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Page ${_selectedPageIndex + 1} of ${_currentSession!.pages.length}',
                style: const TextStyle(color: Colors.white),
              ),
              IconButton(
                onPressed: () => setState(() => _isPreviewMode = false),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ),
        
        // Preview image
        Expanded(
          child: Container(
            color: Colors.black,
            child: Center(
              child: page.processedImageData != null
                  ? InteractiveViewer(
                      child: Image.memory(
                        page.processedImageData!,
                        fit: BoxFit.contain,
                      ),
                    )
                  : const Icon(
                      Icons.image,
                      size: 80,
                      color: Colors.white,
                    ),
            ),
          ),
        ),
        
        // Preview navigation
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black87,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: _selectedPageIndex > 0
                    ? () => setState(() => _selectedPageIndex--)
                    : null,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              IconButton(
                onPressed: () => _deletePage(_selectedPageIndex),
                icon: const Icon(Icons.delete, color: Colors.red),
              ),
              IconButton(
                onPressed: _selectedPageIndex < _currentSession!.pages.length - 1
                    ? () => setState(() => _selectedPageIndex++)
                    : null,
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build bottom action bar
  Widget _buildBottomActionBar() {
    return Container(
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
          // Add page button
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _addPage,
            icon: const Icon(Icons.add),
            label: const Text('Add Page'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
          
          // Reorder button
          OutlinedButton.icon(
            onPressed: _isProcessing ? null : _reorderPages,
            icon: const Icon(Icons.reorder),
            label: const Text('Reorder'),
          ),
          
          // Finalize button
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _finalizeDocument,
            icon: const Icon(Icons.check),
            label: const Text('Done'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Build error card
  Widget _buildErrorCard() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _currentError!,
                style: TextStyle(color: Colors.red.shade700),
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

  /// Scan first page
  Future<void> _scanFirstPage() async {
    setState(() {
      _isProcessing = true;
      _currentError = null;
    });

    try {
      final result = await _scannerService.scanDocument(
        documentType: widget.documentType,
        processingOptions: widget.processingOptions,
        customFilename: widget.customFilename,
      );

      if (result.success && result.document != null) {
        final document = result.document!;
        
        // Show image editor for first page
        await _showImageEditorForPage(document, 1, isFirstPage: true);
      } else {
        _handleError(result.error ?? 'Failed to scan first page');
      }
    } catch (e) {
      _handleError('Error scanning first page: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Add a new page
  Future<void> _addPage() async {
    setState(() {
      _isProcessing = true;
      _currentError = null;
    });

    try {
      final result = await _scannerService.scanDocument(
        documentType: widget.documentType,
        processingOptions: widget.processingOptions,
      );

      if (result.success && result.document != null) {
        final document = result.document!;
        final pageNumber = _currentSession!.pages.length + 1;
        
        // Show image editor for new page
        await _showImageEditorForPage(document, pageNumber, isFirstPage: false);
      } else {
        _handleError(result.error ?? 'Failed to add page');
      }
    } catch (e) {
      _handleError('Error adding page: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Delete a page
  void _deletePage(int index) {
    if (_currentSession == null || index >= _currentSession!.pages.length) return;

    final page = _currentSession!.pages[index];
    _currentSession = _currentSession!.removePage(page.id);
    
    // Adjust selected page index if needed
    if (_selectedPageIndex >= _currentSession!.pages.length) {
      _selectedPageIndex = _currentSession!.pages.length - 1;
    }
    
    setState(() {});
  }

  /// Preview a specific page
  void _previewPage(int index) {
    setState(() {
      _selectedPageIndex = index;
      _isPreviewMode = true;
    });
  }

  /// Reorder pages
  Future<void> _reorderPages() async {
    if (_currentSession == null) return;

    final reorderedPages = await showDialog<List<DocumentPage>>(
      context: context,
      builder: (context) => _PageReorderDialog(pages: _currentSession!.pages),
    );

    if (reorderedPages != null) {
      _currentSession = _currentSession!.reorderPages(reorderedPages);
      setState(() {});
    }
  }

  /// Finalize document (combine all pages into PDF)
  Future<void> _finalizeDocument() async {
    if (_currentSession == null || !_currentSession!.isReadyForFinalization) return;

    setState(() {
      _isProcessing = true;
      _currentError = null;
    });

    try {
      // Generate multi-page PDF
      final imageDataList = _currentSession!.pages
          .map((page) => page.processedImageData!)
          .toList();

      final pdfData = await _pdfGenerator.generateMultiPagePdf(
        imageDataList: imageDataList,
        documentType: widget.documentType,
        resolution: widget.processingOptions?.pdfResolution ?? PdfResolution.quality,
        documentFormat: widget.processingOptions?.documentFormat,
        metadata: {
          'pageCount': _currentSession!.pages.length,
          'sessionId': _currentSession!.sessionId,
          'customFilename': widget.customFilename,
        },
      );

      // Create final document
      final finalDocument = _currentSession!.toScannedDocument().copyWith(
        pdfData: pdfData,
        metadata: {
          ..._currentSession!.toScannedDocument().metadata,
          'finalizedAt': DateTime.now().toIso8601String(),
        },
      );

      print('🔍 MULTI-PAGE DEBUG: Final document created');
      print('🔍 - pdfData exists: ${finalDocument.pdfData != null}');
      print('🔍 - pdfData size: ${finalDocument.pdfData?.length ?? 0}');

      // Save to external storage using finalizeScanResult
      final saveResult = await _scannerService.finalizeScanResult(
        finalDocument,
        widget.customFilename,
      );

      if (saveResult.success && saveResult.document != null) {
        print('✅ MULTI-PAGE DEBUG: Document saved successfully');
        print('✅ - pdfPath: ${saveResult.document!.pdfPath}');
        print('✅ - processedPath: ${saveResult.document!.processedPath}');
        widget.onScanComplete(saveResult);
      } else {
        print('❌ MULTI-PAGE DEBUG: Save failed: ${saveResult.error}');
        _handleError('Failed to save multi-page document: ${saveResult.error}');
      }
    } catch (e) {
      _handleError('Error finalizing document: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Show image editor for a page (both first page and additional pages)
  Future<void> _showImageEditorForPage(
    ScannedDocument document,
    int pageNumber,
    {required bool isFirstPage}
  ) async {
    if (document.rawImageData == null) {
      // No image data available, proceed with original document
      _addPageToSession(document, pageNumber, isFirstPage);
      return;
    }

    try {
      // Navigate to image editing screen
      final editedImageData = await Navigator.push<Uint8List?>(
        context,
        MaterialPageRoute(
          builder: (context) => ImageEditingWidget(
            imageData: document.rawImageData!,
            onImageEdited: (editedData, selectedResolution, selectedFormat) {
              // For multi-page documents, we ignore the individual page resolution/format selection
              // and use the widget's processing options instead
              Navigator.pop(context, editedData);
            },
            onCancel: () {
              Navigator.pop(context, null);
            },
          ),
        ),
      );

      if (editedImageData != null) {
        // User confirmed editing - create new document with edited image
        final editedDocument = document.copyWith(
          processedImageData: editedImageData,
          metadata: {
            ...document.metadata,
            'edited': true,
            'editedAt': DateTime.now().toIso8601String(),
          },
        );

        _addPageToSession(editedDocument, pageNumber, isFirstPage);
      } else {
        // User cancelled editing - use original processed image
        _addPageToSession(document, pageNumber, isFirstPage);
      }
    } catch (e) {
      _handleError('Failed to edit image for page $pageNumber: $e');
    }
  }

  /// Add page to session after editing
  void _addPageToSession(ScannedDocument document, int pageNumber, bool isFirstPage) {
    if (isFirstPage) {
      // Create new session for first page
      _currentSession = MultiPageScanSession(
        sessionId: document.id,
        documentType: widget.documentType,
        processingOptions: document.processingOptions,
        startTime: DateTime.now(),
        customFilename: widget.customFilename,
      );
    }

    // Add page to session
    final newPage = DocumentPage(
      id: '${_currentSession!.sessionId}_page_$pageNumber',
      pageNumber: pageNumber,
      originalPath: document.originalPath,
      scanTime: document.scanTime,
      rawImageData: document.rawImageData,
      processedImageData: document.processedImageData,
      metadata: document.metadata,
    );

    _currentSession = _currentSession!.addPage(newPage);
    setState(() {});
  }

  /// Handle error
  void _handleError(String error) {
    setState(() => _currentError = error);
    widget.onError?.call(error);
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

  /// Get document type name
  String _getDocumentTypeName() {
    switch (widget.documentType) {
      case DocumentType.receipt:
        return 'Receipt';
      case DocumentType.manual:
        return 'Manual';
      case DocumentType.document:
        return 'Document';
      case DocumentType.other:
        return 'Document';
    }
  }

  /// Get screen title
  String _getTitle() {
    return 'Multi-Page ${_getDocumentTypeName()}';
  }
}

/// Dialog for reordering pages
class _PageReorderDialog extends StatefulWidget {
  final List<DocumentPage> pages;

  const _PageReorderDialog({required this.pages});

  @override
  State<_PageReorderDialog> createState() => _PageReorderDialogState();
}

class _PageReorderDialogState extends State<_PageReorderDialog> {
  late List<DocumentPage> _pages;

  @override
  void initState() {
    super.initState();
    _pages = List.from(widget.pages);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reorder Pages'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ReorderableListView.builder(
          itemCount: _pages.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final page = _pages.removeAt(oldIndex);
              _pages.insert(newIndex, page);
            });
          },
          itemBuilder: (context, index) {
            final page = _pages[index];
            return ListTile(
              key: ValueKey(page.id),
              leading: Text('${index + 1}'),
              title: Text('Page ${index + 1}'),
              subtitle: Text('Scanned: ${page.scanTime.toString().split('.')[0]}'),
              trailing: const Icon(Icons.drag_handle),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _pages),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

