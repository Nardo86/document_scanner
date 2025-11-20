import 'dart:io';
import 'dart:typed_data';

import 'package:document_scanner/document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DocumentScannerService().configureStorage(appName: 'DocumentScannerShowcase');
  runApp(const DocumentScannerShowcaseApp());
}

class DocumentScannerShowcaseApp extends StatefulWidget {
  const DocumentScannerShowcaseApp({super.key});

  @override
  State<DocumentScannerShowcaseApp> createState() => _DocumentScannerShowcaseAppState();
}

class _DocumentScannerShowcaseAppState extends State<DocumentScannerShowcaseApp> {
  late final ShowcaseState _state;

  @override
  void initState() {
    super.initState();
    _state = ShowcaseState();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShowcaseStateScope(
      notifier: _state,
      child: MaterialApp(
        title: 'Document Scanner Showcase',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
          useMaterial3: true,
        ),
        routes: {
          SinglePageShowcaseScreen.routeName: (_) => const SinglePageShowcaseScreen(),
          MultiPageShowcaseScreen.routeName: (_) => const MultiPageShowcaseScreen(),
          PdfPreviewShowcaseScreen.routeName: (_) => const PdfPreviewShowcaseScreen(),
          CapabilitiesLabScreen.routeName: (_) => const CapabilitiesLabScreen(),
        },
        home: const ShowcaseHomeScreen(),
      ),
    );
  }
}

class ShowcaseState extends ChangeNotifier {
  static const int _maxHistory = 15;

  final List<ScanSessionLog> _history = [];
  String _appName = 'DocumentScannerShowcase';
  String? _customDirectory;
  String? _defaultFilename;
  String? _lastConfigSummary;

  String get appName => _appName;
  String? get customDirectory => _customDirectory;
  String? get defaultFilename => _defaultFilename;
  String? get lastConfigSummary => _lastConfigSummary;

  List<ScanSessionLog> get history => List.unmodifiable(_history);

  ScannedDocument? get latestDocument {
    for (final log in _history) {
      if (log.result.document != null) {
        return log.result.document;
      }
    }
    return null;
  }

  List<ScannedDocument> get documents => _history
      .where((log) => log.result.document != null)
      .map((log) => log.result.document!)
      .toList(growable: false);

  void configureStorage({String? appName, String? customDirectory}) {
    final sanitizedAppName = (appName ?? _appName).trim().isEmpty ? _appName : (appName ?? _appName).trim();
    final sanitizedDirectory = (customDirectory ?? '').trim().isEmpty ? null : (customDirectory ?? '').trim();

    DocumentScannerService().configureStorage(
      appName: sanitizedAppName,
      customStorageDirectory: sanitizedDirectory,
    );

    _appName = sanitizedAppName;
    _customDirectory = sanitizedDirectory;
    _lastConfigSummary = 'Configured at ${DateTime.now().toLocal()}';
    notifyListeners();
  }

  void resetStorage() {
    _defaultFilename = null;
    configureStorage(appName: 'DocumentScannerShowcase', customDirectory: null);
  }

  void setDefaultFilename(String? value) {
    _defaultFilename = value?.trim().isEmpty ?? true ? null : value?.trim();
    notifyListeners();
  }

  String? resolveFilename(String? override) {
    final trimmed = override?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return _defaultFilename;
  }

  void addResult(String flow, ScanResult result) {
    _history.insert(0, ScanSessionLog(flow: flow, result: result, timestamp: DateTime.now()));
    if (_history.length > _maxHistory) {
      _history.removeRange(_maxHistory, _history.length);
    }
    notifyListeners();
  }
}

class ScanSessionLog {
  final String flow;
  final ScanResult result;
  final DateTime timestamp;

  ScanSessionLog({required this.flow, required this.result, required this.timestamp});


}

class ShowcaseStateScope extends InheritedNotifier<ShowcaseState> {
  const ShowcaseStateScope({
    super.key,
    required ShowcaseState notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ShowcaseState watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ShowcaseStateScope>();
    assert(scope != null, 'ShowcaseStateScope not found in context');
    return scope!.notifier!;
  }

  static ShowcaseState read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<ShowcaseStateScope>();
    assert(element != null, 'ShowcaseStateScope not found in context');
    final scope = element!.widget as ShowcaseStateScope;
    return scope.notifier!;
  }
}
class ShowcaseHomeScreen extends StatefulWidget {
  const ShowcaseHomeScreen({super.key});

  @override
  State<ShowcaseHomeScreen> createState() => _ShowcaseHomeScreenState();
}

