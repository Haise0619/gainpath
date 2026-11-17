import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Locally drawn achievement medals shared by the collection and export card.
class AchievementArtwork extends StatelessWidget {
  const AchievementArtwork({
    super.key,
    required this.id,
    required this.unlocked,
    this.size = 72,
  });

  final String id;
  final bool unlocked;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(
          size: Size.square(size),
          painter: AchievementArtworkPainter(id: id, unlocked: unlocked),
        ),
      );
}

class AchievementArtworkPainter extends CustomPainter {
  const AchievementArtworkPainter({required this.id, required this.unlocked});

  final String id;
  final bool unlocked;

  static const _palettes = <String, (Color, Color)>{
    'first-check-in': (Color(0xFF16B894), Color(0xFF086A63)),
    'check-in-streak-3': (Color(0xFFFF8B54), Color(0xFFC23C34)),
    'check-in-streak-7': (Color(0xFF737CFC), Color(0xFF4034B8)),
    'check-in-streak-14': (Color(0xFFFFC94E), Color(0xFFC37020)),
    'first-workout': (Color(0xFF4EC3FD), Color(0xFF2765C4)),
    'workout-regular': (Color(0xFFE885F0), Color(0xFF8338B1)),
    'century-club': (Color(0xFF49C982), Color(0xFF147A58)),
    'routine-finisher': (Color(0xFFBA9BFF), Color(0xFF6636C3)),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final (light, dark) = unlocked
        ? _palettes[id] ?? _palettes['routine-finisher']!
        : (const Color(0xFFB5B7C5), const Color(0xFF797B90));
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    const center = Offset(50, 48);
    final rim = _seal(center, 42);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [light, dark],
    ).createShader(const Rect.fromLTWH(8, 8, 84, 84));

