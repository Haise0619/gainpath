import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/sparkcharts.dart';
import '../../../../app/theme.dart';

/// A dashboard entry point into one deep-dive report: icon, title,
/// one-line description, and a spark-chart thumbnail giving an
/// at-a-glance trend before the member ever taps in.
class ReportPreviewTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<double> sparkData;
  final Color sparkColor;
  final VoidCallback onTap;

  const ReportPreviewTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.sparkData,
    required this.onTap,
    this.sparkColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 12.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 64,
              height: 34,
              child: SfSparkAreaChart(
                data: sparkData,
                color: sparkColor.withValues(alpha: 0.85),
                borderColor: sparkColor,
                borderWidth: 1.6,
                axisLineColor: Colors.transparent,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 13, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}
