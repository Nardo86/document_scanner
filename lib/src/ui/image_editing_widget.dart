import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/scanned_document.dart';
import '../services/image_processor.dart';

/// Widget for editing scanned images: rotation, colour filters, and cropping.
///
/// State model is **declarative**: the editor tracks the current rotation,
/// crop quad, colour filter and document format, and re-renders the preview by
/// applying that pipeline to the *original* image every time. This avoids the
/// cumulative JPEG re-encoding / stale-state bugs of an incremental approach
/// and makes rotation/crop interaction (issues #30/#31/#32) coherent:
///
/// - Rotation re-derives the full (uncropped) base image and clears the crop,
///   re-detecting edges in the new orientation — the crop tool stays available.
/// - Reset-crop simply drops the crop quad (no double-rotation).
/// - Changing the document format only re-renders; it never auto-commits a crop.
class ImageEditingWidget extends StatefulWidget {
  final Uint8List imageData;
  final void Function(
    Uint8List editedImageData,
    PdfResolution selectedResolution,
    DocumentFormat selectedFormat,
  )
  onImageEdited;
  final VoidCallback? onCancel;

  /// Optional already-processed preview shown before the first render.
  final Uint8List? initialPreviewData;

  /// Optional initial crop corners (in [imageData] pixel coordinates).
  final List<Offset>? initialCropCorners;

  const ImageEditingWidget({
    super.key,
    required this.imageData,
    required this.onImageEdited,
    this.onCancel,
    this.initialPreviewData,
    this.initialCropCorners,
  });

  @override
  State<ImageEditingWidget> createState() => _ImageEditingWidgetState();
}

class _ImageEditingWidgetState extends State<ImageEditingWidget> {
  final ImageProcessor _imageProcessor = ImageProcessor();

  /// Original captured image — never mutated.
  late final Uint8List _rawImage;

  /// Raw image rotated by [_rotation] (the canvas the user crops on).
  Uint8List? _baseImage;

  /// Rendered result: rotation → crop → filter applied to [_rawImage].
  Uint8List? _previewImageData;

  /// Corners shown/edited in the crop overlay, in [_baseImage] coordinates.
  List<Offset>? _detectedCorners;

  /// Committed crop quad (null = no crop), in [_baseImage] coordinates.
  List<Offset>? _cropCorners;

  DocumentColorFilter _filter = DocumentColorFilter.none;
  DocumentFormat _format = DocumentFormat.auto;
  int _rotation = 0; // 0, 90, 180, 270 (clockwise)

  PdfResolution _selectedResolution = PdfResolution.size;

  bool _isProcessing = false;
  bool _showCropOverlay = false;
  bool _isSettingsExpanded = false;

  @override
  void initState() {
    super.initState();
    _rawImage = widget.imageData;
    _previewImageData = widget.initialPreviewData ?? widget.imageData;
    _baseImage = widget.imageData;

    if (widget.initialCropCorners != null &&
        widget.initialCropCorners!.length == 4) {
      _cropCorners = widget.initialCropCorners;
      _detectedCorners = widget.initialCropCorners;
    } else {
      _detectEdges(_rawImage);
    }
  }

