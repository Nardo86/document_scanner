import 'dart:io';
import 'dart:typed_data';

import 'package:document_scanner/document_scanner.dart';
import 'package:flutter/material.dart';

/// Shared helper that loads PDF data and opens [PdfPreviewWidget].
///
/// Used by SinglePage, MultiPage, and CapabilitiesLab screens to avoid
/// duplicating the same load-from-disk / null-check logic.
Future<void> openPdfPreview(
  BuildContext context,
  ScannedDocument document, {
  String? title,
}) async {
  if (document.pdfData == null && document.pdfPath == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No PDF available for this document.')),
    );
    return;
  }

  Uint8List? pdfData = document.pdfData;
  if (pdfData == null && document.pdfPath != null) {
    final file = File(document.pdfPath!);
    if (await file.exists()) {
      pdfData = await file.readAsBytes();
    }
  }

  if (pdfData == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF file could not be loaded.')),
    );
    return;
  }

  if (!context.mounted) return;

  final displayTitle =
      title ?? 'Preview ${document.metadata['customFilename'] ?? document.id}';

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (previewContext) => PdfPreviewWidget(
        pdfData: pdfData,
        pdfPath: document.pdfPath,
        title: displayTitle,
        onConfirm: () => Navigator.pop(previewContext),
        onCancel: () => Navigator.pop(previewContext),
      ),
    ),
  );
}
