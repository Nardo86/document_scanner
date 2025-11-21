import 'package:document_scanner/document_scanner.dart';
import 'package:flutter/material.dart';

class ScanResultDetails extends StatelessWidget {
  final ScanResult result;
  final VoidCallback? onPreview;
  final bool showPreviewButton;

  const ScanResultDetails({super.key, required this.result, this.onPreview, this.showPreviewButton = false});

  @override
  Widget build(BuildContext context) {
    final document = result.document;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ResultStatusChip(result: result),
                const SizedBox(width: 12),
                Text(result.type.name.toUpperCase(), style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                Text(
                  result.success ? 'Success' : 'Failed',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (document == null)
              Text(result.error ?? 'No document was produced', style: Theme.of(context).textTheme.bodyMedium)
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('Type: ${document.type.name}')),
                  Chip(label: Text(document.isMultiPage ? '${document.pages.length} pages' : 'Single page')),
                  Chip(label: Text(document.pdfPath != null ? 'PDF saved' : 'PDF pending')),
                  Chip(label: Text(document.processingOptions.generatePdf ? 'PDF output' : 'No PDF')),
                ],
              ),
              const SizedBox(height: 12),
              if (document.processedImageData != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    document.processedImageData!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else if (document.pages.isNotEmpty && document.pages.first.processedImageData != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    document.pages.first.processedImageData!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 12),
              _buildPathTile(context, 'PDF path', document.pdfPath),
              _buildPathTile(context, 'Processed image path', document.processedPath),
              _buildPathTile(context, 'Original capture', document.originalPath),
              const SizedBox(height: 12),
              Text('Metadata', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              MetadataList(metadata: document.metadata),
              const SizedBox(height: 12),
              Text('Processing options', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(document.processingOptions.convertToGrayscale ? 'Grayscale' : 'Color')),
                  Chip(label: Text(document.processingOptions.enhanceContrast ? 'Contrast +' : 'Contrast off')),
                  Chip(label: Text('Compression ${(document.processingOptions.compressionQuality * 100).round()}%')),
                  Chip(label: Text(document.processingOptions.pdfResolution.name)),
                  Chip(label: Text(document.processingOptions.saveImageFile ? 'PDF + image' : 'PDF only')),
                ],
              ),
              if (showPreviewButton && onPreview != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: onPreview,
                    icon: const Icon(Icons.visibility),
                    label: const Text('Open PDF preview'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPathTile(BuildContext context, String label, String? value) {
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

class MetadataList extends StatelessWidget {
  final Map<String, dynamic> metadata;

  const MetadataList({super.key, required this.metadata});

  @override
  Widget build(BuildContext context) {
    if (metadata.isEmpty) {
      return Text('No metadata available', style: Theme.of(context).textTheme.bodySmall);
    }
    return Column(
      children: metadata.entries
          .map(
            (entry) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(entry.key),
              subtitle: Text('${entry.value}'),
            ),
          )
          .toList(),
    );
  }
}

class ResultStatusChip extends StatelessWidget {
  final ScanResult result;

  const ResultStatusChip({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    late Color color;
    late String label;
    if (result.success) {
      color = Colors.green;
      label = 'Success';
    } else if (result.error == 'User cancelled operation') {
      color = Colors.orange;
      label = 'Cancelled';
    } else {
      color = Colors.red;
      label = 'Error';
    }
    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: 6),
      label: Text(label),
    );
  }
}
