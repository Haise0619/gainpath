import 'package:flutter/material.dart';
import '../../tokens/app_theme.dart';

/// Line-style trend chart drawn with CustomPaint.
class TrendChart extends StatelessWidget {
  final List<int> values;
  final Color color;
  const TrendChart(this.values, {super.key, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      width: double.infinity,
      child: CustomPaint(painter: _TrendPainter(values, color)),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<int> values;
  final Color color;
  _TrendPainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce((a, b) => a > b ? a : b).toDouble();
    final minV = values.reduce((a, b) => a < b ? a : b).toDouble();
    final range = (maxV - minV) == 0 ? 1 : (maxV - minV);

    final path = Path();
    final fill = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height -
          ((values[i] - minV) / range) * (size.height - 16) -
          8;
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();

    canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.20), color.withValues(alpha: 0.0)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height -
          ((values[i] - minV) / range) * (size.height - 16) -
          8;
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = Colors.white);
      canvas.drawCircle(
          Offset(x, y),
          3.5,
          Paint()
            ..color = color
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.values != values;
}