  @override
  void dispose() {
    _imageProcessor.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Rendering pipeline (always derived from the raw image)
  // ---------------------------------------------------------------------------

  ImageEditingOptions get _currentOptions => ImageEditingOptions(
    rotationDegrees: _rotation,
    colorFilter: _filter,
    cropCorners: _cropCorners,
    documentFormat: _format,
  );

  /// Re-render the preview from the raw image applying the full pipeline.
  Future<void> _renderPreview() async {
    setState(() => _isProcessing = true);
    try {
      final preview = await _imageProcessor.applyImageEditing(
        _rawImage,
        _currentOptions,
      );
      if (!mounted) return;
      setState(() {
        _previewImageData = preview;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showSnack('Error updating preview: $e');
    }
  }

  /// Re-derive the (uncropped) base image for the current rotation.
  Future<void> _renderBase() async {
    final base = await _imageProcessor.applyImageEditing(
      _rawImage,
      ImageEditingOptions(rotationDegrees: _rotation),
    );
    if (!mounted) return;
    setState(() => _baseImage = base);
  }

  // ---------------------------------------------------------------------------
  // Edge detection
  // ---------------------------------------------------------------------------

  Future<void> _detectEdges(Uint8List imageData) async {
    try {
      final corners = await _imageProcessor.detectDocumentEdges(imageData);
      if (!mounted) return;
      if (corners.length == 4) {
        setState(() => _detectedCorners = corners);
        return;
      }
    } catch (_) {
      if (!mounted) return;
    }
    await _setProportionalFallbackCorners(imageData);
  }

  Future<void> _setProportionalFallbackCorners(Uint8List imageData) async {
    if (!mounted) return;
    try {
      final codec = await ui.instantiateImageCodec(imageData);
      final frame = await codec.getNextFrame();
      final w = frame.image.width.toDouble();
      final h = frame.image.height.toDouble();
      frame.image.dispose();
      if (!mounted) return;
      const inset = 0.05;
      setState(() {
        _detectedCorners = [
          Offset(w * inset, h * inset),
          Offset(w * (1 - inset), h * inset),
          Offset(w * (1 - inset), h * (1 - inset)),
          Offset(w * inset, h * (1 - inset)),
        ];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _detectedCorners = const [
          Offset(50, 50),
          Offset(300, 50),
          Offset(300, 400),
          Offset(50, 400),
        ];
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _rotateClockwise() => _applyRotation(90);
  void _rotateCounterclockwise() => _applyRotation(-90);

  /// Rotate by [degrees] (±90).
  ///
  /// Per issue #32, rotation discards any crop and re-detects edges on the
  /// freshly-rotated full image, keeping the crop tool available.
  Future<void> _applyRotation(int degrees) async {
    setState(() {
      _rotation = (_rotation + degrees) % 360;
      if (_rotation < 0) _rotation += 360;
      _cropCorners = null;
      _detectedCorners = null;
      _showCropOverlay = false;
    });
    await _renderBase();
    if (!mounted) return;
    await _renderPreview();
    if (!mounted || _baseImage == null) return;
    await _detectEdges(_baseImage!);
  }

  void _setColorFilter(DocumentColorFilter filter) {
    if (_filter == filter) return;
    setState(() => _filter = filter);
    _renderPreview();
    if (mounted && filter != DocumentColorFilter.none) {
      _showSnack('${_getFilterName(filter)} filter applied', isError: false);
    }
  }

  void _toggleCropMode() {
    setState(() {
      _showCropOverlay = !_showCropOverlay;
      if (_showCropOverlay) {
        _detectedCorners = _cropCorners ?? _detectedCorners;
      }
    });
    if (!_showCropOverlay) {
      _renderPreview();
    }
  }

  Future<void> _applyCrop() async {
    if (_detectedCorners == null || _detectedCorners!.length != 4) return;
    setState(() {
      _cropCorners = _detectedCorners;
      _showCropOverlay = false;
    });
    await _renderPreview();
  }

  /// Issue #31: drop the crop and return to the full (rotated) image.
  Future<void> _resetCrop() async {
    setState(() {
      _cropCorners = null;
      _showCropOverlay = false;
    });
    await _renderPreview();
    if (mounted && _baseImage != null) {
      await _detectEdges(_baseImage!);
    }
  }

  Future<void> _resetEditing() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all edits?'),
        content: const Text('This discards rotation, crop and filter changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _rotation = 0;
      _filter = DocumentColorFilter.none;
      _format = DocumentFormat.auto;
      _cropCorners = null;
      _detectedCorners = null;
      _showCropOverlay = false;
      _baseImage = _rawImage;
      _previewImageData = _rawImage;
    });
    await _detectEdges(_rawImage);
  }

  void _setResolution(PdfResolution resolution) {
    setState(() => _selectedResolution = resolution);
  }

  void _setDocumentFormat(DocumentFormat format) {
    setState(() => _format = format);
    // Format only affects the final render; never auto-commit a crop.
    if (!_showCropOverlay) {
      _renderPreview();
    }
  }

  void _confirmEditing() {
    final preview = _previewImageData;
    if (preview != null) {
      widget.onImageEdited(preview, _selectedResolution, _format);
    }
  }

  void _showSnack(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: isError ? 3 : 1),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Image'),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: widget.onCancel,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isProcessing ? null : _resetEditing,
            tooltip: 'Reset',
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isProcessing ? null : _confirmEditing,
            tooltip: 'Confirm',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: scheme.surfaceContainerHighest,
              child: Center(child: _buildPreviewArea()),
            ),
          ),
          _buildControls(context),
        ],
      ),
    );
  }

  Widget _buildPreviewArea() {
    if (_isProcessing) {
      return const CircularProgressIndicator();
    }
    final preview = _previewImageData;
    if (preview == null) {
      return const Icon(Icons.image, size: 64);
    }
    if (_showCropOverlay && _detectedCorners != null) {
      return CropOverlayWidget(
        imageData: _baseImage ?? widget.imageData,
        corners: _detectedCorners!,
        onCornersChanged: (newCorners) {
          setState(() => _detectedCorners = newCorners);
        },
      );
    }
    return InteractiveViewer(
      child: Image.memory(
        preview,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) =>
            const Icon(Icons.broken_image, size: 64),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isSettingsExpanded = !_isSettingsExpanded),
      onVerticalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -500) {
          setState(() => _isSettingsExpanded = true);
        } else if (v > 500) {
          setState(() => _isSettingsExpanded = false);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToolRow(),
            const SizedBox(height: 12),
            if (_isSettingsExpanded)
              _buildExpandedSettings(context)
            else
              _buildCompactSettings(),
          ],
        ),
      ),
    );
  }

  Widget _buildToolRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          onPressed: _isProcessing ? null : _rotateCounterclockwise,
          icon: const Icon(Icons.rotate_left),
          tooltip: 'Rotate Left',
        ),
        IconButton(
          onPressed: _isProcessing ? null : _rotateClockwise,
          icon: const Icon(Icons.rotate_right),
          tooltip: 'Rotate Right',
        ),
        IconButton(
          onPressed: _isProcessing ? null : _toggleCropMode,
          icon: Icon(_showCropOverlay ? Icons.crop_free : Icons.crop),
          tooltip: _showCropOverlay ? 'Disable Crop' : 'Enable Crop',
        ),
        if (_showCropOverlay)
          IconButton(
            onPressed: _isProcessing ? null : _applyCrop,
            icon: const Icon(Icons.check),
            tooltip: 'Apply Crop',
            color: Colors.green,
          ),
        if (!_showCropOverlay && _cropCorners != null)
          IconButton(
            onPressed: _isProcessing ? null : _resetCrop,
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset Crop',
            color: Colors.orange,
          ),
      ],
    );
  }

  Widget _buildCompactSettings() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActiveSettingIndicator(
          'Filter',
          _getColorFilterIcon(_filter),
          _filter != DocumentColorFilter.none,
        ),
        _buildActiveSettingIndicator(
          'Format',
          _getDocumentFormatIcon(_format),
          _format != DocumentFormat.auto,
        ),
        _buildActiveSettingIndicator(
          'PDF',
          _getResolutionIcon(_selectedResolution),
          _selectedResolution != PdfResolution.size,
        ),
        IconButton(
          onPressed: () => setState(() => _isSettingsExpanded = true),
          icon: const Icon(Icons.settings),
          tooltip: 'Show All Settings',
        ),
      ],
    );
  }

  Widget _buildExpandedSettings(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: () => setState(() => _isSettingsExpanded = false),
              icon: const Icon(Icons.keyboard_arrow_down),
              tooltip: 'Collapse Settings',
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Color Filter:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildFilterButton(
              'Original',
              DocumentColorFilter.none,
              Icons.image,
            ),
            _buildFilterButton(
              'Enhanced',
              DocumentColorFilter.highContrast,
              Icons.auto_fix_high,
            ),
            _buildFilterButton(
              'B&W',
              DocumentColorFilter.blackAndWhite,
              Icons.filter_b_and_w,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Document Format:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFormatButton(
              'Auto',
              DocumentFormat.auto,
              Icons.auto_fix_normal,
            ),
            _buildFormatButton('A4', DocumentFormat.isoA, Icons.description),
            _buildFormatButton(
              'Letter',
              DocumentFormat.usLetter,
              Icons.document_scanner,
            ),
            _buildFormatButton('Legal', DocumentFormat.usLegal, Icons.article),
            _buildFormatButton('Receipt', DocumentFormat.receipt, Icons.receipt),
            _buildFormatButton(
              'Square',
              DocumentFormat.square,
              Icons.crop_square,
            ),
            _buildFormatButton(
              'Card',
              DocumentFormat.businessCard,
              Icons.credit_card,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'PDF Quality:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildResolutionButton(
              'Standard',
              PdfResolution.size,
              Icons.compress,
            ),
            _buildResolutionButton(
              'High',
              PdfResolution.quality,
              Icons.high_quality,
            ),
            _buildResolutionButton('Max', PdfResolution.original, Icons.hd),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveSettingIndicator(String label, IconData icon, bool active) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => setState(() => _isSettingsExpanded = true),
          icon: Icon(icon, color: active ? scheme.primary : scheme.outline),
          style: IconButton.styleFrom(
            backgroundColor: active ? scheme.primaryContainer : null,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? scheme.primary : scheme.outline,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton(
    String label,
    DocumentColorFilter filter,
    IconData icon,
  ) {
    return _buildSelectableButton(
      label: label,
      icon: icon,
      selected: _filter == filter,
      onPressed: _isProcessing ? null : () => _setColorFilter(filter),
    );
  }

  Widget _buildFormatButton(String label, DocumentFormat format, IconData icon) {
    return _buildSelectableButton(
      label: label,
      icon: icon,
      selected: _format == format,
      onPressed: _isProcessing ? null : () => _setDocumentFormat(format),
    );
  }

  Widget _buildResolutionButton(
    String label,
    PdfResolution resolution,
    IconData icon,
  ) {
    return _buildSelectableButton(
      label: label,
      icon: icon,
      selected: _selectedResolution == resolution,
      onPressed: () => _setResolution(resolution),
    );
  }

  Widget _buildSelectableButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback? onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: selected ? scheme.primary : scheme.outline),
          style: IconButton.styleFrom(
            backgroundColor: selected ? scheme.primaryContainer : null,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? scheme.primary : scheme.outline,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  IconData _getColorFilterIcon(DocumentColorFilter filter) {
    switch (filter) {
      case DocumentColorFilter.none:
        return Icons.image;
      case DocumentColorFilter.highContrast:
        return Icons.auto_fix_high;
      case DocumentColorFilter.blackAndWhite:
        return Icons.filter_b_and_w;
    }
  }

  String _getFilterName(DocumentColorFilter filter) {
    switch (filter) {
      case DocumentColorFilter.none:
        return 'Original';
      case DocumentColorFilter.highContrast:
        return 'Enhanced';
      case DocumentColorFilter.blackAndWhite:
        return 'B&W';
    }
  }

  IconData _getDocumentFormatIcon(DocumentFormat format) {
    switch (format) {
      case DocumentFormat.auto:
        return Icons.auto_fix_normal;
      case DocumentFormat.isoA:
        return Icons.description;
      case DocumentFormat.usLetter:
        return Icons.document_scanner;
      case DocumentFormat.usLegal:
        return Icons.article;
      case DocumentFormat.square:
        return Icons.crop_square;
      case DocumentFormat.receipt:
        return Icons.receipt;
      case DocumentFormat.businessCard:
        return Icons.credit_card;
    }
  }

  IconData _getResolutionIcon(PdfResolution resolution) {
    switch (resolution) {
      case PdfResolution.size:
        return Icons.compress;
      case PdfResolution.quality:
        return Icons.high_quality;
      case PdfResolution.original:
        return Icons.hd;
    }
  }
}

/// Widget for interactive crop overlay with proper scaling.
class CropOverlayWidget extends StatefulWidget {
  final Uint8List imageData;
  final List<Offset> corners;
  final ValueChanged<List<Offset>> onCornersChanged;

  const CropOverlayWidget({
    super.key,
    required this.imageData,
    required this.corners,
    required this.onCornersChanged,
  });

  @override
  State<CropOverlayWidget> createState() => _CropOverlayWidgetState();
}

class _CropOverlayWidgetState extends State<CropOverlayWidget> {
  Size? _originalImageSize;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  @override
  void didUpdateWidget(CropOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageData != widget.imageData) {
      _loadImageSize();
    }
  }

  Future<void> _loadImageSize() async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(widget.imageData);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image image = frame.image;
      if (mounted) {
        setState(() {
          _originalImageSize = Size(
            image.width.toDouble(),
            image.height.toDouble(),
          );
        });
      }
      image.dispose();
    } catch (_) {
      // Image size detection failed; overlay will not render.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_originalImageSize == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
        final imageInfo = _calculateImageDisplayInfo(containerSize);

        return _CropInteractiveWidget(
          imageData: widget.imageData,
          corners: widget.corners,
          imageInfo: imageInfo,
          onCornersChanged: widget.onCornersChanged,
        );
      },
    );
  }

  ImageDisplayInfo _calculateImageDisplayInfo(Size containerSize) {
    final original = _originalImageSize!;
    final scaleX = containerSize.width / original.width;
    final scaleY = containerSize.height / original.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final displayWidth = original.width * scale;
    final displayHeight = original.height * scale;
    final offsetX = (containerSize.width - displayWidth) / 2;
    final offsetY = (containerSize.height - displayHeight) / 2;

    return ImageDisplayInfo(
      scale: scale,
      offset: Offset(offsetX, offsetY),
      displaySize: Size(displayWidth, displayHeight),
    );
  }
}

