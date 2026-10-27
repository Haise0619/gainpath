import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../domain/curl_arm_metrics.dart';

class CurlArmStats extends StatelessWidget {
  const CurlArmStats({super.key, required this.metrics});
  final CurlArmMetrics metrics;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
            '${metrics.mode.label} · ${metrics.repetitionsPerArm} reps per arm per set',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        for (final row in [
          ('Left arm', metrics.left, metrics.mode != CurlArmMode.rightOnly),
          ('Right arm', metrics.right, metrics.mode != CurlArmMode.leftOnly)
        ])
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                  !row.$3
                      ? '${row.$1}: not selected'
                      : '${row.$1}: ${row.$2.repetitions} full · ${row.$2.partialRepetitions} partial · ${row.$2.formScorePercent == null ? 'Form —' : '${row.$2.formScorePercent!.round()}% est. form'}',
                  style: const TextStyle(color: AppColors.inkSoft))),
      ]);
}