    if (unlocked) {
      canvas.drawCircle(
        center,
        46,
        Paint()
          ..color = light.withValues(alpha: .28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas.drawPath(
      _polygon(const [
        Offset(29, 65),
        Offset(20, 96),
        Offset(34, 90),
        Offset(41, 98),
        Offset(50, 73),
        Offset(59, 98),
        Offset(66, 90),
        Offset(80, 96),
        Offset(71, 65),
      ]),
      Paint()..color = dark,
    );
    canvas.drawPath(rim, Paint()..shader = gradient);
    canvas.drawPath(
      _seal(center, 36),
      Paint()
        ..color = Colors.white.withValues(alpha: .40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    canvas.drawCircle(
      center,
      30,
      Paint()..color = Colors.white.withValues(alpha: .12),
    );
    _drawSymbol(canvas);
    canvas.restore();
  }

  void _drawSymbol(Canvas canvas) {
    final ink = Paint()..color = const Color(0xFFFFF9EB);
    final stroke = Paint()
      ..color = ink.color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void rounded(double x, double y, double w, double h, double r) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w, h),
            Radius.circular(r),
          ),
          ink);
    }

    switch (id) {
      case 'first-check-in':
        canvas.drawLine(const Offset(38, 32), const Offset(38, 65), stroke);
        canvas.drawPath(
            _polygon(const [
              Offset(39, 33),
              Offset(64, 33),
              Offset(58, 41),
              Offset(64, 49),
              Offset(39, 49),
            ]),
            ink);
      case 'check-in-streak-3':
        canvas.drawPath(
            Path()
              ..moveTo(49, 25)
              ..cubicTo(67, 39, 72, 49, 65, 60)
              ..cubicTo(58, 71, 39, 71, 34, 58)
              ..cubicTo(30, 48, 38, 40, 42, 35)
              ..quadraticBezierTo(41, 44, 47, 47)
              ..quadraticBezierTo(53, 41, 49, 25)
              ..close(),
            ink);
        canvas.drawPath(
            Path()
              ..moveTo(51, 47)
              ..quadraticBezierTo(64, 62, 51, 65)
              ..quadraticBezierTo(39, 64, 51, 47)
              ..close(),
            Paint()
              ..color =
                  unlocked ? const Color(0xFFFFB762) : const Color(0xFFA0A2AC));
      case 'check-in-streak-7':
        canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(34, 34, 32, 29),
              const Radius.circular(5),
            ),
            stroke);
        canvas.drawLine(const Offset(35, 43), const Offset(65, 43), stroke);
        canvas.drawLine(const Offset(42, 30), const Offset(42, 37), stroke);
        canvas.drawLine(const Offset(58, 30), const Offset(58, 37), stroke);
        canvas.drawPath(
            Path()
              ..moveTo(44, 53)
              ..lineTo(49, 57)
              ..lineTo(57, 49),
            stroke);
      case 'check-in-streak-14':
        canvas.drawPath(
            _polygon(const [
              Offset(34, 40),
              Offset(42, 47),
              Offset(50, 33),
              Offset(58, 47),
              Offset(66, 40),
              Offset(62, 57),
              Offset(38, 57),
            ]),
            ink);
        rounded(38, 60, 24, 4, 2);
        for (final tip in const [
          Offset(34, 37),
          Offset(50, 30),
          Offset(66, 37)
        ]) {
          canvas.drawCircle(tip, 2.3, ink);
        }
      case 'first-workout':
        canvas.save();
        canvas.translate(50, 48);
        canvas.rotate(-math.pi / 4);
        rounded(-20, -9, 6, 18, 2);
        rounded(-12, -13, 5, 26, 2);
        rounded(-8, -3, 16, 6, 1);
        rounded(7, -13, 5, 26, 2);
        rounded(14, -9, 6, 18, 2);
        canvas.restore();
      case 'workout-regular':
        canvas.drawPath(_star(const Offset(50, 47), 17, 8), ink);
        canvas.drawPath(_star(const Offset(69, 35), 5, 2), ink);
        canvas.drawPath(_star(const Offset(32, 58), 4, 2), ink);
      case 'century-club':
        final number = TextPainter(
          text: TextSpan(
            text: '100',
            style: TextStyle(
              color: ink.color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        number.paint(
            canvas, Offset(50 - number.width / 2, 48 - number.height / 2));
        number.dispose();
        canvas.drawLine(const Offset(41, 65), const Offset(59, 65), stroke);
      case 'routine-finisher':
        canvas.drawPath(
            Path()
              ..moveTo(39, 33)
              ..lineTo(61, 33)
              ..lineTo(59, 49)
              ..quadraticBezierTo(50, 61, 41, 49)
              ..close(),
            ink);
        canvas.drawPath(
            Path()
              ..moveTo(39, 37)
              ..lineTo(33, 37)
              ..quadraticBezierTo(32, 49, 42, 49),
            stroke);
        canvas.drawPath(
            Path()
              ..moveTo(61, 37)
              ..lineTo(67, 37)
              ..quadraticBezierTo(68, 49, 58, 49),
            stroke);
        rounded(48, 51, 4, 11, 1);
        rounded(42, 61, 16, 4, 2);
      default:
        canvas.drawPath(_star(const Offset(50, 48), 15, 7), ink);
    }
  }

  @override
  bool shouldRepaint(covariant AchievementArtworkPainter oldDelegate) =>
      oldDelegate.id != id || oldDelegate.unlocked != unlocked;
}

Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);

Path _seal(Offset center, double radius) => _polygon([
      for (var i = 0; i < 24; i++)
        center +
            Offset.fromDirection(
              i * math.pi / 12 - math.pi / 2,
              i.isEven ? radius : radius * .95,
            ),
    ]);

Path _star(Offset center, double outer, double inner) => _polygon([
      for (var i = 0; i < 10; i++)
        center +
            Offset.fromDirection(
              i * math.pi / 5 - math.pi / 2,
              i.isEven ? outer : inner,
            ),
    ]);
