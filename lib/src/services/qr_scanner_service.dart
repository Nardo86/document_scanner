import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import '../models/scanned_document.dart';
import '../models/scan_result.dart';
import '../models/processing_options.dart';

/// Service for QR code scanning and manual download
class QRScannerService {
  
  /// Scan QR code and return result using mobile_scanner
  /// AIDEV-NOTE: Fixed UnimplementedError - returns error with guidance for proper usage
  Future<QRScanResult> scanQRCode() async {
    try {
      // This method requires BuildContext for UI navigation
      // Return error with clear guidance instead of throwing UnimplementedError
      return QRScanResult.error(
        error: 'QR scanning requires UI context. Use scanQRCodeWithUI() with BuildContext instead.',
        qrData: '',
        contentType: QRContentType.unknown,
      );
    } catch (e) {
      return QRScanResult.error(
        error: 'Failed to scan QR code: $e',
        qrData: '',
        contentType: QRContentType.unknown,
      );
    }
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

  /// Download manual from URL (typically from QR code)
  Future<ScannedDocument?> downloadManualFromUrl(String url) async {
    try {
      // Validate URL
      if (!_isValidUrl(url)) {
        throw Exception('Invalid URL format');
      }

      // Download file
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to download: HTTP ${response.statusCode}');
      }

      // Validate file type
      final contentType = response.headers['content-type'] ?? '';
      if (!_isSupportedFileType(contentType)) {
        throw Exception('Unsupported file type: $contentType');
      }

      // Extract filename from URL or Content-Disposition header
      final filename = _extractFilename(url, response.headers);
      
      // Create scanned document
      final document = ScannedDocument(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: DocumentType.manual,
        originalPath: url,
        scanTime: DateTime.now(),
        processingOptions: DocumentProcessingOptions.manual,
        metadata: {
          'source': 'download',
          'url': url,
          'contentType': contentType,
          'filename': filename,
          'fileSize': response.bodyBytes.length,
          'downloadTime': DateTime.now().toIso8601String(),
        },
      );

      // For PDF files, store directly
      if (contentType.contains('pdf')) {
        return document.copyWith(
          pdfData: response.bodyBytes,
          metadata: {
            ...document.metadata,
            'isPdf': true,
          },
        );
      }

      // For images, store as raw data for processing
      return document.copyWith(
        rawImageData: response.bodyBytes,
        metadata: {
          ...document.metadata,
          'needsProcessing': true,
        },
      );
    } catch (e) {
      throw Exception('Failed to download manual: $e');
    }
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

  /// Validate URL format
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
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
      final match = RegExp(r'filename[^;=\n]*=([^;\n]*)').firstMatch(contentDisposition);
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
  Future<bool> validateManualUrl(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200 && 
             _isSupportedFileType(response.headers['content-type'] ?? '');
    } catch (e) {
      return false;
    }
  }

  /// Get manual metadata without downloading
  Future<Map<String, dynamic>> getManualMetadata(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      
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
      return {
        'url': url,
        'error': e.toString(),
        'isValid': false,
      };
    }
  }

  /// Dispose QR scanner resources
  void dispose() {
    // _controller?.dispose();
  }
}

/// QR Scanner Screen Widget
class QRScannerScreen extends StatefulWidget {
  final Function(String) onResult;
  
  const QRScannerScreen({
    Key? key,
    required this.onResult,
  }) : super(key: key);

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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The QR code will be scanned automatically',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
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

