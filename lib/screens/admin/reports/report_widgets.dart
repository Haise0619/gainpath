import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../widgets/shared.dart';
import 'csv_export.dart';

/// A `MockData.allBookings`-derived date/branch filter, applied live
/// across every report section that can honestly support it. Sections
/// whose underlying mock data has no date/branch dimension (posture,
/// retention, rewards, gamification) don't take a filter — pretending to
/// filter data that was never date-tagged would just be a fake control.
class ReportFilter {
  /// Window length in days, or null for "all time" (since the earliest
  /// booking on record).
  final int? days;
  final String? branch;
  const ReportFilter({this.days, this.branch});

  bool get isDefault => days == null && branch == null;

  DateTime cutoff(List<DateTime> allDates) {
    if (days != null) return DateTime.now().subtract(Duration(days: days!));
    if (allDates.isEmpty) return DateTime.now().subtract(const Duration(days: 60));
    final earliest = allDates.reduce((a, b) => a.isBefore(b) ? a : b);
    return earliest;
  }

  int rangeDays(List<DateTime> allDates) {
    final span = DateTime.now().difference(cutoff(allDates)).inDays;
    return span < 1 ? 1 : span;
  }
}

/// Every report section shares this shell: an anchor target for the
/// in-page jump nav, a title/subtitle header, an optional "Live · N
/// records" or "Illustrative" provenance tag, and an export button that
/// triggers a real CSV download rather than a toast.
class ReportSection extends StatelessWidget {
  final GlobalKey anchorKey;
  final String title;
  final String subtitle;
  final bool live;

  /// Overrides the tag's default "Live · filtered" / "Illustrative" text
  /// — the default is Reports-specific phrasing (tied to the date/branch
  /// filter bar), other admin pages reusing this shell supply their own.
  final String? tagLabel;
  final String exportFilename;
  final List<List<Object?>> Function() exportRows;
  final Widget child;

  const ReportSection({
    super.key,
    required this.anchorKey,
    required this.title,
    required this.subtitle,
    required this.live,
    this.tagLabel,
    required this.exportFilename,
    required this.exportRows,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: anchorKey,
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(width: 10),
                        _ProvenanceTag(live: live, label: tagLabel),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.download_rounded, size: 19),
                tooltip: 'Export CSV',
                onPressed: () {
                  downloadCsv(exportFilename, exportRows());
                  showToast(context, 'Downloaded $exportFilename.');
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ProvenanceTag extends StatelessWidget {
  final bool live;
  final String? label;
  const _ProvenanceTag({required this.live, this.label});

  @override
  Widget build(BuildContext context) {
    final color = live ? AppColors.success : AppColors.inkSoft;
    final bg = live ? AppColors.successTint : AppColors.surfaceAlt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(live ? Icons.bolt_rounded : Icons.info_outline_rounded, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label ?? (live ? 'Live · filtered' : 'Illustrative'),
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// Shown in place of a chart when a filter combination matches nothing —
/// the `Exc-12.2a` "no data found" branch, instead of rendering a blank
/// or broken-looking chart.
class NoFilteredData extends StatelessWidget {
  final String message;
  const NoFilteredData({super.key, this.message = 'No data for this period or branch.'});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.filter_alt_off_rounded, size: 26, color: AppColors.hairline),
              const SizedBox(height: 8),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
