import 'dart:io';
import 'dart:typed_data';

import 'package:document_scanner/document_scanner.dart';
import 'package:flutter/material.dart';

import '../state/showcase_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/scan_result_details.dart';
import '../widgets/section_header.dart';

class SinglePageScreen extends StatefulWidget {
  static const routeName = '/single-page';

  const SinglePageScreen({super.key});

  @override
  State<SinglePageScreen> createState() => _SinglePageScreenState();
}

class _SinglePageScreenState extends State<SinglePageScreen> {
  final DocumentScannerService _scannerService = DocumentScannerService();
  final TextEditingController _filenameController = TextEditingController();

  DocumentType _selectedType = DocumentType.document;
  bool _appliedDefault = false;
  bool _isGuidedLaunching = false;
  bool _isCameraProcessing = false;
  bool _isGalleryProcessing = false;
  ScanResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _filenameController.addListener(_onFilenameChanged);
  }

  void _onFilenameChanged() {
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_appliedDefault) {
      final defaultName = ShowcaseStateScope.read(context).defaultFilename;
      if (defaultName != null) {
        _filenameController.text = defaultName;
      }
      _appliedDefault = true;
    }
  }

  @override
  void dispose() {
    _filenameController.removeListener(_onFilenameChanged);
    _filenameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ShowcaseStateScope.watch(context);
    final resolvedFilename = state.resolveFilename(_filenameController.text);
    final isBusy = _isGuidedLaunching || _isCameraProcessing || _isGalleryProcessing;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Single Page Capture'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(
            icon: Icons.document_scanner,
            title: 'Guided scanner experience',
            subtitle: 'Uses DocumentScannerWidget → ImageEditingWidget → PdfPreviewWidget, then surfaces metadata.',
          ),
          const SizedBox(height: 12),
          _NamingStrategyBanner(
            resolvedFilename: resolvedFilename,
            storageDirectory: state.customDirectory ?? '/Documents/${state.appName}',
          ),
          const SizedBox(height: 12),
          _buildTypeSelector(),
          const SizedBox(height: 12),
          TextField(
            controller: _filenameController,
            decoration: const InputDecoration(
              labelText: 'Custom filename (overrides default for this run)',
              prefixIcon: Icon(Icons.drive_file_rename_outline),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isBusy ? null : _launchGuidedScanner,
            icon: _isGuidedLaunching
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow),
            label: Text(_isGuidedLaunching ? 'Launching…' : 'Launch guided scanner'),
          ),
          const SizedBox(height: 16),
          _buildQuickActions(),
          const SizedBox(height: 24),
          if (_lastResult != null)
            ScanResultDetails(
              result: _lastResult!,
              showPreviewButton: true,
              onPreview: () {
                final doc = _lastResult!.document;
                if (doc != null) {
                  _openPreview(doc);
                }
              },
            )
          else
            const EmptyState(
              icon: Icons.photo_camera_back,
              title: 'Ready when you are',
              message: 'Capture a document to see file paths, metadata, and a live preview.',
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    const options = [
      DocumentType.document,
      DocumentType.receipt,
      DocumentType.manual,
    ];
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
                    if (selected) {
                      setState(() => _selectedType = option);
                    }
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isCameraProcessing || _isGuidedLaunching || _isGalleryProcessing
                    ? null
                    : () => _runQuickAction(useCamera: true),
                icon: _isCameraProcessing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.camera_alt),
                label: Text(_isCameraProcessing ? 'Capturing…' : 'Capture with camera'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isGalleryProcessing || _isGuidedLaunching || _isCameraProcessing
                    ? null
                    : () => _runQuickAction(useCamera: false),
                icon: _isGalleryProcessing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.photo_library),
                label: Text(_isGalleryProcessing ? 'Importing…' : 'Import from gallery'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _launchGuidedScanner() async {
    setState(() => _isGuidedLaunching = true);
    final state = ShowcaseStateScope.read(context);
    final filename = state.resolveFilename(_filenameController.text);

    final result = await Navigator.push<ScanResult>(
      context,
      MaterialPageRoute(
        builder: (routeContext) => DocumentScannerWidget(
          documentType: _selectedType,
          customFilename: filename,
          customHeader: _SinglePageScannerBanner(filename: filename),
          onScanComplete: (scanResult) => Navigator.pop(routeContext, scanResult),
          onError: (error) {
            ScaffoldMessenger.of(routeContext).showSnackBar(
              SnackBar(content: Text(error)),
            );
          },
        ),
      ),
    );

    if (!mounted) return;

    setState(() => _isGuidedLaunching = false);

    if (result != null) {
      _handleResult(result, flowLabel: 'Single Page');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scanner closed before finishing.')),
      );
    }
  }

  Future<void> _runQuickAction({required bool useCamera}) async {
    setState(() {
      if (useCamera) {
        _isCameraProcessing = true;
      } else {
        _isGalleryProcessing = true;
      }
    });

    final state = ShowcaseStateScope.read(context);
    final filename = state.resolveFilename(_filenameController.text);

    try {
      final result = useCamera
          ? await _scannerService.scanDocument(
              documentType: _selectedType,
              customFilename: filename,
            )
          : await _scannerService.importDocument(
              documentType: _selectedType,
              customFilename: filename,
            );

      if (!mounted) return;
      _handleResult(
        result,
        flowLabel: useCamera ? 'Single Page (Camera)' : 'Single Page (Gallery)',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to ${useCamera ? 'capture' : 'import'}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (useCamera) {
            _isCameraProcessing = false;
          } else {
            _isGalleryProcessing = false;
          }
        });
      }
    }
  }

  void _handleResult(ScanResult result, {required String flowLabel}) {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _lastResult = result);

    final state = ShowcaseStateScope.read(context);
    state.addResult(flowLabel, result);

    if (result.success) {
      messenger.showSnackBar(
        SnackBar(content: Text('Saved ${_resultDisplayName(result)}')),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(result.error ?? 'Scan failed')),
      );
    }
  }

  String _resultDisplayName(ScanResult result) {
    final document = result.document;
    if (document == null) {
      return 'new scan';
    }
    final customName = document.metadata['customFilename'];
    if (customName is String && customName.isNotEmpty) {
      return customName;
    }
    return document.id;
  }

  Future<void> _openPreview(ScannedDocument document) async {
    if (document.pdfData == null && document.pdfPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No PDF generated yet. Enable PDF output to preview.')),
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

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (previewContext) => PdfPreviewWidget(
          pdfData: pdfData,
          pdfPath: document.pdfPath,
          title: 'Preview ${document.metadata['customFilename'] ?? document.id}',
          onConfirm: () => Navigator.pop(previewContext),
          onCancel: () => Navigator.pop(previewContext),
        ),
      ),
    );
  }
}

class _NamingStrategyBanner extends StatelessWidget {
  final String? resolvedFilename;
  final String storageDirectory;

  const _NamingStrategyBanner({required this.resolvedFilename, required this.storageDirectory});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = resolvedFilename == null ? 'Automatic naming enabled' : 'Using "$resolvedFilename"';
    final subtitle = resolvedFilename == null
        ? 'Files will use metadata-driven names.'
        : 'Overrides will apply only to this session.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.badge_outlined, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$subtitle Stored under $storageDirectory.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SinglePageScannerBanner extends StatelessWidget {
  final String? filename;

  const _SinglePageScannerBanner({this.filename});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Row(
        children: [
          Icon(Icons.tips_and_updates, color: Theme.of(context).colorScheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              filename == null
                  ? 'Files will use automatic naming'
                  : 'Files will be saved as "$filename"',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
