import 'package:document_scanner/document_scanner.dart';
import 'package:flutter/material.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DocumentScannerService().configureStorage(appName: 'DocumentScannerShowcase');
  runApp(const DocumentScannerShowcaseApp());
}
