import 'package:document_scanner/document_scanner.dart';
import 'package:flutter/material.dart';

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
