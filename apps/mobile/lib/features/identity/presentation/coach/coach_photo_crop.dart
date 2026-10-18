import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/identity.dart';
import '../../../../infrastructure/local/account_photo_picker.dart';
import '../../application/coach_account_gateway.dart';
import 'coach_account_session_guard.dart';

Future<AccountPhoto?> pickCoachPhoto(
    BuildContext context, CoachAccountGateway repository) async {
  final camera = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(context, true)),
            ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(context, false)),
          ])));
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
      appBar: AppBar(title: const Text('Take profile photo')),
      body: error != null
          ? Center(child: Text(error!))
          : controller?.value.isInitialized != true
              ? const Center(child: CircularProgressIndicator())
              : Column(children: [
                  Expanded(child: CameraPreview(controller!)),
                  FilledButton(
                      onPressed: busy
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
                      child: const Text('Capture'))
                ]));
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
      appBar: AppBar(title: const Text('Crop profile photo')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        AspectRatio(
            aspectRatio: 1,
            child: Stack(fit: StackFit.expand, children: [
              Image.memory(widget.photo.bytes,
                  fit: BoxFit.cover,
                  alignment: Alignment(horizontal, vertical)),
              const IgnorePointer(child: CustomPaint(painter: _CropGrid()))
            ])),
        const Text('Move the crop horizontally'),
        Slider(
            value: horizontal,
            min: -1,
            max: 1,
            onChanged: busy ? null : (v) => setState(() => horizontal = v)),
        const Text('Move the crop vertically'),
        Slider(
            value: vertical,
            min: -1,
            max: 1,
            onChanged: busy ? null : (v) => setState(() => vertical = v)),
        FilledButton(
            onPressed: busy ? null : crop,
            child: const Text('Use cropped photo')),
      ]));
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
