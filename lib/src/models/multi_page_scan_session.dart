import 'document_page.dart';
import 'processing_options.dart';
import 'scanned_document.dart';

/// Manages a multi-page document scanning session.
///
/// [MultiPageScanSession] represents an ongoing scanning session where users can
/// capture multiple pages sequentially, reorder them, and finalize into a single
/// [ScannedDocument]. This is the primary interface for multi-page workflows.
///
/// The session maintains:
/// - All captured pages in order
/// - Session metadata (start time, document type, processing options)
/// - Optional custom filename for the final document
///
/// Pages can be added, removed, or reordered. When ready, the session converts
/// to a [ScannedDocument] for finalization (PDF generation, saving, etc.).
///
/// Example:
/// ```dart
/// // Create a new multi-page session
/// final session = MultiPageScanSession(
///   sessionId: 'session-123',
///   documentType: DocumentType.document,
///   processingOptions: DocumentProcessingOptions.document,
///   startTime: DateTime.now(),
/// );
///
/// // Add pages from scanning
/// session = session.addPage(page1);
/// session = session.addPage(page2);
///
/// // Reorder if needed
/// session = session.reorderPages([page2, page1]);
///
/// // Convert to document when done
/// final document = session.toScannedDocument();
/// ```
class MultiPageScanSession {
  /// Unique identifier for this scanning session
  final String sessionId;

  /// The type of document being scanned
  final DocumentType documentType;

  /// Processing options to apply to all pages in this session
  final DocumentProcessingOptions processingOptions;

  /// Pages in the session, maintained in scan/user-specified order
  final List<DocumentPage> pages;

  /// Timestamp when the session started
  final DateTime startTime;

  /// Optional custom filename for the final document (without extension)
  final String? customFilename;

  /// Creates a new [MultiPageScanSession].
  ///
  /// The [sessionId], [documentType], [processingOptions], and [startTime] are required.
  /// Sessions start with no pages and accumulate them via [addPage].
  ///
  /// Example:
  /// ```dart
  /// final session = MultiPageScanSession(
  ///   sessionId: 'session-001',
  ///   documentType: DocumentType.document,
  ///   processingOptions: DocumentProcessingOptions.document,
  ///   startTime: DateTime.now(),
  ///   customFilename: 'my_document',
  /// );
  /// ```
  MultiPageScanSession({
    required this.sessionId,
    required this.documentType,
    required this.processingOptions,
    required this.startTime,
    this.pages = const [],
    this.customFilename,
  });

  /// Adds a new page to the end of the session.
  ///
  /// Returns a new session with the page appended. The original session is unchanged
  /// (immutable operation). Pages maintain their order as they are added.
  ///
  /// Example:
  /// ```dart
  /// final sessionWithPage = session.addPage(newPage);
  /// ```
  MultiPageScanSession addPage(DocumentPage page) {
    final updatedPages = [...pages, page];
    return MultiPageScanSession(
      sessionId: sessionId,
      documentType: documentType,
      processingOptions: processingOptions,
      startTime: startTime,
      pages: updatedPages,
      customFilename: customFilename,
    );
  }

  /// Removes a page from the session by its ID.
  ///
  /// Returns a new session with the specified page removed. If no page with that ID exists,
  /// the session is returned unchanged.
  ///
  /// Example:
  /// ```dart
  /// final sessionWithoutPage = session.removePage('page-id-123');
  /// ```
  MultiPageScanSession removePage(String pageId) {
    final updatedPages = pages.where((p) => p.id != pageId).toList();
    return MultiPageScanSession(
      sessionId: sessionId,
      documentType: documentType,
      processingOptions: processingOptions,
      startTime: startTime,
      pages: updatedPages,
      customFilename: customFilename,
    );
  }

  /// Reorders the pages in the session.
  ///
  /// Takes a new ordered list of pages and returns a session with that order.
  /// This is useful when the user wants to rearrange pages via drag-and-drop or
  /// manual selection.
  ///
  /// Example:
  /// ```dart
  /// // Reverse the order
  /// final reversed = session.reorderPages(session.pages.reversed.toList());
  ///
  /// // Or manually specify new order
  /// final reordered = session.reorderPages([page3, page1, page2]);
  /// ```
  MultiPageScanSession reorderPages(List<DocumentPage> reorderedPages) {
    return MultiPageScanSession(
      sessionId: sessionId,
      documentType: documentType,
      processingOptions: processingOptions,
      startTime: startTime,
      pages: reorderedPages,
      customFilename: customFilename,
    );
  }

  /// Checks if the session is ready for finalization into a document.
  ///
  /// A session is ready when it contains at least one page. This is typically checked
  /// before converting to [ScannedDocument] or generating output (PDF, images).
  ///
  /// Example:
  /// ```dart
  /// if (session.isReadyForFinalization) {
  ///   final document = session.toScannedDocument();
  ///   // Generate PDF, save, etc.
  /// }
  /// ```
  bool get isReadyForFinalization => pages.isNotEmpty;

  /// Returns the number of pages currently in the session.
  ///
  /// Convenience getter for [pages.length].
  ///
  /// Example:
  /// ```dart
  /// print('Document has ${session.pageCount} pages');
  /// ```
  int get pageCount => pages.length;

  /// Returns a summary map of the current session state.
  ///
  /// Useful for debugging, logging, or quick status checks without full serialization.
  ///
  /// Example:
  /// ```dart
  /// print('Session summary: ${session.summary()}');
  /// ```
  Map<String, dynamic> summary() {
    return {
      'sessionId': sessionId,
      'documentType': documentType.toString(),
      'pageCount': pageCount,
      'isReadyForFinalization': isReadyForFinalization,
      'startTime': startTime.toIso8601String(),
      'customFilename': customFilename,
    };
  }

  /// Converts this session into a final [ScannedDocument].
  ///
  /// The resulting document includes:
  /// - All pages from the session
  /// - A flag indicating whether the document is multi-page (pages.length > 1)
  /// - Metadata including page count, session start time, and custom filename
  /// - Original path from the first page (for compatibility)
  ///
  /// This is typically called when the user finishes scanning and is ready to
  /// process (crop, filter, generate PDF) the complete document.
  ///
  /// Example:
  /// ```dart
  /// final document = session.toScannedDocument();
  /// // Now you can process, save, or further edit the document
  /// ```
  ScannedDocument toScannedDocument() {
    return ScannedDocument(
      id: sessionId,
      type: documentType,
      originalPath: pages.isNotEmpty ? pages.first.originalPath : '',
      scanTime: startTime,
      processingOptions: processingOptions,
      pages: pages,
      isMultiPage: pages.length > 1,
      metadata: {
        'pageCount': pages.length,
        'sessionStartTime': startTime.toIso8601String(),
        'customFilename': customFilename,
      },
    );
  }
}
