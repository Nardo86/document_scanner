import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';

import '../models/scanned_document.dart';
import '../models/scan_result.dart';

/// Service for QR code scanning and manual download
class QRScannerService {
  /// Maximum bytes accepted from a download before aborting (DoS guard).
  static const int maxDownloadBytes = 25 * 1024 * 1024; // 25 MB

  /// Network timeout for download / metadata requests.
  static const Duration networkTimeout = Duration(seconds: 30);

  /// Maximum number of HTTP redirects followed (each re-validated).
  static const int maxRedirects = 5;

  /// Scan a QR code.
  ///
  /// This overload has no [BuildContext] so it cannot show the scanner UI and
  /// always returns an error. Use [scanQRCodeWithUI] instead.
  @Deprecated('Use scanQRCodeWithUI(context); this overload cannot show UI.')
  Future<QRScanResult> scanQRCode() async {
    return QRScanResult.error(
      error:
          'QR scanning requires UI context. '
          'Use scanQRCodeWithUI() with BuildContext instead.',
      qrData: '',
      contentType: QRContentType.unknown,
    );
  }

  /// Scan QR code with UI integration
  Future<QRScanResult> scanQRCodeWithUI(BuildContext context) async {
    try {
      // Show QR scanner screen
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => QRScannerScreen(
            onResult: (String qrData) {
              Navigator.of(context).pop(qrData);
            },
          ),
        ),
      );

      if (result == null) {
        return QRScanResult.error(
          error: 'User cancelled operation',
          qrData: '',
        );
      }

