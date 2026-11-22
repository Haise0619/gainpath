import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class WorkoutFact extends StatelessWidget {
  const WorkoutFact(this.value, this.label,
      {super.key,
      this.icon = Icons.fitness_center_rounded,
      this.color = AppColors.primaryDark,
      this.tint = AppColors.primaryTint});
  final String value, label;
  final IconData icon;
  final Color color, tint;
  @override
  Widget build(BuildContext context) => Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(minWidth: 110),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.hairline)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: tint, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 21, color: color)),
            const SizedBox(height: 12),
            Text(value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 32,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 6),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.inkSoft)),
          ])));
}
