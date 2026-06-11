import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:document_scanner/src/services/qr_scanner_service.dart';

http.Client _respondWith(
  List<int> body, {
  int status = 200,
  String contentType = 'application/pdf',
  Map<String, String> extraHeaders = const {},
}) {
  return MockClient((request) async {
    return http.Response.bytes(
      body,
      status,
      headers: {'content-type': contentType, ...extraHeaders},
    );
  });
}

final _pdfMagic = <int>[0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x37]; // %PDF-1.7
final _jpegMagic = <int>[0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0];

void main() {
  late QRScannerService service;

  setUp(() => service = QRScannerService());

  group('downloadManualFromUrl - security', () {
    test('downloads a valid PDF over https', () async {
      final client = _respondWith(_pdfMagic);
      final doc = await service.downloadManualFromUrl(
        'https://example.com/manual.pdf',
        client: client,
      );
      expect(doc, isNotNull);
      expect(doc!.pdfData, isNotNull);
      expect(doc.rawImageData, isNull);
    });

    test('stores images as raw data for processing', () async {
      final client = _respondWith(_jpegMagic, contentType: 'image/jpeg');
      final doc = await service.downloadManualFromUrl(
        'https://example.com/manual.jpg',
        client: client,
      );
      expect(doc, isNotNull);
      expect(doc!.rawImageData, isNotNull);
      expect(doc.pdfData, isNull);
    });

    test('rejects cleartext http by default (MITM guard)', () async {
      final client = _respondWith(_pdfMagic);
      expect(
        () => service.downloadManualFromUrl(
          'http://example.com/manual.pdf',
          client: client,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('allows http only when explicitly opted in', () async {
      final client = _respondWith(_pdfMagic);
      final doc = await service.downloadManualFromUrl(
        'http://example.com/manual.pdf',
        allowInsecureHttp: true,
        client: client,
      );
      expect(doc, isNotNull);
    });

    test('rejects loopback host (SSRF guard)', () async {
      final client = _respondWith(_pdfMagic);
      expect(
        () => service.downloadManualFromUrl(
          'https://127.0.0.1/manual.pdf',
          client: client,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects private network host (SSRF guard)', () async {
      final client = _respondWith(_pdfMagic);
      expect(
        () => service.downloadManualFromUrl(
          'https://192.168.0.10/manual.pdf',
          client: client,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects link-local / cloud metadata host (SSRF guard)', () async {
      final client = _respondWith(_pdfMagic);
      expect(
        () => service.downloadManualFromUrl(
          'https://169.254.169.254/latest/meta-data/',
          client: client,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('enforces the byte cap (DoS guard)', () async {
      final big = List<int>.filled(1024, 0)
        ..setRange(0, _pdfMagic.length, _pdfMagic);
      final client = _respondWith(big);
      expect(
        () => service.downloadManualFromUrl(
          'https://example.com/huge.pdf',
          maxBytes: 256,
          client: client,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects payloads whose magic bytes do not match (content spoofing)',
        () async {
      // Claims to be a PDF but the bytes are neither PDF nor a known image.
      final client = _respondWith([0x00, 0x01, 0x02, 0x03, 0x04, 0x05]);
      expect(
        () => service.downloadManualFromUrl(
          'https://example.com/fake.pdf',
          client: client,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects non-200 responses', () async {
      final client = _respondWith(_pdfMagic, status: 404);
      expect(
        () => service.downloadManualFromUrl(
          'https://example.com/missing.pdf',
          client: client,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