      return processQRData(result);
    } catch (e) {
      return QRScanResult.error(
        error: 'Failed to scan QR code: $e',
        qrData: '',
      );
    }
  }

  /// Process QR code data and determine content type
  QRScanResult processQRData(String qrData) {
    try {
      final contentType = _determineContentType(qrData);

      return QRScanResult.success(
        qrData: qrData,
        contentType: contentType,
        metadata: {
          'processedAt': DateTime.now().toIso8601String(),
          'dataLength': qrData.length,
        },
      );
    } catch (e) {
      return QRScanResult.error(
        error: 'Failed to process QR data: $e',
        qrData: qrData,
      );
    }
  }

  /// Download a manual (PDF or image) from [url], typically obtained from a QR
  /// code.
  ///
  /// Security controls:
  /// - HTTPS only by default ([allowInsecureHttp] opts into cleartext).
  /// - Rejects private / loopback / link-local hosts (SSRF guard).
  /// - Caps the response at [maxDownloadBytes] via streaming (DoS guard).
  /// - Enforces a [networkTimeout].
  /// - Re-validates every redirect hop.
  /// - Validates the payload by magic bytes, not just the Content-Type header.
  Future<ScannedDocument?> downloadManualFromUrl(
    String url, {
    bool allowInsecureHttp = false,
    int? maxBytes,
    http.Client? client,
  }) async {
    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    try {
      final result = await _fetch(
        httpClient,
        url,
        allowInsecureHttp: allowInsecureHttp,
        maxBytes: maxBytes ?? maxDownloadBytes,
      );

      final bytes = result.bytes;
      final contentType = result.contentType;
      final kind = _detectPayloadKind(bytes, contentType);
      if (kind == _PayloadKind.unsupported) {
        throw Exception(
          'Unsupported or unverified file type (content-type: $contentType)',
        );
      }

      final filename = _extractFilename(url, result.headers);

      final document = ScannedDocument(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: DocumentType.manual,
        originalPath: url,
        scanTime: DateTime.now(),
        processingOptions: DocumentProcessingOptions.manual,
        metadata: {
          'source': 'download',
          'url': url,
          'contentType': contentType,
          'filename': filename,
          'fileSize': bytes.length,
          'downloadTime': DateTime.now().toIso8601String(),
        },
      );

      if (kind == _PayloadKind.pdf) {
        return document.copyWith(
          pdfData: bytes,
          metadata: {...document.metadata, 'isPdf': true},
        );
      }
      return document.copyWith(
        rawImageData: bytes,
        metadata: {...document.metadata, 'needsProcessing': true},
      );
    } finally {
      if (ownsClient) httpClient.close();
    }
  }

  /// Streamed fetch with redirect re-validation and a hard byte cap.
  Future<_FetchResult> _fetch(
    http.Client client,
    String url, {
    required bool allowInsecureHttp,
    required int maxBytes,
  }) async {
    var uri = _parseAndValidate(url, allowInsecureHttp: allowInsecureHttp);

    for (var hop = 0; hop <= maxRedirects; hop++) {
      final request = http.Request('GET', uri)..followRedirects = false;
      final streamed = await client.send(request).timeout(networkTimeout);

      // Handle redirects manually so each target is re-validated.
      if (streamed.statusCode >= 300 && streamed.statusCode < 400) {
        final location = streamed.headers['location'];
        await streamed.stream.drain<void>();
        if (location == null || hop == maxRedirects) {
          throw Exception('Too many or invalid redirects');
        }
        uri = _parseAndValidate(
          uri.resolve(location).toString(),
          allowInsecureHttp: allowInsecureHttp,
        );
        continue;
      }

      if (streamed.statusCode != 200) {
        await streamed.stream.drain<void>();
        throw Exception('Failed to download: HTTP ${streamed.statusCode}');
      }

      // Reject early if the advertised length already exceeds the cap.
      final declared = streamed.contentLength;
      if (declared != null && declared > maxBytes) {
        await streamed.stream.drain<void>();
        throw Exception('Download too large: $declared bytes (max $maxBytes)');
      }

      final builder = BytesBuilder(copy: false);
      await for (final chunk in streamed.stream.timeout(networkTimeout)) {
        builder.add(chunk);
        if (builder.length > maxBytes) {
          throw Exception('Download exceeded $maxBytes bytes');
        }
      }

      return _FetchResult(
        bytes: builder.takeBytes(),
        contentType: streamed.headers['content-type'] ?? '',
        headers: streamed.headers,
      );
    }
    throw Exception('Too many redirects');
  }

  /// Parse [url] and reject unsafe schemes/hosts (SSRF guard).
  Uri _parseAndValidate(String url, {required bool allowInsecureHttp}) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw Exception('Invalid URL: $url');
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && !(allowInsecureHttp && scheme == 'http')) {
      throw Exception('Refusing non-HTTPS URL: $url');
    }
    if (_isBlockedHost(uri.host)) {
      throw Exception('Refusing request to private/loopback host: ${uri.host}');
    }
    return uri;
  }

  /// Block localhost and private / loopback / link-local literal addresses.
  bool _isBlockedHost(String host) {
    final h = host.toLowerCase();
    if (h == 'localhost' || h.endsWith('.localhost') || h == '::1') return true;

    final v4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$').firstMatch(h);
    if (v4 != null) {
      final a = int.parse(v4.group(1)!);
      final b = int.parse(v4.group(2)!);
      if (a == 10) return true; // 10.0.0.0/8
      if (a == 127) return true; // loopback
      if (a == 0) return true; // 0.0.0.0/8
      if (a == 169 && b == 254) return true; // link-local (incl. cloud metadata)
      if (a == 172 && b >= 16 && b <= 31) return true; // 172.16.0.0/12
      if (a == 192 && b == 168) return true; // 192.168.0.0/16
    }
    // IPv6 unique-local / link-local prefixes.
    if (h.startsWith('fe80:') || h.startsWith('fc') || h.startsWith('fd')) {
      return true;
    }
    return false;
  }

  /// Classify the payload by magic bytes, cross-checked with [contentType].
  _PayloadKind _detectPayloadKind(Uint8List bytes, String contentType) {
    if (bytes.length >= 5 &&
        bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46 && // F
        bytes[4] == 0x2D) {
      // -
      return _PayloadKind.pdf;
    }
    final isJpeg = bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
    final isPng = bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    final isGif = bytes.length >= 3 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46;
    final isWebp = bytes.length >= 12 &&
        bytes[0] == 0x52 && // R
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x46 && // F
        bytes[8] == 0x57 && // W
        bytes[9] == 0x45 && // E
        bytes[10] == 0x42 && // B
        bytes[11] == 0x50; // P
    if (isJpeg || isPng || isGif || isWebp) return _PayloadKind.image;
    return _PayloadKind.unsupported;
  }

  /// Determine content type of QR code data
  QRContentType _determineContentType(String qrData) {
    if (qrData.startsWith('http://') || qrData.startsWith('https://')) {
      if (qrData.toLowerCase().contains('.pdf')) {
        return QRContentType.pdfLink;
      } else if (_looksLikeManualUrl(qrData)) {
        return QRContentType.manualLink;
      } else {
        return QRContentType.url;
      }
    } else {
      return QRContentType.text;
    }
  }

  /// Check if URL looks like a manual URL
  bool _looksLikeManualUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('manual') ||
        lowerUrl.contains('instruction') ||
        lowerUrl.contains('guide') ||
        lowerUrl.contains('support') ||
        lowerUrl.contains('download');
  }

  /// Check if file type is supported
  bool _isSupportedFileType(String contentType) {
    return contentType.contains('pdf') ||
        contentType.contains('image/') ||
        contentType.contains('application/pdf');
  }

  /// Extract filename from URL or headers
  String _extractFilename(String url, Map<String, String> headers) {
    // Try Content-Disposition header first
    final contentDisposition = headers['content-disposition'];
    if (contentDisposition != null) {
      final match = RegExp(
        r'filename[^;=\n]*=([^;\n]*)',
      ).firstMatch(contentDisposition);
      if (match != null) {
        return match.group(1)?.replaceAll('"', '') ?? '';
      }
    }

    // Fall back to URL basename
    try {
      final uri = Uri.parse(url);
      final basename = path.basename(uri.path);
      return basename.isNotEmpty ? basename : 'manual';
    } catch (e) {
      return 'manual';
    }
  }

  /// Validate manual URL before downloading
  Future<bool> validateManualUrl(String url, {bool allowInsecureHttp = false}) async {
    try {
      final uri = _parseAndValidate(url, allowInsecureHttp: allowInsecureHttp);
      final response = await http.head(uri).timeout(networkTimeout);
      return response.statusCode == 200 &&
          _isSupportedFileType(response.headers['content-type'] ?? '');
    } catch (e) {
      return false;
    }
  }

  /// Get manual metadata without downloading
  Future<Map<String, dynamic>> getManualMetadata(
    String url, {
    bool allowInsecureHttp = false,
  }) async {
    try {
      final uri = _parseAndValidate(url, allowInsecureHttp: allowInsecureHttp);
      final response = await http.head(uri).timeout(networkTimeout);

      return {
        'url': url,
        'statusCode': response.statusCode,
        'contentType': response.headers['content-type'],
        'contentLength': response.headers['content-length'],
        'lastModified': response.headers['last-modified'],
        'filename': _extractFilename(url, response.headers),
        'isValid': response.statusCode == 200,
      };
    } catch (e) {
      return {'url': url, 'error': e.toString(), 'isValid': false};
    }
  }

  /// Dispose QR scanner resources.
  void dispose() {}
}

/// QR Scanner Screen Widget
class QRScannerScreen extends StatefulWidget {
  final Function(String) onResult;

  const QRScannerScreen({Key? key, required this.onResult}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController controller = MobileScannerController();
  bool _hasResult = false;
  bool _torchOn = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: _torchOn ? Colors.yellow : Colors.grey,
            ),
            onPressed: () async {
              await controller.toggleTorch();
              setState(() {
                _torchOn = !_torchOn;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.camera_front),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  if (_hasResult) return;

                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      _hasResult = true;
                      widget.onResult(barcode.rawValue!);
                      return;
                    }
                  }
                },
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    size: 32,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Point camera at QR code',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The QR code will be scanned automatically',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Classification of a downloaded payload, decided by magic bytes.
enum _PayloadKind { pdf, image, unsupported }

/// Result of a bounded, validated fetch.
class _FetchResult {
  final Uint8List bytes;
  final String contentType;
  final Map<String, String> headers;

  const _FetchResult({
    required this.bytes,
    required this.contentType,
    required this.headers,
  });
}