class _ShowcaseHomeScreenState extends State<ShowcaseHomeScreen> {
  late TextEditingController _appNameController;
  late TextEditingController _directoryController;
  late TextEditingController _filenameController;
  bool _controllersReady = false;
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _packageInfo = info);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controllersReady) {
      final state = ShowcaseStateScope.read(context);
      _appNameController = TextEditingController(text: state.appName);
      _directoryController = TextEditingController(text: state.customDirectory ?? '');
      _filenameController = TextEditingController(text: state.defaultFilename ?? '');
      _controllersReady = true;
    }
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _directoryController.dispose();
    _filenameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ShowcaseStateScope.watch(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phase 2 Showcase'),
        actions: [
          IconButton(
            icon: const Icon(Icons.rule_folder_outlined),
            tooltip: 'Manual test checklist',
            onPressed: () => _showManualTests(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeroHeader(state),
          const SizedBox(height: 16),
          _buildStorageCard(state),
          const SizedBox(height: 16),
          _buildFlowGrid(),
          const SizedBox(height: 16),
          _buildRecentResults(state),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(ShowcaseState state) {
    final version = _packageInfo?.version ?? '...';
    final buildNumber = _packageInfo?.buildNumber ?? '';
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document Scanner',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Phase 2 Example Showcase',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text('v$version+$buildNumber'),
                  avatar: const Icon(Icons.info_outline),
                ),
                Chip(
                  label: Text('Storage: ${state.customDirectory ?? '/Documents/${state.appName}'}'),
                  avatar: const Icon(Icons.sd_storage),
                ),
                Chip(
                  label: Text('Default name: ${state.defaultFilename ?? 'auto'}'),
                  avatar: const Icon(Icons.badge_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageCard(ShowcaseState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              icon: Icons.settings_applications,
              title: 'Storage & naming configuration',
              subtitle: 'Calls DocumentScannerService.configureStorage and sets a default filename for the showcase.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _appNameController,
              decoration: const InputDecoration(
                labelText: 'App name',
                prefixIcon: Icon(Icons.apps),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _directoryController,
              decoration: const InputDecoration(
                labelText: 'Custom storage directory (optional)',
                hintText: '/storage/emulated/0/Documents/MyApp',
                prefixIcon: Icon(Icons.folder),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _filenameController,
              decoration: const InputDecoration(
                labelText: 'Default custom filename (optional)',
                hintText: 'project-proposal',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ShowcaseStateScope.read(context).configureStorage(
                        appName: _appNameController.text,
                        customDirectory: _directoryController.text,
                      );
                      ShowcaseStateScope.read(context).setDefaultFilename(_filenameController.text);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Storage configuration applied')),
                      );
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Apply configuration'),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Reset to defaults',
                  onPressed: () {
                    _appNameController.text = 'DocumentScannerShowcase';
                    _directoryController.clear();
                    _filenameController.clear();
                    ShowcaseStateScope.read(context).resetStorage();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Configuration reset to defaults')),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (state.lastConfigSummary != null) ...[
              const SizedBox(height: 12),
              Text(
                state.lastConfigSummary!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFlowGrid() {
    final flows = [
      FlowCardData(
        title: 'Single Page Capture',
        description: 'Launches DocumentScannerWidget with editing, PDF preview, and metadata surfacing.',
        icon: Icons.document_scanner,
        accentColor: Colors.blue,
        routeName: SinglePageShowcaseScreen.routeName,
        badges: const ['Image editor', 'Custom filenames'],
      ),
      FlowCardData(
        title: 'Multi-Page Session',
        description: 'Demonstrates MultiPageScannerWidget with page management and PDF export.',
        icon: Icons.menu_book,
        accentColor: Colors.green,
        routeName: MultiPageShowcaseScreen.routeName,
        badges: const ['Multi-page', 'Reorder'],
      ),
      FlowCardData(
        title: 'PDF Review',
        description: 'Loads PdfPreviewWidget for any scan result and highlights metadata.',
        icon: Icons.picture_as_pdf,
        accentColor: Colors.purple,
        routeName: PdfPreviewShowcaseScreen.routeName,
        badges: const ['Preview', 'Paths'],
      ),
      FlowCardData(
        title: 'Capabilities Lab',
        description: 'Toggle DocumentProcessingOptions and run camera/gallery experiments.',
        icon: Icons.science,
        accentColor: Colors.orange,
        routeName: CapabilitiesLabScreen.routeName,
        badges: const ['Direct service', 'Advanced config'],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          icon: Icons.map_outlined,
          title: 'Phased flows',
          subtitle: 'Each screen focuses on a dedicated part of the rebuilt API.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: flows.map((flow) => FlowCard(data: flow)).toList(),
        ),
      ],
    );
  }

  Widget _buildRecentResults(ShowcaseState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          icon: Icons.history,
          title: 'Recent results',
          subtitle: 'The latest scans across all flows with quick previews.',
        ),
        const SizedBox(height: 12),
        if (state.history.isEmpty)
          const EmptyState(
            icon: Icons.hourglass_empty,
            title: 'No scans yet',
            message: 'Run any showcase flow to populate this timeline.',
          )
        else
          Column(
            children: state.history.take(5).map((log) {
              final doc = log.result.document;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_flowIcon(log.flow), color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              log.flow,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          ResultStatusChip(result: log.result),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Completed at ${log.timestamp.toLocal()}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (doc != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(label: Text(doc.type.name)),
                            Chip(label: Text('${doc.isMultiPage ? doc.pages.length : 1} page(s)')),
                            if (doc.pdfPath != null) const Chip(label: Text('PDF saved')),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, PdfPreviewShowcaseScreen.routeName);
                            },
                            icon: const Icon(Icons.preview),
                            label: const Text('Open previews'),
                          ),
                        ),
                      ]
                      else if (log.result.error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          log.result.error!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  IconData _flowIcon(String flow) {
    switch (flow) {
      case 'Single Page':
        return Icons.filter_1;
      case 'Multi-Page':
        return Icons.filter_2;
      case 'PDF Preview':
        return Icons.picture_as_pdf;
      case 'Capabilities Lab':
        return Icons.science;
      default:
        return Icons.history;
    }
  }

  void _showManualTests(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: const [
              SectionHeader(
                icon: Icons.rule_folder_outlined,
                title: 'Manual test checklist',
                subtitle: 'Run on a physical device or emulator to validate Phase 2 showcase.',
              ),
              SizedBox(height: 12),
              ManualTestChecklist(),
            ],
          ),
        );
      },
    );
  }
}

class FlowCardData {
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String routeName;
  final List<String> badges;

  FlowCardData({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.routeName,
    required this.badges,
  });
}

class FlowCard extends StatelessWidget {
  final FlowCardData data;

  const FlowCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: data.accentColor.withValues(alpha: 0.15),
                child: Icon(data.icon, color: data.accentColor),
              ),
              const SizedBox(height: 12),
              Text(
                data.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                data.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: data.badges
                    .map((badge) => Chip(
                          label: Text(badge),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, data.routeName),
                  icon: const Icon(Icons.play_circle_fill),
                  label: const Text('Launch'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const SectionHeader({super.key, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyState({super.key, required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class ManualTestChecklist extends StatelessWidget {
  const ManualTestChecklist({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Configure custom storage and verify files land in the expected directory.',
      'Run Single Page Capture, rotate/crop in the editor, finish preview, and confirm metadata is displayed.',
      'Create a multi-page document (3+ pages), reorder at least once, and finalize the PDF.',
      'Open the PDF review screen and preview both of the above scans.',
      'Use the capabilities lab to toggle grayscale off, enable image saving, and run both camera + gallery imports.',
      'Trigger an error (deny a permission or cancel mid-flow) and confirm it is surfaced in the recent results timeline.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          ListTile(
            leading: CircleAvatar(
              radius: 14,
              child: Text('${i + 1}'),
            ),
            title: Text(steps[i]),
          ),
      ],
    );
  }
}
class SinglePageShowcaseScreen extends StatefulWidget {
  static const routeName = '/single-page';

  const SinglePageShowcaseScreen({super.key});

  @override
  State<SinglePageShowcaseScreen> createState() => _SinglePageShowcaseScreenState();
}

class _SinglePageShowcaseScreenState extends State<SinglePageShowcaseScreen> {
  DocumentType _selectedType = DocumentType.document;
  final TextEditingController _filenameController = TextEditingController();
  bool _initialized = false;
  bool _isLaunching = false;
  ScanResult? _lastResult;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final defaultName = ShowcaseStateScope.read(context).defaultFilename;
      if (defaultName != null) {
        _filenameController.text = defaultName;
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _filenameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: _isLaunching ? null : _launchScanner,
            icon: _isLaunching
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow),
            label: Text(_isLaunching ? 'Launching...' : 'Launch scanner'),
          ),
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

  Future<void> _launchScanner() async {
    setState(() => _isLaunching = true);
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

    setState(() {
      _isLaunching = false;
      if (result != null) {
        _lastResult = result;
      }
    });

    if (result != null) {
      state.addResult('Single Page', result);
    }
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
            label: Text(_isLaunching ? 'Launching...' : 'Start multi-page session'),
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
class PdfPreviewShowcaseScreen extends StatefulWidget {
  static const routeName = '/pdf-preview';

  const PdfPreviewShowcaseScreen({super.key});

  @override
  State<PdfPreviewShowcaseScreen> createState() => _PdfPreviewShowcaseScreenState();
}

class _PdfPreviewShowcaseScreenState extends State<PdfPreviewShowcaseScreen> {
  String? _loadingDocumentId;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final state = ShowcaseStateScope.watch(context);
    final documents = state.documents;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Preview Lab'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(
            icon: Icons.picture_as_pdf,
            title: 'Review PDFs before sharing',
            subtitle: 'Shows PdfPreviewWidget on top of saved files or in-memory bytes.',
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (documents.isEmpty)
            const EmptyState(
              icon: Icons.hourglass_empty,
              title: 'No documents yet',
              message: 'Run either scanner flow to generate PDFs, then revisit this screen.',
            )
          else
            Column(
              children: documents
                  .map(
                    (doc) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.metadata['customFilename'] ?? doc.pdfPath?.split('/').last ?? doc.id,
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
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _loadingDocumentId == doc.id ? null : () => _previewDocument(doc),
                                    icon: _loadingDocumentId == doc.id
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Icon(Icons.preview),
                                    label: Text(_loadingDocumentId == doc.id ? 'Loading...' : 'Preview PDF'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  tooltip: 'View metadata',
                                  onPressed: () {
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
                                  },
                                  icon: const Icon(Icons.info_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _previewDocument(ScannedDocument document) async {
    setState(() {
      _loadingDocumentId = document.id;
      _error = null;
    });

    try {
      Uint8List? pdfData = document.pdfData;
      if (pdfData == null && document.pdfPath != null) {
        final file = File(document.pdfPath!);
        if (await file.exists()) {
          pdfData = await file.readAsBytes();
        }
      }

      if (!mounted) return;

      if (pdfData == null && document.pdfPath == null) {
        setState(() => _error = 'Document ${document.id} does not have PDF data yet.');
        return;
      }

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
    } catch (e) {
      setState(() => _error = 'Failed to load PDF: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingDocumentId = null);
      }
    }
  }
}
class CapabilitiesLabScreen extends StatefulWidget {
  static const routeName = '/capabilities-lab';

  const CapabilitiesLabScreen({super.key});

  @override
  State<CapabilitiesLabScreen> createState() => _CapabilitiesLabScreenState();
}

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
  bool _isProcessing = false;
  ScanResult? _lastResult;
  String? _error;

  @override
  void dispose() {
    _filenameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capabilities Lab'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(
            icon: Icons.science,
            title: 'Toggle processing options on the fly',
            subtitle: 'Directly calls DocumentScannerService.scan/importWithProcessing to bypass the UI widgets.',
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
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
                if (doc != null) {
                  _openPreview(doc);
                }
              },
            )
          else
            const EmptyState(
              icon: Icons.tune,
              title: 'Experiment results appear here',
              message: 'Capture via camera or import a file to see how each toggle affects the output.',
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDocumentTypeSelector() {
    const options = [DocumentType.document, DocumentType.manual, DocumentType.receipt, DocumentType.other];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
                      selected: _documentType == option,
                      onSelected: (selected) {
                        if (selected) setState(() => _documentType = option);
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
            Text('PDF resolution & format', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildResolutionDropdown()),
                const SizedBox(width: 12),
                Expanded(child: _buildFormatDropdown(formats)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buildSummaryChips(),
            ),
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
              .map(
                (res) => DropdownMenuItem(
                  value: res,
                  child: Text(res.name),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _resolution = value);
            }
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
                (format) => DropdownMenuItem(
                  value: format,
                  child: Text(format.name),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _format = value);
            }
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
            onPressed: _isProcessing ? null : () => _runExperiment(useCamera: true),
            icon: _isProcessing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.camera),
            label: Text(_isProcessing ? 'Processing...' : 'Capture with camera'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isProcessing ? null : () => _runExperiment(useCamera: false),
            icon: const Icon(Icons.photo_library),
            label: const Text('Import from gallery'),
          ),
        ),
      ],
    );
  }

  Future<void> _runExperiment({required bool useCamera}) async {
    setState(() {
      _isProcessing = true;
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
        result = await DocumentScannerService().scanDocumentWithProcessing(
          documentType: _documentType,
          processingOptions: options,
          customFilename: filename,
        );
      } else {
        result = await DocumentScannerService().importDocumentWithProcessing(
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
          SnackBar(content: Text(result.error ?? 'Experiment returned an error.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Experiment failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
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
          title: 'Capabilities preview',
          onConfirm: () => Navigator.pop(previewContext),
          onCancel: () => Navigator.pop(previewContext),
        ),
      ),
    );
  }
}
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
