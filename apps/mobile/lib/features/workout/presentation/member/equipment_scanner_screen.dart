import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'equipment_browse_screen.dart';
import '../shared/equipment_detail_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:gainpath_domain/workout.dart';
import '../../../../infrastructure/vision/smart_equipment_vision_classifier.dart';
import '../../../../infrastructure/local/equipment_image_picker.dart';

const _viewfinderHero =
    'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=1200&q=80';

/// Full-bleed network image with a graceful gradient fallback so a dead
/// link never breaks the layout — the same defensive pattern used across
/// onboarding, profile setup, and the workout module.
Widget _networkHero(String url, {BoxFit fit = BoxFit.cover}) {
  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : Container(color: AppColors.ink),
    errorBuilder: (context, error, stack) => const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.heroGradient)),
  );
}

/// UC-2.6 — Scan Gym Equipment with Vision AI.
/// Connects live CameraPreview, Gemini Vision AI model, and existing active
/// Firebase Equipment records. Opens real EquipmentDetailScreen on match.
class EquipmentScannerScreen extends StatefulWidget {
  const EquipmentScannerScreen({
    super.key,
    this.connected = false,
    this.organizationId,
    this.reader,
    this.classifier,
    this.matcher = const EquipmentMatcher(),
    this.onBrowse,
    this.enableCamera = true,
    this.imagePicker,
  });

  final bool connected;
  final String? organizationId;
  final EquipmentReader? reader;
  final EquipmentVisionClassifier? classifier;
  final EquipmentMatcher matcher;
  final VoidCallback? onBrowse;
  final bool enableCamera;
  final EquipmentImagePicker? imagePicker;

  @override
  State<EquipmentScannerScreen> createState() => _EquipmentScannerScreenState();
}

