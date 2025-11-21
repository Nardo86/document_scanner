import 'package:flutter/material.dart';

import 'screens/capabilities_lab_screen.dart';
import 'screens/home_screen.dart';
import 'screens/multi_page_screen.dart';
import 'screens/pdf_preview_screen.dart';
import 'screens/single_page_screen.dart';
import 'state/showcase_state.dart';

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
          SinglePageScreen.routeName: (_) => const SinglePageScreen(),
          MultiPageShowcaseScreen.routeName: (_) => const MultiPageShowcaseScreen(),
          PdfPreviewShowcaseScreen.routeName: (_) => const PdfPreviewShowcaseScreen(),
          CapabilitiesLabScreen.routeName: (_) => const CapabilitiesLabScreen(),
        },
        home: const ShowcaseHomeScreen(),
      ),
    );
  }
}
