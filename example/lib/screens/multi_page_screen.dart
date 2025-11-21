import 'dart:io';
import 'dart:typed_data';

import 'package:document_scanner/document_scanner.dart';
import 'package:flutter/material.dart';

import '../state/showcase_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/scan_result_details.dart';
import '../widgets/section_header.dart';

class MultiPageShowcaseScreen extends StatefulWidget {
  static const routeName = '/multi-page';

  const MultiPageShowcaseScreen({super.key});

  @override
  State<MultiPageShowcaseScreen> createState() => _MultiPageShowcaseScreenState();
}

class _MultiPageShowcaseScreenState extends State<MultiPageShowcaseScreen> {
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
          if (_lastResult != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  const SizedBox(height: 16),
                  Text('Pages', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: doc.pages.length,
                    itemBuilder: (context, index) {
                      final page = doc.pages[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text('Scanned at ${page.scanTime.toLocal()}'),
                          subtitle: page.metadata.isEmpty
                              ? const Text('No metadata captured')
                              : Text(page.metadata.entries
                                  .map((entry) => '${entry.key}: ${entry.value}')
                                  .join('\n')),
                        ),
                      );
                    },
                  ),
                ],
              ],
            )
          else
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
