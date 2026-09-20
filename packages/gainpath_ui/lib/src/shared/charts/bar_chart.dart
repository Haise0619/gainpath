import 'package:flutter/material.dart';
import '../../tokens/app_theme.dart';

/// Simple bar chart with no external dependency.
class BarChart extends StatelessWidget {
  final List<int> values;
  final List<String>? labels;
  final Color color;
  final double height;

  const BarChart(this.values,
      {super.key, this.labels, this.color = AppColors.primary, this.height = 140});

  @override
  Widget build(BuildContext context) {
    final maxValue =
        values.isEmpty ? 1 : values.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final ratio = maxValue == 0 ? 0.0 : values[i] / maxValue;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: (height - 22) * ratio.clamp(0.02, 1.0),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                  ),
                  if (labels != null && i < labels!.length) ...[
                    const SizedBox(height: 6),
                    Text(labels![i],
                        style: const TextStyle(
                            fontSize: 9.5, color: AppColors.inkSoft)),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