/// Interactive widget for crop overlay with real-time feedback.
class _CropInteractiveWidget extends StatefulWidget {
  final Uint8List imageData;
  final List<Offset> corners;
  final ImageDisplayInfo imageInfo;
  final ValueChanged<List<Offset>> onCornersChanged;

  const _CropInteractiveWidget({
    required this.imageData,
    required this.corners,
    required this.imageInfo,
    required this.onCornersChanged,
  });

  @override
  State<_CropInteractiveWidget> createState() => _CropInteractiveWidgetState();
}

class _CropInteractiveWidgetState extends State<_CropInteractiveWidget> {
  late List<Offset> _currentCorners;
  int? _draggedCornerIndex;

  @override
  void initState() {
    super.initState();
    _currentCorners = _convertToScreenCoordinates(
      widget.corners,
      widget.imageInfo,
    );
  }

  @override
  void didUpdateWidget(_CropInteractiveWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.corners != widget.corners ||
        oldWidget.imageInfo != widget.imageInfo) {
      _currentCorners = _convertToScreenCoordinates(
        widget.corners,
        widget.imageInfo,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Image.memory(
          widget.imageData,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stack) =>
              const Center(child: Icon(Icons.broken_image, size: 64)),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _CropOverlayPainter(
              corners: _currentCorners,
              draggedCornerIndex: _draggedCornerIndex,
            ),
            child: GestureDetector(
              onPanStart: (details) {
                final cornerIndex = _findNearestCorner(
                  details.localPosition,
                  _currentCorners,
                );
                if (cornerIndex != null) {
                  setState(() => _draggedCornerIndex = cornerIndex);
                }
              },
              onPanUpdate: (details) {
                if (_draggedCornerIndex != null) {
                  setState(() {
                    _currentCorners[_draggedCornerIndex!] =
                        details.localPosition;
                  });
                }
              },
              onPanEnd: (details) {
                if (_draggedCornerIndex != null) {
                  widget.onCornersChanged(
                    _convertToOriginalCoordinates(
                      _currentCorners,
                      widget.imageInfo,
                    ),
                  );
                  setState(() => _draggedCornerIndex = null);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  int? _findNearestCorner(Offset position, List<Offset> corners) {
    const double touchRadius = 35.0;
    for (int i = 0; i < corners.length; i++) {
      if ((position - corners[i]).distance <= touchRadius) return i;
    }
    return null;
  }

  List<Offset> _convertToScreenCoordinates(
    List<Offset> originalCorners,
    ImageDisplayInfo info,
  ) {
    return originalCorners
        .map(
          (c) => Offset(
            c.dx * info.scale + info.offset.dx,
            c.dy * info.scale + info.offset.dy,
          ),
        )
        .toList();
  }

  List<Offset> _convertToOriginalCoordinates(
    List<Offset> screenCorners,
    ImageDisplayInfo info,
  ) {
    return screenCorners
        .map(
          (c) => Offset(
            (c.dx - info.offset.dx) / info.scale,
            (c.dy - info.offset.dy) / info.scale,
          ),
        )
        .toList();
  }
}

/// Custom painter for the crop overlay.
class _CropOverlayPainter extends CustomPainter {
  final List<Offset> corners;
  final int? draggedCornerIndex;

  _CropOverlayPainter({required this.corners, this.draggedCornerIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;

    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final cropPath = Path()..moveTo(corners[0].dx, corners[0].dy);
    for (int i = 1; i < 4; i++) {
      cropPath.lineTo(corners[i].dx, corners[i].dy);
    }
    cropPath.close();
    canvas.drawPath(cropPath, borderPaint);

    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (int i = 0; i < corners.length; i++) {
      final corner = corners[i];
      final isDragged = i == draggedCornerIndex;
      final handleRadius = isDragged ? 20.0 : 16.0;
      final centerRadius = isDragged ? 10.0 : 8.0;

      final handlePaint = Paint()
        ..color = (isDragged ? Colors.orange : Colors.blue).withValues(
          alpha: 0.8,
        )
        ..style = PaintingStyle.fill;
      final strokePaint = Paint()
        ..color = isDragged ? Colors.orange : Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = isDragged ? 4 : 3;

      canvas.drawCircle(corner + const Offset(2, 2), handleRadius, shadowPaint);
      canvas.drawCircle(corner, handleRadius, handlePaint);
      canvas.drawCircle(corner, centerRadius, centerPaint);
      canvas.drawCircle(corner, centerRadius, strokePaint);
    }

    final gridPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 1; i < 3; i++) {
      final t = i / 3.0;
      canvas.drawLine(
        Offset.lerp(corners[0], corners[1], t)!,
        Offset.lerp(corners[3], corners[2], t)!,
        gridPaint,
      );
      canvas.drawLine(
        Offset.lerp(corners[0], corners[3], t)!,
        Offset.lerp(corners[1], corners[2], t)!,
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is! _CropOverlayPainter) return true;
    if (corners.length != oldDelegate.corners.length) return true;
    for (int i = 0; i < corners.length; i++) {
      if (corners[i] != oldDelegate.corners[i]) return true;
    }
    return draggedCornerIndex != oldDelegate.draggedCornerIndex;
  }
}

/// Helper class to store image display information.
class ImageDisplayInfo {
  final double scale;
  final Offset offset;
  final Size displaySize;

  ImageDisplayInfo({
    required this.scale,
    required this.offset,
    required this.displaySize,
  });
}