class _EquipmentScannerScreenState extends State<EquipmentScannerScreen>
    with TickerProviderStateMixin {
  late final AnimationController _scanLine;
  CameraController? _cameraController;
  late final EquipmentVisionClassifier _classifier;
  late final EquipmentImagePicker _imagePicker;

  bool _scanning = false;
  bool _noMatch = false;
  String? _noMatchReason;
  List<GymEquipment>? _multipleMatches;
  String? _errorMessage;
  bool _cameraFailed = false;
  bool _initializingCamera = false;
  GymEquipment? _suggestedMatch;
  Uint8List? _uploadedImageBytes;

  static const _boxSize = 260.0;

  @override
  void initState() {
    super.initState();
    _scanLine = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700));

    _classifier = widget.classifier ??
        SmartEquipmentVisionClassifier(
            connected: widget.connected, organizationId: widget.organizationId);

    _imagePicker = widget.imagePicker ?? LocalEquipmentImagePicker();

    if (widget.enableCamera) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    if (_initializingCamera || !mounted) return;
    _initializingCamera = true;
    CameraController? controller;
    setState(() {
      _cameraFailed = false;
      _errorMessage = null;
    });
    try {
      final previous = _cameraController;
      setState(() => _cameraController = null);
      await previous?.dispose();
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) throw CameraException('unavailable', 'No camera');

      // Prefer back camera for scanning gym machines
      final selectedCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _cameraController = controller);
      _scanLine.repeat();
    } catch (_) {
      await controller?.dispose();
      if (mounted) {
        _scanLine.stop();
        setState(() {
          _cameraFailed = true;
          _errorMessage =
              'Camera access is unavailable. Allow camera permission in Settings, then retry or browse the catalogue.';
        });
      }
    } finally {
      _initializingCamera = false;
    }
  }

  Future<void> _retry() async {
    if (_uploadedImageBytes != null) {
      await _processImageBytes(_uploadedImageBytes!);
    } else if (_cameraFailed || _cameraController == null) {
      await _initCamera();
    } else {
      await _runScan();
    }
  }

  @override
  void dispose() {
    _scanLine.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  void _openBrowseCatalog() {
    if (widget.onBrowse != null) {
      widget.onBrowse!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EquipmentBrowseScreen(reader: widget.reader),
        ),
      );
    }
  }

  Future<void> _pickAndScanImage() async {
    if (_scanning) return;
    try {
      final image = await _imagePicker.pick();
      if (image == null || !mounted) return;

      setState(() {
        _uploadedImageBytes = image.bytes;
        _errorMessage = null;
      });

      await _processImageBytes(image.bytes, mimeType: image.contentType);
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Could not load the selected image. Choose another JPG, PNG or WebP.';
      });
    }
  }

  Future<void> _processImageBytes(
    List<int> imageBytes, {
    String? mimeType,
  }) async {
    setState(() {
      _scanning = true;
      _noMatch = false;
      _noMatchReason = null;
      _multipleMatches = null;
      _errorMessage = null;
      _suggestedMatch = null;
    });

    try {
      // Auto-detect MIME type directly from magic bytes to guarantee valid server format
      final isPng = imageBytes.length >= 8 &&
          imageBytes[0] == 137 &&
          imageBytes[1] == 80 &&
          imageBytes[2] == 78 &&
          imageBytes[3] == 71;
      final actualMime = isPng ? 'image/png' : 'image/jpeg';

      // Identify via Vision AI
      final recognition = await _classifier.identifyEquipment(
        imageBytes,
        mimeType: actualMime,
      );

      // Load active equipment catalog
      List<GymEquipment> activeCatalog = [];
      if (widget.reader != null) {
        String? cursor;
        final seen = <String>{};
        do {
          final page = await widget.reader!.loadEquipment(afterId: cursor);
          if (!mounted) return;
          activeCatalog.addAll(page.items.where((e) => e.isActive));
          cursor = page.nextCursor;
          if (cursor != null && !seen.add(cursor)) {
            throw StateError('Catalog pagination did not advance.');
          }
        } while (cursor != null);
      } else {
        try {
          activeCatalog = context
              .read<EquipmentRepository>()
              .gymEquipment
              .where((e) => e.isActive)
              .toList();
        } catch (_) {
          activeCatalog = [];
        }
      }

      if (!mounted) return;

      // Match recognition against catalog
      final matchResult = widget.matcher.match(
        recognition: recognition,
        catalog: activeCatalog,
      );

      switch (matchResult) {
        case SingleEquipmentMatch(:final equipment):
          setState(() {
            _scanning = false;
            _suggestedMatch = equipment;
          });
        case MultipleEquipmentMatches(:final candidates):
          setState(() {
            _scanning = false;
            _multipleMatches = candidates;
          });
        case NoEquipmentMatch(:final reason):
          setState(() {
            _scanning = false;
            _noMatch = true;
            _noMatchReason = reason;
          });
      }
    } catch (e) {
      if (!mounted) return;
      String message =
          'Network or scanner error. Check your connection or browse the catalog.';
      if (e is FirebaseFunctionsException &&
          e.message != null &&
          e.message!.trim().isNotEmpty) {
        message = e.message!.trim();
      }
      setState(() {
        _scanning = false;
        _errorMessage = message;
      });
    }
  }

  Future<void> _runScan() async {
    if (_scanning) return;
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _cameraController!.value.hasError) {
      setState(() {
        _cameraFailed = true;
        _errorMessage =
            'Camera is not ready. Retry camera access or browse the catalogue.';
      });
      return;
    }

    setState(() {
      _uploadedImageBytes = null;
    });

    late final List<int> imageBytes;
    try {
      final xfile = await _cameraController!.takePicture();
      try {
        imageBytes = await xfile.readAsBytes();
      } finally {
        if (xfile.path.isNotEmpty) {
          try {
            await File(xfile.path).delete();
          } catch (_) {}
        }
      }
      if (imageBytes.isEmpty) throw CameraException('empty', 'Empty capture');
    } catch (_) {
      if (mounted) {
        setState(() {
          _cameraFailed = true;
          _errorMessage =
              'Could not capture a photo. Retry the camera or browse the catalogue.';
        });
      }
      return;
    }
    if (!mounted) return;

    await _processImageBytes(imageBytes, mimeType: 'image/jpeg');
  }

  @override
  Widget build(BuildContext context) {
    final cameraReady =
        _cameraController != null && _cameraController!.value.isInitialized;

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background: Uploaded image, Camera Preview, or Viewfinder Hero
          if (_uploadedImageBytes != null)
            Center(
              child: Image.memory(
                _uploadedImageBytes!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => const DecoratedBox(
                    decoration:
                        BoxDecoration(gradient: AppColors.heroGradient)),
              ),
            )
          else if (cameraReady)
            Center(
              child: CameraPreview(_cameraController!),
            )
          else
            _networkHero(_viewfinderHero),

          // Tint overlay
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(
                alpha: _uploadedImageBytes != null
                    ? 0.10
                    : cameraReady
                        ? 0.20
                        : 0.55,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'Scan equipment',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.photo_library_rounded,
                            color: Colors.white),
                        tooltip: 'Upload image',
                        onPressed: _pickAndScanImage,
                      ),
                      IconButton(
                        icon: const Icon(Icons.grid_view_rounded,
                            color: Colors.white),
                        tooltip: 'Browse all equipment',
                        onPressed: _openBrowseCatalog,
                      ),
                    ],
                  ),
                ),

                // Uploaded image indicator chip
                if (_uploadedImageBytes != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.image_rounded,
                              size: 15, color: Colors.white70),
                          const SizedBox(width: 6),
                          const Text(
                            'Uploaded photo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            key: const Key('equipment_scanner_clear_upload'),
                            onTap: () =>
                                setState(() => _uploadedImageBytes = null),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Viewfinder frame
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: _boxSize,
                      height: _boxSize,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedBuilder(
                            animation: _scanLine,
                            builder: (context, _) => Positioned(
                              top: _scanLine.value * (_boxSize - 3),
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: AppColors.overlay,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.overlay
                                          .withValues(alpha: 0.7),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          ..._corners(),
                        ],
                      ),
                    ),
                  ),
                ),

                // Status message
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
                  child: Text(
                    _scanning
                        ? 'Identifying equipment…'
                        : _uploadedImageBytes != null
                            ? 'Scanned from uploaded photo'
                            : 'Point your camera at gym equipment',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // Error message card
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.wifi_off_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _cameraFailed
                                      ? 'Camera unavailable'
                                      : 'Scanning unavailable',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.overlay,
                                        padding: EdgeInsets.zero,
                                      ),
                                      onPressed: _openBrowseCatalog,
                                      child: const Text('Browse catalogue'),
                                    ),
                                    const SizedBox(width: 16),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.zero,
                                      ),
                                      onPressed: _retry,
                                      child: const Text('Retry'),
                                    ),
                                    const SizedBox(width: 16),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.overlay,
                                        padding: EdgeInsets.zero,
                                      ),
                                      onPressed: _pickAndScanImage,
                                      child: const Text('Upload photo'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_suggestedMatch != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Column(children: [
                      Text('Possible match: ${_suggestedMatch!.name}',
                          style: const TextStyle(color: Colors.white)),
                      const Text(
                          'AI can be wrong. Confirm this is your equipment.',
                          style: TextStyle(color: Colors.white70)),
                      TextButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => EquipmentDetailScreen(
                                      equipment: _suggestedMatch!,
                                      live: widget.connected))),
                          child: const Text('Confirm equipment')),
                    ]),
                  ),
                // Disambiguation for multiple matches
                if (_multipleMatches != null && _multipleMatches!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.sizeOf(context).height * 0.30),
                          child: SingleChildScrollView(
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.fitness_center_rounded,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Confirm equipment',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ..._multipleMatches!.map(
                                (eq) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EquipmentDetailScreen(
                                          equipment: eq,
                                          live: widget.connected,
                                        ),
                                      ),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              eq.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            color: Colors.white70,
                                            size: 14,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ))),
                    ),
                  ),

                // No match card
                if (_noMatch)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.search_off_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Couldn't recognise this equipment",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _noMatchReason ??
                                      'Try moving closer, or browse the catalogue instead.',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.overlay,
                                    padding: EdgeInsets.zero,
                                  ),
                                  onPressed: _openBrowseCatalog,
                                  child: const Text('Browse all equipment'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Bottom control row
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Upload image button
                      Tooltip(
                        message: 'Upload image',
                        child: InkWell(
                          key: const Key('equipment_scanner_upload_button'),
                          onTap: _pickAndScanImage,
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.16),
                              border: Border.all(
                                  color: Colors.white24, width: 1.5),
                            ),
                            child: const Icon(
                              Icons.photo_library_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),

                      // Shutter button
                      GestureDetector(
                        onTap: _runScan,
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.fromBorderSide(
                              BorderSide(color: Colors.white54, width: 4),
                            ),
                          ),
                          child: _scanning
                              ? const Padding(
                                  padding: EdgeInsets.all(22),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.6,
                                    color: AppColors.primary,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt_rounded,
                                  color: AppColors.primary,
                                  size: 30,
                                ),
                        ),
                      ),

                      // Live camera / Reset button (or placeholder for alignment)
                      if (_uploadedImageBytes != null && cameraReady)
                        Tooltip(
                          message: 'Return to camera',
                          child: InkWell(
                            key: const Key(
                                'equipment_scanner_return_camera_button'),
                            onTap: () =>
                                setState(() => _uploadedImageBytes = null),
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.16),
                                border: Border.all(
                                    color: Colors.white24, width: 1.5),
                              ),
                              child: const Icon(
                                Icons.videocam_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 52),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _corners() {
    const size = 28.0;
    const thickness = 3.0;

    Widget bracket({required bool top, required bool left}) {
      return Positioned(
        top: top ? 0 : null,
        bottom: top ? null : 0,
        left: left ? 0 : null,
        right: left ? null : 0,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border(
              top: top
                  ? const BorderSide(color: Colors.white, width: thickness)
                  : BorderSide.none,
              bottom: !top
                  ? const BorderSide(color: Colors.white, width: thickness)
                  : BorderSide.none,
              left: left
                  ? const BorderSide(color: Colors.white, width: thickness)
                  : BorderSide.none,
              right: !left
                  ? const BorderSide(color: Colors.white, width: thickness)
                  : BorderSide.none,
            ),
          ),
        ),
      );
    }

    return [
      bracket(top: true, left: true),
      bracket(top: true, left: false),
      bracket(top: false, left: true),
      bracket(top: false, left: false),
    ];
  }
}
