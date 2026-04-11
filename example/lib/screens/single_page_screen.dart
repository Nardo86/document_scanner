import 'package:document_scanner/document_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../helpers/pdf_preview_helper.dart';
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

enum _Action { none, guided, camera, gallery }

class _SinglePageScreenState extends State<SinglePageScreen> {
  final DocumentScannerService _scannerService = DocumentScannerService();
  final TextEditingController _filenameController = TextEditingController();

  DocumentType _selectedType = DocumentType.document;
  _Action _activeAction = _Action.none;
  ScanResult? _lastResult;

  // Track which filename version was last applied so we can re-sync
  // when the user changes the global default via the config dialog.
  int _lastFilenameVersion = -1;
  String? _lastAppliedDefault;

  bool get _isBusy => _activeAction != _Action.none;

  @override
  void initState() {
    super.initState();
    _filenameController.addListener(_onFilenameChanged);
  }

  void _onFilenameChanged() => setState(() {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = ShowcaseStateScope.read(context);
    if (_lastFilenameVersion != state.filenameVersion) {
      final current = _filenameController.text.trim();
      final isUserEdit =
          current.isNotEmpty && current != _lastAppliedDefault;
      if (!isUserEdit) {
        _filenameController.text = state.defaultFilename ?? '';
      }
      _lastAppliedDefault = state.defaultFilename;
      _lastFilenameVersion = state.filenameVersion;
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
    final resolvedFilename =
        state.resolveFilename(_filenameController.text);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(
          icon: Icons.document_scanner,
          title: 'Single Page Capture',
          subtitle:
              'Guided scanner with image editing, or quick capture via camera / gallery.',
        ),
        const SizedBox(height: 12),
        if (_lastResult == null) const _FirstScanBanner(),
        const SizedBox(height: 12),
        _NamingStrategyBanner(
          resolvedFilename: resolvedFilename,
          storageDirectory: state.storageDisplayPath,
        ),
        const SizedBox(height: 12),
        _buildTypeSelector(),
        const SizedBox(height: 12),
        TextField(
          controller: _filenameController,
          decoration: const InputDecoration(
            labelText: 'Custom filename (overrides default)',
            prefixIcon: Icon(Icons.drive_file_rename_outline),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _isBusy ? null : _launchGuidedScanner,
          icon: _activeAction == _Action.guided
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.play_arrow),
          label: Text(_activeAction == _Action.guided
              ? 'Launching...'
              : 'Launch guided scanner'),
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
              if (doc != null) openPdfPreview(context, doc);
            },
          )
        else
          const EmptyState(
            icon: Icons.photo_camera_back,
            title: 'Ready when you are',
            message:
                'Capture a document to see file paths, metadata, and a live preview.',
          ),
        const SizedBox(height: 32),
      ],
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
        Text('Document type',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options
              .map((option) => ChoiceChip(
                    label: Text(option.name),
                    selected: _selectedType == option,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedType = option);
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick actions',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _isBusy ? null : () => _runQuickAction(useCamera: true),
                icon: _activeAction == _Action.camera
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.camera_alt),
                label: Text(_activeAction == _Action.camera
                    ? 'Capturing...'
                    : 'Camera'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isBusy
                    ? null
                    : () => _runQuickAction(useCamera: false),
                icon: _activeAction == _Action.gallery
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.photo_library),
                label: Text(_activeAction == _Action.gallery
                    ? 'Importing...'
                    : 'Gallery'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _launchGuidedScanner() async {
    setState(() => _activeAction = _Action.guided);
    final state = ShowcaseStateScope.read(context);
    final filename = state.resolveFilename(_filenameController.text);

    final result = await Navigator.push<ScanResult>(
      context,
      MaterialPageRoute(
        builder: (routeContext) => DocumentScannerWidget(
          documentType: _selectedType,
          customFilename: filename,
          customHeader: _GuidedScannerBanner(filename: filename),
          onScanComplete: (r) => Navigator.pop(routeContext, r),
          onError: (error) {
            ScaffoldMessenger.of(routeContext)
                .showSnackBar(SnackBar(content: Text(error)));
          },
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _activeAction = _Action.none);

    if (result != null) {
      _handleResult(result, flowLabel: 'Single Page');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scanner closed before finishing.')),
      );
    }
  }

  Future<void> _runQuickAction({required bool useCamera}) async {
    setState(() =>
        _activeAction = useCamera ? _Action.camera : _Action.gallery);

    final state = ShowcaseStateScope.read(context);
    final filename = state.resolveFilename(_filenameController.text);

    try {
      final result = useCamera
          ? await _scannerService.scanDocument(
              documentType: _selectedType, customFilename: filename)
          : await _scannerService.importDocument(
              documentType: _selectedType, customFilename: filename);

      if (!mounted) return;

      if (result.success &&
          result.document != null &&
          result.document!.rawImageData != null) {
        final finalResult = await _scannerService.showImageEditorFlow(
          context: context,
          document: result.document!,
          customFilename: filename,
          processingOptions: result.document!.processingOptions,
        );
        if (mounted) {
          _handleResult(finalResult,
              flowLabel:
                  useCamera ? 'Single Page (Camera)' : 'Single Page (Gallery)');
        }
      } else {
        _handleResult(result,
            flowLabel:
                useCamera ? 'Single Page (Camera)' : 'Single Page (Gallery)');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Failed to ${useCamera ? 'capture' : 'import'}: $e')),
      );
    } finally {
      if (mounted) setState(() => _activeAction = _Action.none);
    }
  }

  void _handleResult(ScanResult result, {required String flowLabel}) {
    if (kDebugMode) {
      debugPrint('DocumentScanner: $flowLabel - '
          '${result.success ? "SUCCESS" : "FAILED"}');
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _lastResult = result);
    ShowcaseStateScope.read(context).addResult(flowLabel, result);

    if (result.success) {
      messenger.showSnackBar(
          SnackBar(content: Text('Saved ${_displayName(result)}')));
    } else {
      messenger.showSnackBar(
          SnackBar(content: Text(result.error ?? 'Scan failed')));
    }
  }

  String _displayName(ScanResult result) {
    final document = result.document;
    if (document == null) return 'new scan';
    final custom = document.metadata['customFilename'];
    if (custom is String && custom.isNotEmpty) return custom;
    return document.id;
  }
}

// ---------------------------------------------------------------------------
// Banners
// ---------------------------------------------------------------------------

class _NamingStrategyBanner extends StatelessWidget {
  final String? resolvedFilename;
  final String storageDirectory;

  const _NamingStrategyBanner(
      {required this.resolvedFilename, required this.storageDirectory});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = resolvedFilename == null
        ? 'Automatic naming'
        : 'Filename: "$resolvedFilename"';
    final subtitle = resolvedFilename == null
        ? 'Files use metadata-driven names.'
        : 'Applied to the next scan from this tab.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.badge_outlined,
              color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer)),
                const SizedBox(height: 2),
                Text('$subtitle Storage: $storageDirectory',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FirstScanBanner extends StatelessWidget {
  const _FirstScanBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline,
              color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tap a button below to capture or import your first document. '
              'For multi-page documents, switch to the Multi Scan tab.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidedScannerBanner extends StatelessWidget {
  final String? filename;

  const _GuidedScannerBanner({this.filename});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Row(
        children: [
          Icon(Icons.tips_and_updates,
              color: Theme.of(context).colorScheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              filename == null
                  ? 'Files will use automatic naming'
                  : 'Saving as "$filename"',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
