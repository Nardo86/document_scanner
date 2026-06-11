import 'package:document_scanner/document_scanner.dart';
import 'package:flutter/material.dart';

import '../helpers/pdf_preview_helper.dart';
import '../state/showcase_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/scan_result_details.dart';
import '../widgets/section_header.dart';

class CapabilitiesLabScreen extends StatefulWidget {
  static const routeName = '/capabilities-lab';

  const CapabilitiesLabScreen({super.key});

  @override
  State<CapabilitiesLabScreen> createState() => _CapabilitiesLabScreenState();
}

enum _LabAction { none, camera, gallery }

class _CapabilitiesLabScreenState extends State<CapabilitiesLabScreen> {
  DocumentType _documentType = DocumentType.document;
  bool _grayscale = true;
  bool _contrast = true;
  bool _perspective = true;
  bool _generatePdf = true;
  bool _saveImage = false;
  double _compression = 0.85;
  PdfResolution _resolution = PdfResolution.quality;
  DocumentFormat _format = DocumentFormat.auto;
  final TextEditingController _filenameController = TextEditingController();
  _LabAction _activeAction = _LabAction.none;
  ScanResult? _lastResult;
  String? _error;

  bool get _isBusy => _activeAction != _LabAction.none;

  @override
  void dispose() {
    _filenameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(
          icon: Icons.science,
          title: 'Capabilities Lab',
          subtitle:
              'Toggle processing options and call the scanner service directly.',
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    onPressed: () => setState(() => _error = null),
                    tooltip: 'Dismiss',
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        _buildDocumentTypeSelector(),
        const SizedBox(height: 12),
        _buildToggleCard(),
        const SizedBox(height: 12),
        _buildAdvancedOptionsCard(),
        const SizedBox(height: 12),
        TextField(
          controller: _filenameController,
          decoration: const InputDecoration(
            labelText: 'Override filename for this experiment',
            prefixIcon: Icon(Icons.drive_file_move),
          ),
        ),
        const SizedBox(height: 16),
        _buildActionButtons(),
        const SizedBox(height: 24),
        if (_lastResult != null)
          ScanResultDetails(
            result: _lastResult!,
            showPreviewButton: true,
            onPreview: () {
              final doc = _lastResult!.document;
              if (doc != null) openPdfPreview(context, doc);
            },
          )
        else
          const EmptyState(
            icon: Icons.tune,
            title: 'Experiment results appear here',
            message:
                'Capture via camera or import a file to see how each toggle affects the output.',
          ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDocumentTypeSelector() {
    const options = [
      DocumentType.document,
      DocumentType.manual,
      DocumentType.receipt,
      DocumentType.other,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document type',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: options
                  .map(
                    (option) => ChoiceChip(
                      label: Text(option.name),
                      selected: _documentType == option,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _documentType = option);
                        }
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleCard() {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Convert to grayscale'),
            subtitle: const Text('Helpful for receipts and contracts'),
            value: _grayscale,
            onChanged: (value) => setState(() => _grayscale = value),
          ),
          SwitchListTile(
            title: const Text('Enhance contrast'),
            subtitle: const Text('Boost faint ink and faded scans'),
            value: _contrast,
            onChanged: (value) => setState(() => _contrast = value),
          ),
          SwitchListTile(
            title: const Text('Auto perspective correction'),
            value: _perspective,
            onChanged: (value) => setState(() => _perspective = value),
          ),
          SwitchListTile(
            title: const Text('Generate PDF output'),
            value: _generatePdf,
            onChanged: (value) => setState(() => _generatePdf = value),
          ),
          SwitchListTile(
            title: const Text('Save processed image alongside PDF'),
            value: _saveImage,
            onChanged: (value) => setState(() => _saveImage = value),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Compression quality (${(_compression * 100).round()}%)'),
                Slider(
                  value: _compression,
                  min: 0.4,
                  max: 1.0,
                  divisions: 6,
                  onChanged: (value) => setState(() => _compression = value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedOptionsCard() {
    final formats = [
      DocumentFormat.auto,
      DocumentFormat.isoA,
      DocumentFormat.usLetter,
      DocumentFormat.square,
      DocumentFormat.receipt,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PDF resolution & format',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildResolutionDropdown()),
                const SizedBox(width: 12),
                Expanded(child: _buildFormatDropdown(formats)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: _buildSummaryChips()),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSummaryChips() {
    return [
      Chip(label: Text(_grayscale ? 'Grayscale' : 'Color')),
      Chip(label: Text(_contrast ? 'Contrast +' : 'Contrast off')),
      Chip(label: Text('Compression ${(_compression * 100).round()}%')),
      Chip(label: Text('Resolution ${_resolution.name}')),
      Chip(label: Text(_saveImage ? 'PDF + image' : 'PDF only')),
      Chip(label: Text('Format ${_format.name}')),
    ];
  }

  Widget _buildResolutionDropdown() {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Resolution',
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PdfResolution>(
          value: _resolution,
          isExpanded: true,
          items: PdfResolution.values
              .map((res) => DropdownMenuItem(value: res, child: Text(res.name)))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _resolution = value);
          },
        ),
      ),
    );
  }

  Widget _buildFormatDropdown(List<DocumentFormat> formats) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Document format',
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DocumentFormat>(
          value: _format,
          isExpanded: true,
          items: formats
              .map(
                (format) =>
                    DropdownMenuItem(value: format, child: Text(format.name)),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _format = value);
          },
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _isBusy ? null : () => _runExperiment(useCamera: true),
            icon: _activeAction == _LabAction.camera
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.camera),
            label: Text(
              _activeAction == _LabAction.camera ? 'Capturing…' : 'Camera',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isBusy ? null : () => _runExperiment(useCamera: false),
            icon: _activeAction == _LabAction.gallery
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_library),
            label: Text(
              _activeAction == _LabAction.gallery ? 'Importing…' : 'Gallery',
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton.outlined(
          onPressed: _isBusy ? null : _resetToDefaults,
          icon: const Icon(Icons.refresh),
          tooltip: 'Reset all options to defaults',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _resetToDefaults() {
    setState(() {
      _documentType = DocumentType.document;
      _grayscale = true;
      _contrast = true;
      _perspective = true;
      _generatePdf = true;
      _saveImage = false;
      _compression = 0.85;
      _resolution = PdfResolution.quality;
      _format = DocumentFormat.auto;
      _filenameController.clear();
      _lastResult = null;
      _error = null;
    });
  }

  Future<void> _runExperiment({required bool useCamera}) async {
    setState(() {
      _activeAction = useCamera ? _LabAction.camera : _LabAction.gallery;
      _error = null;
    });

    final options = DocumentProcessingOptions(
      convertToGrayscale: _grayscale,
      enhanceContrast: _contrast,
      autoCorrectPerspective: _perspective,
      compressionQuality: _compression,
      generatePdf: _generatePdf,
      saveImageFile: _saveImage,
      pdfResolution: _resolution,
      documentFormat: _format,
    );

    final state = ShowcaseStateScope.read(context);
    final filename = state.resolveFilename(_filenameController.text);

    try {
      ScanResult result;
      if (useCamera) {
        result = await DocumentScannerService.instance.scanDocumentWithProcessing(
          documentType: _documentType,
          processingOptions: options,
          customFilename: filename,
        );
      } else {
        result = await DocumentScannerService.instance.importDocumentWithProcessing(
          documentType: _documentType,
          processingOptions: options,
          customFilename: filename,
        );
      }

      if (!mounted) return;

      setState(() => _lastResult = result);
      state.addResult('Capabilities Lab', result);

      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Experiment returned an error.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Experiment failed: $e');
    } finally {
      if (mounted) setState(() => _activeAction = _LabAction.none);
    }
  }
}
