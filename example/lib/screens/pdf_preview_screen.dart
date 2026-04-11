import 'package:document_scanner/document_scanner.dart';
import 'package:flutter/material.dart';

import '../helpers/pdf_preview_helper.dart';
import '../state/showcase_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/scan_result_details.dart';
import '../widgets/section_header.dart';

class PdfPreviewShowcaseScreen extends StatefulWidget {
  static const routeName = '/pdf-preview';

  const PdfPreviewShowcaseScreen({super.key});

  @override
  State<PdfPreviewShowcaseScreen> createState() =>
      _PdfPreviewShowcaseScreenState();
}

class _PdfPreviewShowcaseScreenState
    extends State<PdfPreviewShowcaseScreen> {
  String? _loadingDocumentId;

  @override
  Widget build(BuildContext context) {
    final state = ShowcaseStateScope.watch(context);
    final documents = state.documents;
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Preview Lab')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(
            icon: Icons.picture_as_pdf,
            title: 'Review PDFs before sharing',
            subtitle:
                'Preview saved PDFs or in-memory bytes using PdfPreviewWidget.',
          ),
          const SizedBox(height: 12),
          if (documents.isEmpty)
            const EmptyState(
              icon: Icons.hourglass_empty,
              title: 'No documents yet',
              message:
                  'Run either scanner flow to generate PDFs, then revisit this screen.',
            )
          else
            Column(
              children: documents
                  .map((doc) => _buildDocumentCard(context, doc))
                  .toList(),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(
      BuildContext context, ScannedDocument doc) {
    final isLoading = _loadingDocumentId == doc.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              doc.metadata['customFilename'] ??
                  doc.pdfPath?.split('/').last ??
                  doc.id,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Type: ${doc.type.name} • Pages: ${doc.isMultiPage ? doc.pages.length : 1}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (doc.pdfPath != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                doc.pdfPath!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontFamily: 'monospace'),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        isLoading ? null : () => _previewDocument(doc),
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Icon(Icons.preview),
                    label: Text(
                        isLoading ? 'Loading…' : 'Preview PDF'),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'View metadata',
                  onPressed: () => _showMetadataDialog(doc),
                  icon: const Icon(Icons.info_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _previewDocument(ScannedDocument document) async {
    setState(() => _loadingDocumentId = document.id);
    try {
      await openPdfPreview(context, document);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingDocumentId = null);
    }
  }

  void _showMetadataDialog(ScannedDocument doc) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Document metadata'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: MetadataList(metadata: doc.metadata),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
