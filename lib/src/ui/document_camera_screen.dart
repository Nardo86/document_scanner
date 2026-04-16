import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Result returned by [DocumentCameraScreen] after capture.
class CameraGuideResult {
  final Uint8List imageData;
  final List<Offset> corners;

  const CameraGuideResult({required this.imageData, required this.corners});
}

/// Full-screen camera with a draggable 4-corner guide overlay.
///
/// The overlay defaults to an A4 trapezoid that approximates a ~30° viewing
/// angle (narrower at top, wider at bottom). Corners are draggable so the
/// user can adjust once for their setup. On capture the guide coordinates
/// are mapped to the captured image and returned together with the raw bytes.
class DocumentCameraScreen extends StatefulWidget {
  const DocumentCameraScreen({super.key});

  @override
  State<DocumentCameraScreen> createState() => _DocumentCameraScreenState();
}

class _DocumentCameraScreenState extends State<DocumentCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  FlashMode _flashMode = FlashMode.off;

  /// Guide corners in *fractional* coordinates (0..1) relative to the
  /// preview area. Stored as fractions so they survive layout changes.
  /// Order: top-left, top-right, bottom-right, bottom-left.
  ///
  /// Default: A4-ish trapezoid for ~30° tilt.
  static List<Offset> _savedCornerFractions = _defaultTrapezoid();

  static List<Offset> _defaultTrapezoid() {
    // A4 ratio ≈ 0.707 (w/h). At ~30° tilt the top edge appears ~80%
    // of the bottom edge width due to perspective foreshortening.
    const double bottomW = 0.80;
    const double topW = 0.64; // ~80% of bottomW
    const double h = 0.70;
    const double cy = 0.50; // vertical center
    const double cx = 0.50;

    return [
      Offset(cx - topW / 2, cy - h / 2), // top-left
      Offset(cx + topW / 2, cy - h / 2), // top-right
      Offset(cx + bottomW / 2, cy + h / 2), // bottom-right
      Offset(cx - bottomW / 2, cy + h / 2), // bottom-left
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      setState(() {
        _controller = null;
        _isInitialized = false;
      });
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      // Prefer back camera
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      await controller.setFlashMode(_flashMode);

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitialized = true;
      });
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _toggleFlash() async {
    final next = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await _controller?.setFlashMode(next);
    setState(() => _flashMode = next);
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      // Turn off torch for capture, use flash-auto if torch was on
      if (_flashMode == FlashMode.torch) {
        await controller.setFlashMode(FlashMode.auto);
      }

      final xFile = await controller.takePicture();
      final bytes = await xFile.readAsBytes();

      // Resize if needed (same logic as CameraService)
      final resized = _resizeIfNeeded(bytes);

      if (!mounted) return;
      Navigator.pop(
        context,
        CameraGuideResult(
          imageData: resized,
          corners: List.of(_savedCornerFractions),
        ),
      );
    } catch (e) {
      setState(() => _isCapturing = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Capture failed: $e')));
      }
    }
  }

  Uint8List _resizeIfNeeded(Uint8List data) {
    const maxEdge = 2000;
    final decoded = img.decodeImage(data);
    if (decoded == null) return data;

    final longest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    if (longest <= maxEdge) return data;

    final ratio = maxEdge / longest;
    final resized = img.copyResize(
      decoded,
      width: (decoded.width * ratio).round(),
      height: (decoded.height * ratio).round(),
    );
    return Uint8List.fromList(img.encodeJpg(resized, quality: 95));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitialized && _controller != null
          ? _buildCameraView()
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview and guide overlay share the same coordinate space
        // so that fractional corner positions map directly to the captured image.
        Center(
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller!),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final area = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return _GuideOverlay(
                      areaSize: area,
                      cornerFractions: _savedCornerFractions,
                      onCornersChanged: (updated) {
                        _savedCornerFractions = updated;
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Top bar: close + flash
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _circleButton(Icons.close, () => Navigator.pop(context)),
              _circleButton(
                _flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on,
                _toggleFlash,
              ),
            ],
          ),
        ),

        // Bottom bar: capture button + reset guide
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 24,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Reset guide to default trapezoid
              _circleButton(Icons.grid_on, () {
                setState(() {
                  _savedCornerFractions = _defaultTrapezoid();
                });
              }),

              // Capture button
              GestureDetector(
                onTap: _isCapturing ? null : _capture,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: _isCapturing
                        ? Colors.grey
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                  child: _isCapturing
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),

              // Placeholder for symmetry
              const SizedBox(width: 48),
            ],
          ),
        ),
      ],
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.5),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

