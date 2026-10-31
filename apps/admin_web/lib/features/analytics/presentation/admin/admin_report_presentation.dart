import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// Shared presentation only; report data and calculation contracts stay unchanged.
class AdminReportDetails extends StatelessWidget {
  const AdminReportDetails(
      {super.key, required this.child, this.title = 'Definitions & coverage'});
  final Widget child;
  final String title;
  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        leading: const Icon(Icons.info_outline_rounded,
            size: 18, color: AppColors.inkSoft),
        title: Text(title, style: Theme.of(context).textTheme.labelLarge),
        children: [Align(alignment: Alignment.centerLeft, child: child)],
      );
}

const adminReportPalette = <Color>[
  AppColors.primary,
  AppColors.accent,
  AppColors.success,
  AppColors.info
];
