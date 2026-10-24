import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'equipment_browse_screen.dart';
import '../shared/equipment_detail_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/workout.dart';
import '../../../../infrastructure/vision/smart_equipment_vision_classifier.dart';

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
  });

  final bool connected;
  final String? organizationId;
  final EquipmentReader? reader;
  final EquipmentVisionClassifier? classifier;
  final EquipmentMatcher matcher;
  final VoidCallback? onBrowse;
  final bool enableCamera;

  @override
  State<EquipmentScannerScreen> createState() => _EquipmentScannerScreenState();
}

class _EquipmentScannerScreenState extends State<EquipmentScannerScreen>
    with TickerProviderStateMixin {
  late final AnimationController _scanLine;
  CameraController? _cameraController;
  late final EquipmentVisionClassifier _classifier;

  bool _scanning = false;
  bool _noMatch = false;
  String? _noMatchReason;
  List<GymEquipment>? _multipleMatches;
  String? _errorMessage;
  bool _cameraFailed = false;
  bool _initializingCamera = false;
  GymEquipment? _suggestedMatch;

  static const _boxSize = 260.0;

  @override
  void initState() {
    super.initState();
    _scanLine = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700));

    _classifier = widget.classifier ??
        SmartEquipmentVisionClassifier(
            connected: widget.connected, organizationId: widget.organizationId);

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
        ResolutionPreset.medium,
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
    if (_cameraFailed || _cameraController == null) {
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
      _scanning = true;
      _noMatch = false;
      _noMatchReason = null;
      _multipleMatches = null;
      _errorMessage = null;
      _suggestedMatch = null;
    });

    try {
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
            _scanning = false;
            _cameraFailed = true;
            _errorMessage =
                'Could not capture a photo. Retry the camera or browse the catalogue.';
          });
        }
        return;
      }
      if (!mounted) return;

      // Identify via Vision AI
      final recognition = await _classifier.identifyEquipment(imageBytes);

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
      setState(() {
        _scanning = false;
        _errorMessage =
            'Network or scanner error. Check your connection or browse the catalog.';
      });
    }
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
          // Background: Camera Preview or Viewfinder Hero
          if (cameraReady)
            CameraPreview(_cameraController!)
          else
            _networkHero(_viewfinderHero),

          // Tint overlay
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: cameraReady ? 0.35 : 0.55),
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
                        icon: const Icon(Icons.grid_view_rounded,
                            color: Colors.white),
                        tooltip: 'Browse all equipment',
                        onPressed: _openBrowseCatalog,
                      ),
                    ],
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

                // Shutter button
                Padding(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: GestureDetector(
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
