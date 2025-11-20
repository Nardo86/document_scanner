import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/scanned_document.dart';
import '../models/processing_options.dart';
import '../services/image_processor.dart';

/// Widget for editing scanned images with rotation, color filters, and cropping
class ImageEditingWidget extends StatefulWidget {
  final Uint8List imageData;
  final Function(Uint8List editedImageData, PdfResolution selectedResolution, DocumentFormat selectedFormat) onImageEdited;
  final VoidCallback? onCancel;

  const ImageEditingWidget({
    Key? key,
    required this.imageData,
    required this.onImageEdited,
    this.onCancel,
  }) : super(key: key);

  @override
  State<ImageEditingWidget> createState() => _ImageEditingWidgetState();
}

class _ImageEditingWidgetState extends State<ImageEditingWidget> {
  final ImageProcessor _imageProcessor = ImageProcessor();
  
  ImageEditingOptions _editingOptions = const ImageEditingOptions();
  Uint8List? _previewImageData;
  Uint8List? _baseImageData; // Image after rotation/crop but before color filters
  List<Offset>? _detectedCorners;
  bool _isProcessing = false;
  bool _showCropOverlay = false;
  PdfResolution _selectedResolution = PdfResolution.size; // Default to Standard (150 DPI)
  bool _isSettingsExpanded = false; // Track if settings panel is expanded

  @override
  void initState() {
    super.initState();
    _previewImageData = widget.imageData;
    _baseImageData = widget.imageData; // Initialize base image
    _detectDocumentEdges();
  }

  Future<void> _detectDocumentEdges() async {
    try {
      final corners = await _imageProcessor.detectDocumentEdges(widget.imageData);
      setState(() {
        _detectedCorners = corners;
      });
    } catch (e) {
      print('Error detecting document edges: $e');
      // Fallback to default corners if detection fails
      setState(() {
        _detectedCorners = [
          const Offset(50, 50),
          const Offset(300, 50),
          const Offset(300, 400),
          const Offset(50, 400),
        ];
      });
    }
  }

  Future<void> _updatePreview() async {
    // Apply only color filter to base image (after rotation/crop)
    if (_baseImageData == null) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      // Apply only color filter to base image
      final filterOptions = ImageEditingOptions(colorFilter: _editingOptions.colorFilter);
      final processedData = await _imageProcessor.applyImageEditing(
        _baseImageData!,
        filterOptions,
      );
      
      setState(() {
        _previewImageData = processedData;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating preview: $e')),
      );
    }
  }

  void _rotateClockwise() {
    // Apply rotation to current preview image, not original
    _applyIncrementalRotation(90);
  }

  void _rotateCounterclockwise() {
    // Apply rotation to current preview image, not original
    _applyIncrementalRotation(-90);
  }

