import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'achievement_artwork.dart';

const _shareChannel = MethodChannel('gainpath/achievement_share');
const _shareNames = {
  'first-check-in': 'First check-in',
  'check-in-streak-3': 'Three-day check-in streak',
  'check-in-streak-7': 'Seven-day check-in streak',
  'check-in-streak-14': 'Two-week Champion',
  'first-workout': 'First Workout',
  'workout-regular': 'Workout Regular',
  'century-club': 'Century Club',
  'routine-finisher': 'Routine Finisher',
};

Future<void> shareAchievement({
  required String id,
  required String name,
  required String description,
  required DateTime unlockedAt,
  bool Function()? isCurrent,
}) async {
  if (isCurrent?.call() == false) return;
  final shareName = _shareNames[id];
  if (shareName == null) throw ArgumentError.value(id, 'id');
  final text = 'I unlocked the $shareName badge in GainPath!';

  try {
    final png = await _renderCard(
      id: id,
      name: name,
      description: description,
      unlockedAt: unlockedAt,
    );
    if (isCurrent?.call() == false) return;
    await shareGainPathImage(png, text);
    return;
  } on Object {
    // Preserve the original share action if rendering or image transport fails.
  }
  if (isCurrent?.call() != false) {
    await _shareChannel.invokeMethod<void>('share', {'text': text});
  }
}

Future<void> shareGainPathImage(Uint8List png, String text) =>
    _shareChannel.invokeMethod<void>('shareImage', {'png': png, 'text': text});

Future<Uint8List> _renderCard({
  required String id,
  required String name,
  required String description,
  required DateTime unlockedAt,
}) async {
  const width = 600;
  const height = 704;
  const bounds = Rect.fromLTWH(0, 0, width * 1.0, height * 1.0);
  const white = Color(0xFFFFF8F3);
  const lavender = Color(0xFFE7D8FF);
  return renderGainPathShareCard(
      width: width,
      height: height,
      paint: (canvas, logo) {
        canvas.drawRect(
          bounds,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF200D45), Color(0xFF3F2375), Color(0xFF211342)],
            ).createShader(bounds),
        );
        final rings = Paint()
          ..color = const Color(0x225FDFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
        for (final radius in [126.0, 153.0, 180.0]) {
          canvas.drawCircle(const Offset(300, 266), radius, rings);
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(24, 24, 552, 656),
            const Radius.circular(32),
          ),
          Paint()
            ..color = const Color(0x46FFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(205, 58, 55, 45),
            const Radius.circular(10),
          ),
          Paint()..color = Colors.white,
        );
        canvas.drawImageRect(
          logo,
          Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
          const Rect.fromLTWH(212, 64, 41, 33),
          Paint()..filterQuality = FilterQuality.medium,
        );
        final malaysiaDate = unlockedAt
            .toUtc()
            .add(const Duration(hours: 8))
            .toIso8601String()
            .substring(0, 10);
        _text(canvas, 'GainPath', top: 65, size: 29, color: white, left: 272);
        _text(canvas, 'ACHIEVEMENT UNLOCKED',
            top: 131, size: 15, color: lavender, tracking: 3);
        canvas.save();
        canvas.translate(202, 172);
        AchievementArtworkPainter(id: id, unlocked: true)
            .paint(canvas, const Size.square(196));
        canvas.restore();
        _text(canvas, name, top: 391, size: 44, color: white, maxLines: 2);
        _text(canvas, description,
            top: 510, size: 24, color: lavender, maxLines: 2);
        _text(canvas, 'Unlocked $malaysiaDate',
            top: 584, size: 17, color: lavender);
        _text(canvas, 'Every milestone counts.',
            top: 626, size: 19, color: white);
      });
}

Future<Uint8List> renderGainPathShareCard({
  required int width,
  required int height,
  int scale = 1,
  required void Function(Canvas, ui.Image) paint,
}) async {
  final logoBytes =
      await rootBundle.load('assets/images/achievement_gainpath_logo.png');
  final logoDecoder = await ui.instantiateImageCodec(
    logoBytes.buffer
        .asUint8List(logoBytes.offsetInBytes, logoBytes.lengthInBytes),
  );
  final ui.Image logo;
  try {
    logo = (await logoDecoder.getNextFrame()).image;
  } finally {
    logoDecoder.dispose();
  }

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(scale.toDouble());
  try {
    paint(canvas, logo);
  } catch (_) {
    recorder.endRecording().dispose();
    logo.dispose();
    rethrow;
  }
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(width * scale, height * scale);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('Share card encoding failed.');
      return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
    logo.dispose();
  }
}

void _text(
  Canvas canvas,
  String text, {
  required double top,
  required double size,
  required Color color,
  double? left,
  double tracking = 0,
  int maxLines = 1,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontFamily: 'Barlow',
        fontSize: size,
        fontWeight: size >= 29 ? FontWeight.w800 : FontWeight.w600,
        letterSpacing: tracking,
        height: 1.14,
      ),
    ),
    maxLines: maxLines,
    ellipsis: '…',
    textAlign: left == null ? TextAlign.center : TextAlign.left,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: left == null ? 478 : 240);
  painter.paint(canvas, Offset(left ?? (600 - painter.width) / 2, top));
  painter.dispose();
}
