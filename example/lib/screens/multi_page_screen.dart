import 'dart:io';
import 'dart:typed_data';

import 'package:document_scanner/document_scanner.dart';
import 'package:flutter/material.dart';

import '../state/showcase_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/scan_result_details.dart';
import '../widgets/section_header.dart';

class MultiPageScreen extends StatefulWidget {
  static const routeName = '/multi-page';

  const MultiPageScreen({super.key});

  @override
  State<MultiPageScreen> createState() => _MultiPageScreenState();
}

class _MultiPageScreenState extends State<MultiPageScreen> {
  DocumentType _selectedType = DocumentType.manual;
  final TextEditingController _filenameController = TextEditingController(text: 'multi-session');
  bool _isLaunching = false;
  ScanResult? _lastResult;

  @override
  void dispose() {
    _filenameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = _lastResult?.document;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Page Session'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(
            icon: Icons.menu_book_outlined,
            title: 'Full multi-page workflow',
            subtitle: 'Starts MultiPageScannerWidget with page grid, preview mode, reorder dialog, and PDF preview.',
          ),
          const SizedBox(height: 12),
          _buildTypeSelector(),
          const SizedBox(height: 12),
          TextField(
            controller: _filenameController,
            decoration: const InputDecoration(
              labelText: 'Custom filename (defaults to metadata naming)',
              prefixIcon: Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isLaunching ? null : _launchMultiPageScanner,
            icon: _isLaunching
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow),
            label: Text(_isLaunching ? 'Launching…' : 'Start multi-page session'),
          ),
          const SizedBox(height: 24),
          if (_lastResult != null) ...[
            ScanResultDetails(
              result: _lastResult!,
              showPreviewButton: true,
              onPreview: () {
                if (doc != null) {
                  _openPreview(doc);
                }
              },
            ),
            if (doc != null && doc.pages.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildPagesSummary(doc),
            ],
          ] else
            const EmptyState(
              icon: Icons.library_books_outlined,
              title: 'No sessions yet',
              message: 'Capture 2+ pages to highlight the session timeline and PDF export.',
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    const options = [DocumentType.manual, DocumentType.document, DocumentType.receipt];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Document type', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options
              .map(
                (option) => ChoiceChip(
                  label: Text(option.name),
                  selected: _selectedType == option,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedType = option);
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPagesSummary(ScannedDocument document) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.collections, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Pages (${document.pages.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => _showMetadataDialog(document),
                  tooltip: 'View all metadata',
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: document.pages.length,
              itemBuilder: (context, index) {
                final page = document.pages[index];
                return _PageThumbnailCard(
                  page: page,
                  index: index,
                  onTap: () => _showPageDetails(page, index),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openPreview(document),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('View PDF'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showMetadataDialog(document),
                    icon: const Icon(Icons.info),
                    label: const Text('Metadata'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchMultiPageScanner() async {
    setState(() => _isLaunching = true);
    final state = ShowcaseStateScope.read(context);
    final filename = state.resolveFilename(_filenameController.text) ?? _filenameController.text.trim();

    final result = await Navigator.push<ScanResult>(
      context,
      MaterialPageRoute(
        builder: (routeContext) => MultiPageScannerWidget(
          documentType: _selectedType,
          customFilename: filename.isEmpty ? null : filename,
          customHeader: _MultiPageBanner(filename: filename),
          onScanComplete: (scanResult) => Navigator.pop(routeContext, scanResult),
          onError: (error) {
            ScaffoldMessenger.of(routeContext).showSnackBar(SnackBar(content: Text(error)));
          },
        ),
      ),
    );

    if (!mounted) return;

    setState(() {
      _isLaunching = false;
      if (result != null) {
        _lastResult = result;
      }
    });

    if (result != null) {
      state.addResult('Multi-Page', result);
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Captured ${result.document?.pages.length ?? 0} pages'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                if (result.document != null) {
                  _openPreview(result.document!);
                }
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _openPreview(ScannedDocument document) async {
    Uint8List? pdfData = document.pdfData;
    if (pdfData == null && document.pdfPath != null) {
      final file = File(document.pdfPath!);
      if (await file.exists()) {
        pdfData = await file.readAsBytes();
      }
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (previewContext) => PdfPreviewWidget(
          pdfData: pdfData,
          pdfPath: document.pdfPath,
          title: 'Multi-page preview',
          onConfirm: () => Navigator.pop(previewContext),
          onCancel: () => Navigator.pop(previewContext),
        ),
      ),
    );
  }

  void _showPageDetails(DocumentPage page, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => _PageDetailsSheet(
          page: page,
          index: index,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showMetadataDialog(ScannedDocument document) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document Metadata'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Document ID: ${document.id}'),
              const SizedBox(height: 8),
              Text('Type: ${document.type.name}'),
              const SizedBox(height: 8),
              Text('Pages: ${document.pages.length}'),
              const SizedBox(height: 8),
              Text('Multi-page: ${document.isMultiPage ? 'Yes' : 'No'}'),
              const SizedBox(height: 16),
              if (document.metadata.isNotEmpty) ...[
                const Text('Custom Metadata:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...document.metadata.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('${entry.key}: ${entry.value}'),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _PageThumbnailCard extends StatelessWidget {
  final DocumentPage page;
  final int index;
  final VoidCallback onTap;

  const _PageThumbnailCard({
    required this.page,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: page.processedImageData != null
                  ? Image.memory(
                      page.processedImageData!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Page ${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(page.scanTime),
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

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scanDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (scanDate == today) {
      return 'Today ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.month}/${timestamp.day} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

class _PageDetailsSheet extends StatelessWidget {
  final DocumentPage page;
  final int index;
  final ScrollController scrollController;

  const _PageDetailsSheet({
    required this.page,
    required this.index,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ListView(
        controller: scrollController,
        children: [
          Row(
            children: [
              Icon(Icons.insert_drive_file, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                'Page ${index + 1} Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (page.processedImageData != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                page.processedImageData!,
                fit: BoxFit.contain,
              ),
            )
          else
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No preview available',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scan Information', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _buildInfoRow(context, 'Scan time', page.scanTime.toLocal().toString()),
                  _buildInfoRow(context, 'Page ID', page.id),
                  _buildInfoRow(context, 'Original path', page.originalPath),
                  _buildInfoRow(context, 'Processed path', page.processedPath),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (page.metadata.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Metadata', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ...page.metadata.entries.map(
                      (entry) => _buildInfoRow(context, entry.key, '${entry.value}'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String? value) {
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _MultiPageBanner extends StatelessWidget {
  final String? filename;

  const _MultiPageBanner({this.filename});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session tips',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add as many pages as you like, preview full screen, reorder, then finalize to PDF.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            filename == null || filename!.isEmpty
                ? 'Using automatic multi-page naming'
                : 'Saving as "$filename"',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
          ),
        ],
      ),
    );
  }
}
