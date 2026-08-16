import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../../../app/theme.dart';
import '../../../widgets/shared.dart';

/// AD-M5.3 — View Goal Progress Comparison. Each goal gets its own radial
/// gauge: a dial reads as "progress toward a target" more directly than
/// a linear bar, which is why this report's characteristic differs from
/// every other Progress screen.
class GoalProgressScreen extends StatelessWidget {
  const GoalProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Goal progress')),
      body: PageBody(
        children: [
          Text('How you are tracking against the goals you set.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          Panel(
            child: Row(
              children: const [
                Expanded(
                  child: _GoalGauge(
                    label: 'Train 4x / week',
                    detail: '3 of 4',
                    value: 75,
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: _GoalGauge(
                    label: 'Avg form',
                    detail: '84 of 85',
                    value: 99,
                    color: AppColors.accent,
                  ),
                ),
                Expanded(
                  child: _GoalGauge(
                    label: 'Squat 70kg×8',
                    detail: '60 of 70 kg',
                    value: 86,
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Panel(
            background: AppColors.primaryTint,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.emoji_objects_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'One more session this week and you hit your frequency goal.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalGauge extends StatelessWidget {
  final String label;
  final String detail;
  final double value;
  final Color color;
  const _GoalGauge({
    required this.label,
    required this.detail,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 96,
          width: 96,
          child: SfRadialGauge(
            axes: [
              RadialAxis(
                minimum: 0,
                maximum: 100,
                showLabels: false,
                showTicks: false,
                startAngle: 270,
                endAngle: 270,
                radiusFactor: 0.9,
                axisLineStyle: const AxisLineStyle(
                  thickness: 0.14,
                  thicknessUnit: GaugeSizeUnit.factor,
                  color: AppColors.surfaceAlt,
                ),
                pointers: [
                  RangePointer(
                    value: value,
                    width: 0.14,
                    sizeUnit: GaugeSizeUnit.factor,
                    color: color,
                    cornerStyle: CornerStyle.bothCurve,
                  ),
                ],
                annotations: [
                  GaugeAnnotation(
                    positionFactor: 0,
                    widget: Text('${value.round()}%',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        Text(detail,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
      ],
    );
  }
}
