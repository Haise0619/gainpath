import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Balances rows (six metrics become 3+3) without fixed card heights.
class ReportMetricGrid extends StatelessWidget {
  const ReportMetricGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        if (children.isEmpty) return const SizedBox.shrink();
        final minimum =
            180 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
        final capacity =
            math.max(1, ((constraints.maxWidth + 10) / (minimum + 10)).floor());
        final rows = (children.length / capacity).ceil();
        final columns = (children.length / rows).ceil();
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final child in children) SizedBox(width: width, child: child),
        ]);
      });
}
