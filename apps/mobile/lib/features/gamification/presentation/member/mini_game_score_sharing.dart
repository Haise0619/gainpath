import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import 'achievement_sharing.dart';

enum ShareGame {
  moveCatch('Move & Catch'),
  reachTap('Reach & Tap');

  const ShareGame(this.title);
  final String title;
}

class MiniGameShareResult {
  const MiniGameShareResult({
    required this.game,
    required this.score,
    required this.hits,
    required this.completedAt,
    this.activeMillis,
  });

  final ShareGame game;
  final int score, hits;
  final DateTime completedAt;
  final int? activeMillis;

  String get date {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = completedAt.toUtc().add(const Duration(hours: 8));
    return '${day.day} ${months[day.month - 1]} ${day.year}';
  }

  String? get duration {
    final millis = activeMillis;
    if (millis == null) return null;
    final seconds = millis ~/ 1000;
    return seconds < 60 ? '${seconds}s' : '${seconds ~/ 60}m ${seconds % 60}s';
  }
}

Future<Uint8List> renderMiniGameShareCard(MiniGameShareResult result) =>
    renderGainPathShareCard(
      width: 540,
      height: 675,
      scale: 2,
      paint: (canvas, logo) {
        const surface = Rect.fromLTWH(0, 0, 540, 675);
        const white = Color(0xFFFFFBFF);
        const lavender = Color(0xFFE7D7FF);
        const orange = Color(0xFFFFA35F);
        canvas.drawRect(
          surface,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF210C46), Color(0xFF512396), Color(0xFF210B49)],
            ).createShader(surface),
        );
        final ring = Paint()
          ..color = const Color(0x26CBA5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.25;
        for (final radius in [64.0, 90.0, 116.0]) {
          canvas.drawCircle(const Offset(456, 168), radius, ring);
        }
        canvas.drawCircle(const Offset(467, 91), 4, Paint()..color = orange);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(30, 30, 480, 615), const Radius.circular(30)),
          Paint()..color = const Color(0x4520083A),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(30, 30, 480, 615), const Radius.circular(30)),
          Paint()
            ..color = const Color(0x55E7D7FF)
            ..style = PaintingStyle.stroke,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(60, 60, 51, 42), const Radius.circular(10)),
          Paint()..color = white,
        );
        canvas.drawImageRect(
          logo,
          Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
          const Rect.fromLTWH(66, 65, 39, 32),
          Paint()..filterQuality = FilterQuality.high,
        );
        _label(canvas, 'GainPath', 123, 65, 380, 27, white, bold: true);
        _label(canvas, 'MINI-GAME RESULT', 62, 136, 416, 14, orange,
            spacing: 2.6, bold: true);
        _label(canvas, result.game.title, 60, 160, 420, 42, white, bold: true);
        final score = result.score.toString();
        final size = score.length > 5
            ? (420 / (score.length * .62)).clamp(28.0, 89.0).toDouble()
            : 100.0;
        _label(canvas, score, 60, 249 + (100 - size) / 2, 420, size, white,
            bold: true, centered: true);
        _label(canvas, 'FINAL SCORE', 60, 365, 420, 15, lavender,
            spacing: 2.4, centered: true);
        final duration = result.duration;
        final values = [
          (result.hits.toString(), 'Hits'),
          if (duration != null) (duration, 'Active time')
        ];
        final tileWidth = values.length == 1 ? 420.0 : 200.0;
        for (final (index, metric) in values.indexed) {
          final x = 60.0 + index * 220;
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(x, 420, tileWidth, 86),
                const Radius.circular(15)),
            Paint()..color = const Color(0x33D4B5FF),
          );
          _label(canvas, metric.$1, x + 10, 432, tileWidth - 20, 30, white,
              bold: true, centered: true);
          _label(canvas, metric.$2, x + 10, 470, tileWidth - 20, 15, lavender,
              centered: true);
        }
        canvas.drawLine(const Offset(60, 538), const Offset(480, 538), ring);
        _label(canvas, 'Completed ${result.date} · MYT', 60, 555, 420, 16,
            lavender,
            centered: true);
        _label(canvas, 'Train · Play · Progress', 60, 592, 420, 22, white,
            bold: true, centered: true);
      },
    );

void _label(Canvas canvas, String text, double x, double y, double width,
    double size, Color color,
    {bool bold = false, bool centered = false, double spacing = 0}) {
  final painter = TextPainter(
    text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Barlow',
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          letterSpacing: spacing,
          height: 1.1,
        )),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: width);
  painter.paint(
      canvas, Offset(centered ? x + (width - painter.width) / 2 : x, y));
  painter.dispose();
}

class MiniGameShareButton extends StatefulWidget {
  const MiniGameShareButton({super.key, required this.result, this.isCurrent});

  final MiniGameShareResult result;
  final bool Function()? isCurrent;

  @override
  State<MiniGameShareButton> createState() => _MiniGameShareButtonState();
}

class _MiniGameShareButtonState extends State<MiniGameShareButton> {
  bool _sharing = false;

  bool get _current => mounted && widget.isCurrent?.call() != false;

  Future<void> _share() async {
    if (_sharing || !_current) return;
    setState(() => _sharing = true);
    final result = widget.result;
    try {
      final png = await renderMiniGameShareCard(result);
      if (!_current || widget.result.completedAt != result.completedAt) return;
      await shareGainPathImage(
          png, 'My ${result.game.title} result in GainPath!');
    } catch (_) {
      if (_current)
        showToast(context, 'Could not share this result. Try again.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: _sharing ? null : _share,
        icon: _sharing
            ? const SizedBox.square(
                dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.ios_share_rounded),
        label: Text(_sharing ? 'Preparing image…' : 'Share Result'),
      );
}
