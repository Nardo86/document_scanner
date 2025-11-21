import 'package:flutter/material.dart';

import 'screens/capabilities_lab_screen.dart';
import 'screens/multi_page_screen.dart';
import 'screens/pdf_preview_screen.dart';
import 'screens/single_page_screen.dart';
import 'state/showcase_state.dart';

enum _ShowcaseTab {
  quickScan,
  multiScan,
  lab,
}

class DocumentScannerShowcaseApp extends StatefulWidget {
  const DocumentScannerShowcaseApp({super.key});

  @override
  State<DocumentScannerShowcaseApp> createState() => _DocumentScannerShowcaseAppState();
}

class _DocumentScannerShowcaseAppState extends State<DocumentScannerShowcaseApp> {
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
          PdfPreviewShowcaseScreen.routeName: (_) => const PdfPreviewShowcaseScreen(),
          CapabilitiesLabScreen.routeName: (_) => const CapabilitiesLabScreen(),
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
      body: Column(
        children: [
          // Shared configuration header
          Expanded(
            child: IndexedStack(
              index: currentIndex,
              children: _ShowcaseTab.values.map((tab) => _buildTabContent(tab)).toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTabSelected,
        destinations: _ShowcaseTab.values.map((tab) => _buildDestination(tab)).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showActionMenu(context),
        child: const Icon(Icons.more_vert),
      ),
    );
  }

  NavigationDestination _buildDestination(_ShowcaseTab tab) {
    switch (tab) {
      case _ShowcaseTab.quickScan:
        return const NavigationDestination(
          icon: Icon(Icons.flash_on),
          label: 'Quick Scan',
          selectedIcon: Icon(Icons.flash_on_outlined),
        );
      case _ShowcaseTab.multiScan:
        return const NavigationDestination(
          icon: Icon(Icons.camera_alt),
          label: 'Multi Scan',
          selectedIcon: Icon(Icons.camera_alt_outlined),
        );
      case _ShowcaseTab.lab:
        return const NavigationDestination(
          icon: Icon(Icons.science),
          label: 'Lab',
          selectedIcon: Icon(Icons.science_outlined),
        );
    }
  }

  Widget _buildTabContent(_ShowcaseTab tab) {
    switch (tab) {
      case _ShowcaseTab.quickScan:
        return const _SinglePageTab();
      case _ShowcaseTab.multiScan:
        return const _MultiPageTab();
      case _ShowcaseTab.lab:
        return const _CapabilitiesLabTab();
    }
  }

  void _showActionMenu(BuildContext context) {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 0, 0),
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

class _SinglePageTab extends StatelessWidget {
  const _SinglePageTab();

  @override
  Widget build(BuildContext context) {
    return const SinglePageScreen();
  }
}

class _MultiPageTab extends StatelessWidget {
  const _MultiPageTab();

  @override
  Widget build(BuildContext context) {
    return const MultiPageScreen();
  }
}

class _CapabilitiesLabTab extends StatelessWidget {
  const _CapabilitiesLabTab();

  @override
  Widget build(BuildContext context) {
    return const CapabilitiesLabScreen();
  }
}

class _ConfigurationDialog extends StatefulWidget {
  const _ConfigurationDialog();

  @override
  State<_ConfigurationDialog> createState() => _ConfigurationDialogState();
}

class _ConfigurationDialogState extends State<_ConfigurationDialog> {
  late TextEditingController _appNameController;
  late TextEditingController _directoryController;
  late TextEditingController _filenameController;

  @override
  void initState() {
    super.initState();
    final state = ShowcaseStateScope.read(context);
    _appNameController = TextEditingController(text: state.appName);
    _directoryController = TextEditingController(text: state.customDirectory ?? '');
    _filenameController = TextEditingController(text: state.defaultFilename ?? '');
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
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            ShowcaseStateScope.read(context).configureStorage(
              appName: _appNameController.text,
              customDirectory: _directoryController.text,
            );
            ShowcaseStateScope.read(context).setDefaultFilename(_filenameController.text);
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

class _HistoryDialog extends StatelessWidget {
  const _HistoryDialog();

  IconData _flowIcon(String flow) {
    switch (flow) {
      case 'Single Page Capture':
        return Icons.document_scanner;
      case 'Multi-Page Session':
        return Icons.menu_book;
      case 'Capabilities Lab':
        return Icons.science;
      default:
        return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ShowcaseStateScope.watch(context);
    
    return AlertDialog(
      title: const Text('Scan History'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: state.history.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hourglass_empty, size: 48),
                    SizedBox(height: 16),
                    Text('No scans yet'),
                    Text('Run any showcase flow to populate this timeline.'),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: state.history.length,
                itemBuilder: (context, index) {
                  final log = state.history[index];
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
                              if (log.result.success)
                                const Icon(Icons.check_circle, color: Colors.green)
                              else
                                const Icon(Icons.error, color: Colors.red),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Completed at ${log.timestamp.toLocal()}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (doc != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Pages: ${doc.pages.length}',
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
