import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../infrastructure/local/account_photo_picker.dart';
import '../../application/coach_account_gateway.dart';
import 'coach_account_session_guard.dart';

Future<AccountPhoto?> pickCoachPhoto(
    BuildContext context, CoachAccountGateway repository) async {
  final camera = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.hairline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Profile Photo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose how you want to set your coaching photo',
                    style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primaryTint,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                color: AppColors.primary, size: 20),
                          ),
                          title: const Text('Take photo',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: const Text('Use your device camera for a fresh headshot',
                              style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.inkSoft),
                          onTap: () => Navigator.pop(context, true),
                        ),
                        const Divider(height: 1, indent: 64),
                        ListTile(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primaryTint,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.photo_library_rounded,
                                color: AppColors.primary, size: 20),
                          ),
                          title: const Text('Choose from gallery',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: const Text('Select an existing photo from your library',
                              style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.inkSoft),
                          onTap: () => Navigator.pop(context, false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ));
  if (camera == null || !context.mounted) return null;
  AccountPhoto? photo;
  if (camera) {
    final file = await Navigator.push<XFile>(
        context,
        MaterialPageRoute(
            builder: (_) => CoachAccountSessionGuard(
                repository: repository, child: const _CoachCamera())));
    if (file == null) return null;
    try {
      photo =
          await LocalAccountPhotoPicker(selectFile: () async => file).pick();
    } finally {
      try {
        await File(file.path).delete();
      } catch (_) {}
    }
  } else {
    photo = await LocalAccountPhotoPicker().pick();
  }
  if (photo == null || !context.mounted) return null;
  return Navigator.push<AccountPhoto>(
      context,
      MaterialPageRoute(
          builder: (_) => CoachAccountSessionGuard(
              repository: repository, child: _CropPhoto(photo: photo!))));
}

class _CoachCamera extends StatefulWidget {
  const _CoachCamera();
  @override
  State<_CoachCamera> createState() => _CoachCameraState();
}

class _CoachCameraState extends State<_CoachCamera> {
  CameraController? controller;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) throw StateError('No camera');
      final next = CameraController(cameras.first, ResolutionPreset.medium,
          enableAudio: false);
      controller = next;
      await next.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'Camera access is unavailable. Allow camera permission or choose from gallery.');
      }
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Take profile photo'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ),
            )
          : controller?.value.isInitialized != true
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(controller!),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _CameraGuideOverlay(),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 24,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          child: const Text(
                            'Center your face inside the circle',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 36,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: busy
                              ? null
                              : () async {
                                  setState(() => busy = true);
                                  try {
                                    final file = await controller!.takePicture();
                                    if (context.mounted) {
                                      Navigator.pop(context, file);
                                    } else {
                                      try {
                                        await File(file.path).delete();
                                      } catch (_) {}
                                    }
                                  } catch (_) {
                                    if (mounted) {
                                      setState(() {
                                        busy = false;
                                        error = 'Photo capture failed. Try again.';
                                      });
                                    }
                                  }
                                },
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              color: busy ? Colors.grey : AppColors.primary,
                            ),
                            child: busy
                                ? const Padding(
                                    padding: EdgeInsets.all(18),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.camera_rounded,
                                    color: Colors.white, size: 36),
                          ),
                        ),
                      ),
                    ),
                  ],
                ));
}

class _CameraGuideOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final radius = size.width * 0.38;

    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);

    final circleBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawCircle(center, radius, circleBorderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CropPhoto extends StatefulWidget {
  const _CropPhoto({required this.photo});
  final AccountPhoto photo;
  @override
  State<_CropPhoto> createState() => _CropPhotoState();
}

class _CropPhotoState extends State<_CropPhoto> {
  double horizontal = 0, vertical = 0;
  bool busy = false;
  Future<void> crop() async {
    setState(() => busy = true);
    final codec = await ui.instantiateImageCodec(widget.photo.bytes);
    ui.Image? source, output;
    try {
      source = (await codec.getNextFrame()).image;
      final size = math.min(source.width, source.height).toDouble();
      final left = (source.width - size) * (horizontal + 1) / 2,
          top = (source.height - size) * (vertical + 1) / 2;
      final recorder = ui.PictureRecorder();
      // Render the exact square shown by BoxFit.cover and alignment sliders.
      final drawing = Canvas(recorder);
      drawing.drawImageRect(
          source,
          Rect.fromLTWH(left, top, size, size),
          const Rect.fromLTWH(0, 0, 512, 512),
          Paint()..filterQuality = FilterQuality.high);
      final picture = recorder.endRecording();
      try {
        output = await picture.toImage(512, 512);
      } finally {
        picture.dispose();
      }
      final bytes = await output.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw const FormatException('Could not crop this image.');
      }
      final photo = AccountPhoto(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      if (mounted) Navigator.pop(context, photo);
    } finally {
      source?.dispose();
      output?.dispose();
      codec.dispose();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: const Text('Crop profile photo'),
        actions: [
          TextButton(
            onPressed: busy
                ? null
                : () => setState(() {
                      horizontal = 0;
                      vertical = 0;
                    }),
            child: const Text('Center'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.hairline, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      widget.photo.bytes,
                      fit: BoxFit.cover,
                      alignment: Alignment(horizontal, vertical),
                    ),
                    const IgnorePointer(child: CustomPaint(painter: _CropGrid())),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Horizontal position',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                    Text('${(horizontal * 100).toInt()}%',
                        style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                  ],
                ),
                Slider(
                  value: horizontal,
                  min: -1,
                  max: 1,
                  activeColor: AppColors.primary,
                  onChanged: busy ? null : (v) => setState(() => horizontal = v),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.swap_vert_rounded, size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Vertical position',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                    Text('${(vertical * 100).toInt()}%',
                        style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                  ],
                ),
                Slider(
                  value: vertical,
                  min: -1,
                  max: 1,
                  activeColor: AppColors.primary,
                  onChanged: busy ? null : (v) => setState(() => vertical = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: busy ? null : crop,
            child: busy
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Text('Cropping photo...'),
                    ],
                  )
                : const Text('Use cropped photo', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ));
}

class _CropGrid extends CustomPainter {
  const _CropGrid();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1;
    for (final fraction in [1 / 3, 2 / 3]) {
      canvas.drawLine(Offset(size.width * fraction, 0),
          Offset(size.width * fraction, size.height), paint);
      canvas.drawLine(Offset(0, size.height * fraction),
          Offset(size.width, size.height * fraction), paint);
    }
  }

  @override
  bool shouldRepaint(_CropGrid oldDelegate) => false;
}