// =============================================================================
// Guide overlay with draggable corners
// =============================================================================

class _GuideOverlay extends StatefulWidget {
  final Size areaSize;
  final List<Offset> cornerFractions;
  final ValueChanged<List<Offset>> onCornersChanged;

  const _GuideOverlay({
    required this.areaSize,
    required this.cornerFractions,
    required this.onCornersChanged,
  });

  @override
  State<_GuideOverlay> createState() => _GuideOverlayState();
}

class _GuideOverlayState extends State<_GuideOverlay> {
  late List<Offset> _screenCorners;
  int? _dragIndex;

  @override
  void initState() {
    super.initState();
    _screenCorners = _toScreen(widget.cornerFractions);
  }

  @override
  void didUpdateWidget(_GuideOverlay old) {
    super.didUpdateWidget(old);
    if (old.areaSize != widget.areaSize ||
        old.cornerFractions != widget.cornerFractions) {
      _screenCorners = _toScreen(widget.cornerFractions);
    }
  }

  List<Offset> _toScreen(List<Offset> fractions) {
    return fractions
        .map(
          (f) => Offset(
            f.dx * widget.areaSize.width,
            f.dy * widget.areaSize.height,
          ),
        )
        .toList();
  }

  List<Offset> _toFractions(List<Offset> screen) {
    return screen
        .map(
          (s) => Offset(
            (s.dx / widget.areaSize.width).clamp(0.0, 1.0),
            (s.dy / widget.areaSize.height).clamp(0.0, 1.0),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) {
        const radius = 40.0;
        for (int i = 0; i < _screenCorners.length; i++) {
          if ((d.localPosition - _screenCorners[i]).distance <= radius) {
            _dragIndex = i;
            return;
          }
        }
      },
      onPanUpdate: (d) {
        if (_dragIndex != null) {
          setState(() {
            _screenCorners[_dragIndex!] = d.localPosition;
          });
        }
      },
      onPanEnd: (_) {
        if (_dragIndex != null) {
          widget.onCornersChanged(_toFractions(_screenCorners));
          _dragIndex = null;
        }
      },
      child: CustomPaint(
        size: widget.areaSize,
        painter: _GuidePainter(corners: _screenCorners, dragIndex: _dragIndex),
      ),
    );
  }
}

class _GuidePainter extends CustomPainter {
  final List<Offset> corners;
  final int? dragIndex;

  _GuidePainter({required this.corners, this.dragIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;

    // Semi-transparent dark outside the guide
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final guidePath = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();

    canvas.saveLayer(fullRect, Paint());
    canvas.drawRect(
      fullRect,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    canvas.drawPath(guidePath, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(guidePath, borderPaint);

    // Corner handles
    for (int i = 0; i < 4; i++) {
      final isDragged = i == dragIndex;
      final handlePaint = Paint()
        ..color = isDragged
            ? Colors.orange.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(corners[i], isDragged ? 18 : 14, handlePaint);
      canvas.drawCircle(
        corners[i],
        isDragged ? 18 : 14,
        Paint()
          ..color = isDragged ? Colors.orange : Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
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
  bool shouldRepaint(covariant _GuidePainter old) => true;
}
