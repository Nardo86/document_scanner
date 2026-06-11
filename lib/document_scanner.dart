/// Document Scanner — a Flutter library for scanning documents, receipts and
/// manuals with manual/automatic cropping, perspective correction, colour
/// filters and PDF generation.
///
/// The public surface is intentionally small: domain models, the orchestrator
/// [DocumentScannerService], the QR helper, and the ready-made widgets. Internal
/// services (image processing, storage, PDF generation) are implementation
/// details and are *not* exported, so they can evolve without breaking changes.
library;

// Domain models and result types.
export 'src/models/scanned_document.dart';
export 'src/models/scan_result.dart';

// Orchestrator and QR helper (public entry points).
export 'src/services/document_scanner_service.dart';
export 'src/services/qr_scanner_service.dart'
    show QRScannerService, QRScannerScreen;

// Ready-made UI widgets.
export 'src/ui/document_scanner_widget.dart';
export 'src/ui/multi_page_scanner_widget.dart';
export 'src/ui/image_editing_widget.dart' show ImageEditingWidget;
export 'src/ui/pdf_preview_widget.dart' show PdfPreviewWidget;
export 'src/ui/document_camera_screen.dart'
    show DocumentCameraScreen, CameraGuideResult;