  Future<void> _applyIncrementalRotation(int degrees) async {
    if (_previewImageData == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Apply rotation to current preview image
      final rotationOptions = ImageEditingOptions(rotationDegrees: degrees);
      final rotatedData = await _imageProcessor.applyImageEditing(
        _previewImageData!,
        rotationOptions,
      );
      
      setState(() {
        _previewImageData = rotatedData;
        _baseImageData = rotatedData; // Update base image after rotation
        // Update total rotation for tracking
        final newRotation = (_editingOptions.rotationDegrees + degrees) % 360;
        _editingOptions = _editingOptions.copyWith(rotationDegrees: newRotation);
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rotating image: $e')),
      );
    }
  }

  void _setColorFilter(ColorFilter filter) {
    // Apply color filter to current preview image
    _applyIncrementalColorFilter(filter);
  }

  Future<void> _applyIncrementalColorFilter(ColorFilter filter) async {
    if (_baseImageData == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Apply color filter to base image (after rotation/crop but before previous filters)
      final filterOptions = ImageEditingOptions(colorFilter: filter);
      final filteredData = await _imageProcessor.applyImageEditing(
        _baseImageData!,
        filterOptions,
      );
      
      setState(() {
        _previewImageData = filteredData;
        _editingOptions = _editingOptions.copyWith(colorFilter: filter);
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error applying filter: $e')),
      );
    }
  }

  void _toggleCropMode() {
    setState(() {
      _showCropOverlay = !_showCropOverlay;
      if (_showCropOverlay && _detectedCorners != null) {
        // Don't update preview when entering crop mode, just show overlay
        _editingOptions = _editingOptions.copyWith(cropCorners: _detectedCorners);
      } else {
        // When exiting crop mode, apply the crop or reset
        _editingOptions = _editingOptions.copyWith(cropCorners: null);
        _updatePreview();
      }
    });
  }

  Future<void> _applyCrop() async {
    if (_detectedCorners == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Apply crop to current preview image using original coordinates
      // We need to convert coordinates from original image space to current preview space
      final cropOptions = ImageEditingOptions(
        cropCorners: _detectedCorners,
        documentFormat: _editingOptions.documentFormat,
      );
      final croppedData = await _imageProcessor.applyImageEditing(
        widget.imageData, // Use original image for crop coordinates
        cropOptions,
      );
      
      setState(() {
        _previewImageData = croppedData;
        _baseImageData = croppedData; // Update base image after crop
        _showCropOverlay = false;
        _editingOptions = _editingOptions.copyWith(cropCorners: _detectedCorners);
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error applying crop: $e')),
      );
    }
  }

  void _resetEditing() {
    setState(() {
      _editingOptions = const ImageEditingOptions();
      _previewImageData = widget.imageData;
      _baseImageData = widget.imageData; // Reset base image to original
      _showCropOverlay = false;
    });
  }

  void _confirmEditing() {
    if (_previewImageData != null) {
      widget.onImageEdited(_previewImageData!, _selectedResolution, _editingOptions.documentFormat);
    }
  }

  void _setResolution(PdfResolution resolution) {
    setState(() {
      _selectedResolution = resolution;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Image'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetEditing,
            tooltip: 'Reset',
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _confirmEditing,
            tooltip: 'Confirm',
          ),
        ],
      ),
      body: Column(
        children: [
          // Image preview
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: Center(
                child: _isProcessing
                    ? const CircularProgressIndicator()
                    : _previewImageData != null
                        ? _showCropOverlay && _detectedCorners != null
                            ? CropOverlayWidget(
                                imageData: widget.imageData, // Use original image data for overlay
                                corners: _detectedCorners!,
                                onCornersChanged: (newCorners) {
                                  setState(() {
                                    _detectedCorners = newCorners;
                                    _editingOptions = _editingOptions.copyWith(cropCorners: newCorners);
                                  });
                                  // No need to update preview here - just store the corners
                                },
                              )
                            : InteractiveViewer(
                                child: Image.memory(
                                  _previewImageData!,
                                  fit: BoxFit.contain,
                                ),
                              )
                        : const Icon(Icons.image, size: 64),
              ),
            ),
          ),
          
          // Controls
          GestureDetector(
            onTap: () {
              // Tapping on the controls area toggles expanded state
              setState(() {
                _isSettingsExpanded = !_isSettingsExpanded;
              });
            },
            onVerticalDragEnd: (details) {
              // Swipe up to expand, swipe down to collapse
              if (details.primaryVelocity! < -500) {
                // Swipe up
                setState(() {
                  _isSettingsExpanded = true;
                });
              } else if (details.primaryVelocity! > 500) {
                // Swipe down
                setState(() {
                  _isSettingsExpanded = false;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.3),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
              children: [
                // Rotation and crop controls (always visible)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: _rotateCounterclockwise,
                      icon: const Icon(Icons.rotate_left),
                      tooltip: 'Rotate Left',
                    ),
                    IconButton(
                      onPressed: _rotateClockwise,
                      icon: const Icon(Icons.rotate_right),
                      tooltip: 'Rotate Right',
                    ),
                    IconButton(
                      onPressed: _toggleCropMode,
                      icon: Icon(_showCropOverlay ? Icons.crop_free : Icons.crop),
                      tooltip: _showCropOverlay ? 'Disable Crop' : 'Enable Crop',
                    ),
                    if (_showCropOverlay)
                      IconButton(
                        onPressed: _applyCrop,
                        icon: const Icon(Icons.check),
                        tooltip: 'Apply Crop',
                        color: Colors.green,
                      ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Compact view: Active settings indicators
                if (!_isSettingsExpanded) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActiveSettingIndicator(
                        'Filter',
                        _getColorFilterIcon(_editingOptions.colorFilter),
                        _editingOptions.colorFilter != ColorFilter.none,
                        () => setState(() => _isSettingsExpanded = true),
                      ),
                      _buildActiveSettingIndicator(
                        'Format',
                        _getDocumentFormatIcon(_editingOptions.documentFormat),
                        _editingOptions.documentFormat != DocumentFormat.auto,
                        () => setState(() => _isSettingsExpanded = true),
                      ),
                      _buildActiveSettingIndicator(
                        'PDF',
                        _getResolutionIcon(_selectedResolution),
                        _selectedResolution != PdfResolution.size,
                        () => setState(() => _isSettingsExpanded = true),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _isSettingsExpanded = true),
                        icon: const Icon(Icons.settings),
                        tooltip: 'Show All Settings',
                      ),
                    ],
                  ),
                ],
                
                // Expanded view: All settings
                if (_isSettingsExpanded) ...[
                  // Header with collapse button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        onPressed: () => setState(() => _isSettingsExpanded = false),
                        icon: const Icon(Icons.keyboard_arrow_down),
                        tooltip: 'Collapse Settings',
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Color filter controls
                  const Text('Color Filter:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFilterButton('Original', ColorFilter.none, Icons.image),
                      _buildFilterButton('Enhanced', ColorFilter.highContrast, Icons.auto_fix_high),
                      _buildFilterButton('B&W', ColorFilter.blackAndWhite, Icons.filter_b_and_w),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Document format controls
                  const Text('Document Format:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFormatButton('Auto', DocumentFormat.auto, Icons.auto_fix_normal),
                      _buildFormatButton('A4', DocumentFormat.isoA, Icons.description),
                      _buildFormatButton('Letter', DocumentFormat.usLetter, Icons.document_scanner),
                      _buildFormatButton('Legal', DocumentFormat.usLegal, Icons.article),
                      _buildFormatButton('Receipt', DocumentFormat.receipt, Icons.receipt),
                      _buildFormatButton('Square', DocumentFormat.square, Icons.crop_square),
                      _buildFormatButton('Card', DocumentFormat.businessCard, Icons.credit_card),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // PDF Resolution controls
                  const Text('PDF Quality:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildResolutionButton('Standard', PdfResolution.size, Icons.compress),
                      _buildResolutionButton('High', PdfResolution.quality, Icons.high_quality),
                      _buildResolutionButton('Max', PdfResolution.original, Icons.hd),
                    ],
                  ),
                ],
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSettingIndicator(String label, IconData icon, bool isActive, VoidCallback onTap) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(
            icon,
            color: isActive ? Colors.blue[800] : Colors.grey[600],
          ),
          style: IconButton.styleFrom(
            backgroundColor: isActive ? Colors.blue[50] : null,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.blue[800] : Colors.grey[600],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton(String label, ColorFilter filter, IconData icon) {
    final isSelected = _editingOptions.colorFilter == filter;
    
    return Column(
      children: [
        IconButton(
          onPressed: () => _setColorFilter(filter),
          icon: Icon(
            icon,
            color: isSelected ? Colors.blue[800] : Colors.grey[600],
          ),
          style: IconButton.styleFrom(
            backgroundColor: isSelected ? Colors.blue[50] : null,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.blue[800] : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildResolutionButton(String label, PdfResolution resolution, IconData icon) {
    final isSelected = _selectedResolution == resolution;
    
    return Column(
      children: [
        IconButton(
          onPressed: () => _setResolution(resolution),
          icon: Icon(
            icon,
            color: isSelected ? Colors.green[800] : Colors.grey[600],
          ),
          style: IconButton.styleFrom(
            backgroundColor: isSelected ? Colors.green[50] : null,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.green[800] : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  IconData _getColorFilterIcon(ColorFilter filter) {
    switch (filter) {
      case ColorFilter.none:
        return Icons.image;
      case ColorFilter.highContrast:
        return Icons.auto_fix_high;
      case ColorFilter.blackAndWhite:
        return Icons.filter_b_and_w;
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

  Widget _buildFormatButton(String label, DocumentFormat format, IconData icon) {
    final isSelected = _editingOptions.documentFormat == format;
    
    return Column(
      children: [
        IconButton(
          onPressed: () => _setDocumentFormat(format),
          icon: Icon(
            icon,
            color: isSelected ? Colors.green[800] : Colors.grey[600],
          ),
          style: IconButton.styleFrom(
            backgroundColor: isSelected ? Colors.green[50] : null,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.green[800] : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  void _setDocumentFormat(DocumentFormat format) {
    setState(() {
      _editingOptions = _editingOptions.copyWith(documentFormat: format);
    });
    
    // If crop mode is active and we have corners, re-apply crop with new format
    if (_showCropOverlay && _detectedCorners != null) {
      _applyCrop();
    }
  }
}

/// Widget for interactive crop overlay with proper scaling
class CropOverlayWidget extends StatefulWidget {
  final Uint8List imageData;
  final List<Offset> corners;
  final Function(List<Offset>) onCornersChanged;

  const CropOverlayWidget({
    Key? key,
    required this.imageData,
    required this.corners,
    required this.onCornersChanged,
  }) : super(key: key);

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
      
      setState(() {
        _originalImageSize = Size(image.width.toDouble(), image.height.toDouble());
      });
      
      image.dispose();
    } catch (e) {
      print('Error loading image size: $e');
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
    if (_originalImageSize == null) {
      return ImageDisplayInfo(
        scale: 1.0,
        offset: Offset.zero,
        displaySize: containerSize,
      );
    }

    // Calculate scale to fit image in container while maintaining aspect ratio
    final scaleX = containerSize.width / _originalImageSize!.width;
    final scaleY = containerSize.height / _originalImageSize!.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    // Calculate displayed image size
    final displayWidth = _originalImageSize!.width * scale;
    final displayHeight = _originalImageSize!.height * scale;

    // Calculate offset to center the image
    final offsetX = (containerSize.width - displayWidth) / 2;
    final offsetY = (containerSize.height - displayHeight) / 2;

    return ImageDisplayInfo(
      scale: scale,
      offset: Offset(offsetX, offsetY),
      displaySize: Size(displayWidth, displayHeight),
    );
  }
}

/// Interactive widget for crop overlay with real-time feedback
class _CropInteractiveWidget extends StatefulWidget {
  final Uint8List imageData;
  final List<Offset> corners;
  final ImageDisplayInfo imageInfo;
  final Function(List<Offset>) onCornersChanged;

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
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _currentCorners = _convertToScreenCoordinates(widget.corners, widget.imageInfo);
  }

  @override
  void didUpdateWidget(_CropInteractiveWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.corners != widget.corners || oldWidget.imageInfo != widget.imageInfo) {
      _currentCorners = _convertToScreenCoordinates(widget.corners, widget.imageInfo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background image
        Image.memory(
          widget.imageData,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
        ),
        
        // Crop overlay with real-time updates
        Positioned.fill(
          child: CustomPaint(
            painter: _CropOverlayPainter(
              corners: _currentCorners,
              imageInfo: widget.imageInfo,
            ),
            child: GestureDetector(
              onPanStart: (details) {
                final cornerIndex = _findNearestCorner(details.localPosition, _currentCorners);
                if (cornerIndex != null) {
                  setState(() {
                    _draggedCornerIndex = cornerIndex;
                    _isDragging = true;
                  });
                }
              },
              onPanUpdate: (details) {
                if (_draggedCornerIndex != null && _isDragging) {
                  setState(() {
                    _currentCorners[_draggedCornerIndex!] = details.localPosition;
                  });
                }
              },
              onPanEnd: (details) {
                if (_draggedCornerIndex != null && _isDragging) {
                  // Convert back to original image coordinates and notify parent
                  final originalCorners = _convertToOriginalCoordinates(_currentCorners, widget.imageInfo);
                  widget.onCornersChanged(originalCorners);
                  
                  setState(() {
                    _draggedCornerIndex = null;
                    _isDragging = false;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  int? _findNearestCorner(Offset position, List<Offset> corners) {
    const double touchRadius = 30.0;
    
    for (int i = 0; i < corners.length; i++) {
      final distance = (position - corners[i]).distance;
      if (distance <= touchRadius) {
        return i;
      }
    }
    return null;
  }

  List<Offset> _convertToScreenCoordinates(List<Offset> originalCorners, ImageDisplayInfo info) {
    return originalCorners.map((corner) {
      final x = corner.dx * info.scale + info.offset.dx;
      final y = corner.dy * info.scale + info.offset.dy;
      return Offset(x, y);
    }).toList();
  }

  List<Offset> _convertToOriginalCoordinates(List<Offset> screenCorners, ImageDisplayInfo info) {
    return screenCorners.map((corner) {
      final x = (corner.dx - info.offset.dx) / info.scale;
      final y = (corner.dy - info.offset.dy) / info.scale;
      return Offset(x, y);
    }).toList();
  }
}

/// Custom painter for crop overlay without BlendMode issues  
class _CropOverlayPainter extends CustomPainter {
  final List<Offset> corners;
  final ImageDisplayInfo imageInfo;

  _CropOverlayPainter({
    required this.corners,
    required this.imageInfo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;

    // Draw crop area border (no overlay background to avoid black screen)
    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Create crop area path
    final cropPath = Path();
    cropPath.moveTo(corners[0].dx, corners[0].dy);
    for (int i = 1; i < 4; i++) {
      cropPath.lineTo(corners[i].dx, corners[i].dy);
    }
    cropPath.close();

    // Draw crop area border
    canvas.drawPath(cropPath, borderPaint);

    // Draw corner handles with enhanced visibility
    final handlePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final corner in corners) {
      // Draw outer circle (larger for better touch)
      canvas.drawCircle(corner, 15, handlePaint);
      // Draw inner circle for better visibility
      canvas.drawCircle(corner, 8, centerPaint);
      // Draw border around inner circle
      canvas.drawCircle(corner, 8, strokePaint);
    }

    // Draw grid lines inside crop area for better alignment
    final gridPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Vertical lines
    for (int i = 1; i < 3; i++) {
      final t = i / 3.0;
      final topPoint = Offset.lerp(corners[0], corners[1], t)!;
      final bottomPoint = Offset.lerp(corners[3], corners[2], t)!;
      canvas.drawLine(topPoint, bottomPoint, gridPaint);
    }

    // Horizontal lines
    for (int i = 1; i < 3; i++) {
      final t = i / 3.0;
      final leftPoint = Offset.lerp(corners[0], corners[3], t)!;
      final rightPoint = Offset.lerp(corners[1], corners[2], t)!;
      canvas.drawLine(leftPoint, rightPoint, gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Helper class to store image display information
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