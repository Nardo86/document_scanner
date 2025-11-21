import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../state/showcase_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/scan_result_details.dart';
import '../widgets/section_header.dart';
import 'capabilities_lab_screen.dart';
import 'multi_page_screen.dart';
import 'pdf_preview_screen.dart';
import 'single_page_screen.dart';

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
        routeName: SinglePageScreen.routeName,
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
      case 'Single Page (Camera)':
        return Icons.camera_alt_outlined;
      case 'Single Page (Gallery)':
        return Icons.photo_library_outlined;
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
