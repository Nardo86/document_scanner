import 'package:flutter/material.dart';

import 'screens/capabilities_lab_screen.dart';
import 'screens/multi_page_screen.dart';
import 'screens/pdf_preview_screen.dart';
import 'screens/single_page_screen.dart';
import 'state/showcase_state.dart';

enum _ShowcaseTab { quickScan, multiScan, lab }

class DocumentScannerShowcaseApp extends StatefulWidget {
  const DocumentScannerShowcaseApp({super.key});

  @override
  State<DocumentScannerShowcaseApp> createState() =>
      _DocumentScannerShowcaseAppState();
}

class _DocumentScannerShowcaseAppState
    extends State<DocumentScannerShowcaseApp> {
  late final ShowcaseState _state;
  int _currentIndex = 0;

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
          SinglePageScreen.routeName: (_) => const SinglePageScreen(),
          MultiPageScreen.routeName: (_) => const MultiPageScreen(),
          PdfPreviewShowcaseScreen.routeName: (_) =>
              const PdfPreviewShowcaseScreen(),
          CapabilitiesLabScreen.routeName: (_) =>
              const CapabilitiesLabScreen(),
        },
        home: _TabNavigationShell(
          currentIndex: _currentIndex,
          onTabSelected: (index) => setState(() => _currentIndex = index),
        ),
      ),
    );
  }
}

class _TabNavigationShell extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const _TabNavigationShell({
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: const [
          SinglePageScreen(),
          MultiPageScreen(),
          CapabilitiesLabScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTabSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.flash_on_outlined),
            selectedIcon: Icon(Icons.flash_on),
            label: 'Quick Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Multi Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science),
            label: 'Lab',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => _showActionMenu(context),
        child: const Icon(Icons.more_vert),
      ),
    );
  }

  void _showActionMenu(BuildContext context) {
    final button = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final screenSize = MediaQuery.sizeOf(context);

    final position = button != null && overlay != null
        ? RelativeRect.fromRect(
            button.localToGlobal(Offset.zero) & button.size,
            Offset.zero & overlay.size,
          )
        : RelativeRect.fromLTRB(
            screenSize.width - 200, screenSize.height - 200, 16, 80);

    showMenu(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          onTap: () => _showConfigurationDialog(context),
          child: const Row(
            children: [
              Icon(Icons.settings),
              SizedBox(width: 8),
              Text('Storage Configuration'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () => _showHistoryDialog(context),
          child: const Row(
            children: [
              Icon(Icons.history),
              SizedBox(width: 8),
              Text('Scan History'),
            ],
          ),
        ),
      ],
    );
  }

  void _showConfigurationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _ConfigurationDialog(),
    );
  }

  void _showHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _HistoryDialog(),
    );
  }
}

// ---------------------------------------------------------------------------
// Configuration dialog
// ---------------------------------------------------------------------------

class _ConfigurationDialog extends StatefulWidget {
  const _ConfigurationDialog();

  @override
  State<_ConfigurationDialog> createState() => _ConfigurationDialogState();
}

class _ConfigurationDialogState extends State<_ConfigurationDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _appNameController;
  late TextEditingController _directoryController;
  late TextEditingController _filenameController;

  static final _unsafeChars = RegExp(r'[<>:"/\\|?*]');

  @override
  void initState() {
    super.initState();
    final state = ShowcaseStateScope.read(context);
    _appNameController = TextEditingController(text: state.appName);
    _directoryController =
        TextEditingController(text: state.customDirectory ?? '');
    _filenameController =
        TextEditingController(text: state.defaultFilename ?? '');
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

    return AlertDialog(
      title: const Text('Storage Configuration'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _appNameController,
                decoration: const InputDecoration(
                  labelText: 'App name',
                  prefixIcon: Icon(Icons.apps),
                  helperText: 'Letters, numbers, hyphens, underscores',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'App name cannot be empty';
                  }
                  if (_unsafeChars.hasMatch(value)) {
                    return 'Contains invalid characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _directoryController,
                decoration: const InputDecoration(
                  labelText: 'Custom storage directory (optional)',
                  hintText: '/storage/emulated/0/Documents/MyApp',
                  prefixIcon: Icon(Icons.folder),
                ),
                validator: (value) {
                  if (value != null &&
                      value.trim().isNotEmpty &&
                      !value.trim().startsWith('/')) {
                    return 'Must be an absolute path (starts with /)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _filenameController,
                decoration: const InputDecoration(
                  labelText: 'Default filename (optional)',
                  hintText: 'project-proposal',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: (value) {
                  if (value != null &&
                      value.trim().isNotEmpty &&
                      _unsafeChars.hasMatch(value)) {
                    return 'Contains invalid characters';
                  }
                  return null;
                },
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            _appNameController.text = 'DocumentScannerShowcase';
            _directoryController.clear();
            _filenameController.clear();
            ShowcaseStateScope.read(context).resetStorage();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Configuration reset to defaults')),
            );
          },
          child: const Text('Reset'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            ShowcaseStateScope.read(context).configureStorage(
              appName: _appNameController.text,
              customDirectory: _directoryController.text,
            );
            ShowcaseStateScope.read(context)
                .setDefaultFilename(_filenameController.text);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Storage configuration applied')),
            );
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// History dialog
// ---------------------------------------------------------------------------

class _HistoryDialog extends StatelessWidget {
  const _HistoryDialog();

  IconData _flowIcon(String flow) {
    if (flow.contains('Single') || flow.contains('Camera') || flow.contains('Gallery')) {
      return Icons.document_scanner;
    }
    if (flow.contains('Multi')) return Icons.menu_book;
    if (flow.contains('Lab') || flow.contains('Capabilities')) {
      return Icons.science;
    }
    return Icons.history;
  }

  @override
  Widget build(BuildContext context) {
    final state = ShowcaseStateScope.watch(context);
    final screenHeight = MediaQuery.sizeOf(context).height;

    return AlertDialog(
      title: const Text('Scan History'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: screenHeight * 0.55,
        ),
        child: SizedBox(
          width: double.maxFinite,
          child: state.history.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_empty, size: 48),
                      SizedBox(height: 16),
                      Text('No scans yet'),
                      SizedBox(height: 4),
                      Text('Run any flow to populate this timeline.'),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: state.history.length,
                  itemBuilder: (context, index) {
                    final log = state.history[index];
                    final doc = log.result.document;
                    final colorScheme = Theme.of(context).colorScheme;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(_flowIcon(log.flow),
                                    color: colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    log.flow,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                                Icon(
                                  log.result.success
                                      ? Icons.check_circle
                                      : Icons.error,
                                  color: log.result.success
                                      ? colorScheme.primary
                                      : colorScheme.error,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimestamp(log.timestamp),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (doc != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Pages: ${doc.isMultiPage ? doc.pages.length : 1}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime ts) {
    final h = ts.hour.toString().padLeft(2, '0');
    final m = ts.minute.toString().padLeft(2, '0');
    final now = DateTime.now();
    if (ts.year == now.year && ts.month == now.month && ts.day == now.day) {
      return 'Today $h:$m';
    }
    return '${ts.day}/${ts.month} $h:$m';
  }
}
