import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/admin_reporting_gateway.dart';
import '../../application/business_dashboard_metrics.dart';
import '../../application/admin_operational_metrics.dart';
import 'original_report_data_widgets.dart';

/// Reusable Analytics Page Header.
class AnalyticsPageHeader extends StatelessWidget {
  const AnalyticsPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onRefresh,
    this.onExport,
    this.loading = false,
    this.exporting = false,
    this.exportEnabled = true,
    this.exportTooltip = 'Export current report to CSV',
  });

  final String title;
  final String subtitle;
  final VoidCallback? onRefresh;
  final VoidCallback? onExport;
  final bool loading;
  final bool exporting;
  final bool exportEnabled;
  final String exportTooltip;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      letterSpacing: -0.3,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkSoft,
                      height: 1.35,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Refresh reports',
              onPressed: loading ? null : onRefresh,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.inkSoft,
                padding: const EdgeInsets.all(10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.hairline),
                ),
              ),
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 19),
            ),
            if (onExport != null) ...[
              const SizedBox(width: 10),
              Tooltip(
                message: exportTooltip,
                child: FilledButton.icon(
                  onPressed: (!exportEnabled || loading || exporting)
                      ? null
                      : onExport,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.35),
                    disabledForegroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  icon: exporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 17),
                  label: Text(
                    exporting ? 'Exporting…' : 'Export CSV',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Compact Date Range Toolbar preserving exact preset options, custom date picker,
/// and branch selection.
class AnalyticsDateRangeToolbar extends StatelessWidget {
  const AnalyticsDateRangeToolbar({
    super.key,
    required this.selectedDays,
    required this.customRange,
    required this.onSelectDays,
    required this.onPickCustomDates,
    this.branchSelector,
    this.loading = false,
  });

  final int? selectedDays;
  final DateTimeRange? customRange;
  final ValueChanged<int?> onSelectDays;
  final VoidCallback onPickCustomDates;
  final Widget? branchSelector;
  final bool loading;

  static const dateOptions = [null, 7, 30, 90];
  static const dateLabels = {
    null: 'All recorded dates',
    7: '7 days',
    30: '30 days',
    90: '90 days',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.tune_rounded, size: 16, color: AppColors.inkSoft),
              SizedBox(width: 6),
              Text(
                'Filter Range',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          ...dateOptions.map((days) {
            final isSelected = customRange == null && days == selectedDays;
            return ChoiceChip(
              label: Text(dateLabels[days]!),
              selected: isSelected,
              onSelected: (_) => onSelectDays(days),
              backgroundColor: AppColors.surfaceAlt,
              selectedColor: AppColors.primary,
              showCheckmark: false,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.ink,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(
                  color:
                      isSelected ? AppColors.primary : AppColors.hairline,
                ),
              ),
            );
          }),
          Container(
            width: 1,
            height: 20,
            color: AppColors.hairline,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range_outlined, size: 15),
            label: Text(
              customRange != null
                  ? '${reportCalendarDate(customRange!.start)} – ${reportCalendarDate(customRange!.end)}'
                  : 'Custom dates',
              style: TextStyle(
                fontSize: 12,
                fontWeight: customRange != null
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: customRange != null
                    ? AppColors.primary
                    : AppColors.ink,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              backgroundColor: customRange != null
                  ? AppColors.primaryTint
                  : AppColors.surfaceAlt,
              side: BorderSide(
                color: customRange != null
                    ? AppColors.primary
                    : AppColors.hairline,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              visualDensity: VisualDensity.compact,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: onPickCustomDates,
          ),
          if (branchSelector != null) ...[
            Container(
              width: 1,
              height: 20,
              color: AppColors.hairline,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            branchSelector!,
          ],
        ],
      ),
    );
  }
}

/// Compact Data Scope / Reporting Coverage disclosure widget.
class AnalyticsDataScope extends StatelessWidget {
  const AnalyticsDataScope({super.key, required this.snapshot});
  final AdminReportingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ops = snapshot.operations;
    if (ops == null) return const SizedBox.shrink();

    final isAllDates = snapshot.query.range.start.millisecondsSinceEpoch == 0;
    final rangeText = isAllDates
        ? 'All recorded dates'
        : '${reportCalendarDate(snapshot.query.range.start)} – ${reportCalendarDate(snapshot.query.range.end.subtract(const Duration(milliseconds: 1)))}';

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          childrenPadding:
              const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              const Text(
                'Reporting period & coverage',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Text(
                  '$rangeText · UTC+08:00',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 14, color: AppColors.inkSoft),
                      const SizedBox(width: 6),
                      Text(
                        'Timezone: Malaysia Time (UTC+08:00) · Active range: $rangeText',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Inclusion rules: Current organization account census independent of selected dates. Appointments by creation time; payment receipts by clearance time. Excludes review-associated and refunded transactions from cleared collection totals.',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.inkSoft,
                        height: 1.45),
                  ),
                  if (snapshot.unified != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Scenario data: ${BusinessDashboardMetrics.revenueDefinition}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Data freshness: Read ${ops.sourceReadStartedAt.toUtc().add(adminReportZone).toIso8601String().substring(11, 19)}–${snapshot.capturedAt.toUtc().add(adminReportZone).toIso8601String().substring(11, 19)} UTC+08:00.',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkSoft,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standardized KPI Metric Card with consistent height, optional lavender tint,
/// 40x40 rounded icon, dominant value, and contextual note.
class AnalyticsMetricCard extends StatelessWidget {
  const AnalyticsMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.contextNote,
    this.highlighted = false,
    this.width,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? contextNote;
  final bool highlighted;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.primaryTint.withValues(alpha: 0.6)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.hairline,
          width: highlighted ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: highlighted ? 0.04 : 0.015),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: highlighted
                        ? AppColors.primaryDark
                        : AppColors.inkSoft,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: highlighted
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: highlighted
                      ? AppColors.primary
                      : AppColors.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: highlighted ? AppColors.primary : AppColors.ink,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            contextNote ?? ' ',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: highlighted
                  ? AppColors.primaryDark.withValues(alpha: 0.8)
                  : AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standardized Chart & Section Container Card.
class AnalyticsChartCard extends StatelessWidget {
  const AnalyticsChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
    this.badge,
    this.footer,
    this.padding = const EdgeInsets.all(20),
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  final Widget? badge;
  final Widget? footer;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          badge!,
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.inkSoft,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
          if (footer != null) ...[
            const SizedBox(height: 14),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// Visual Progress Ring comparing active workout members against total current members.
class MemberWorkoutCoverageRing extends StatelessWidget {
  const MemberWorkoutCoverageRing({
    super.key,
    required this.membersWithActivity,
    required this.totalActiveMembers,
    this.isLoading = false,
  });

  final int membersWithActivity;
  final int totalActiveMembers;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final double ratio = totalActiveMembers > 0
        ? (membersWithActivity / totalActiveMembers).clamp(0.0, 1.0)
        : 0.0;
    final int percentage = (ratio * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: CircularProgressIndicator(
                    value: isLoading ? null : ratio,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    color: AppColors.primary,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isLoading ? '…' : '$percentage%',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          height: 1.0,
                        ),
                      ),
                      const Text(
                        'Coverage',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$membersWithActivity of $totalActiveMembers active members',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Recorded workout activity in the selected period. Denominator reflects total active accounts.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.inkSoft,
                    height: 1.35,
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

/// Membership Plan Distribution Component (Free, Basic, Premium, Unknown).
class MembershipPlanDistribution extends StatelessWidget {
  const MembershipPlanDistribution({
    super.key,
    required this.tiers,
    required this.activeSubscriptions,
    required this.expiredSubscriptions,
  });

  final Map<String, int>? tiers;
  final int? activeSubscriptions;
  final int expiredSubscriptions;

  static const _tierColors = {
    'premium': AppColors.primary,
    'basic': AppColors.primarySoft,
    'free': Color(0xFF2EC4B6),
    'unknown': Color(0xFF94A3B8),
  };

  @override
  Widget build(BuildContext context) {
    if (tiers == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Membership plan distribution is unavailable.',
          style: TextStyle(color: AppColors.inkSoft),
        ),
      );
    }

    final total = tiers!.values.fold<int>(0, (sum, val) => sum + val);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Active Plan Assignments',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${activeSubscriptions ?? '—'} active subscriptions',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 14,
            child: total == 0
                ? Container(color: AppColors.hairline)
                : Row(
                    children: [
                      for (final entry in tiers!.entries)
                        if (entry.value > 0)
                          Expanded(
                            flex: entry.value,
                            child: Container(
                              color: _tierColors[entry.key] ?? AppColors.inkSoft,
                            ),
                          ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final entry in tiers!.entries)
              if (entry.value > 0 || entry.key != 'unknown')
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _tierColors[entry.key] ?? AppColors.inkSoft,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${entry.key[0].toUpperCase()}${entry.key.substring(1)}: ${entry.value}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink,
                      ),
                    ),
                    if (total > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(${(entry.value / total * 100).toStringAsFixed(0)}%)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ],
                ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '$expiredSubscriptions expired subscriptions · Active counts exclude expired and unassigned plans. Distribution includes current recorded plan assignments.',
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.inkSoft,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Operational "Needs Attention" alert panel for admin reviews, cancellations, and issues.
class AnalyticsAttentionPanel extends StatelessWidget {
  const AnalyticsAttentionPanel({
    super.key,
    required this.cancelledCount,
    required this.reviewCount,
    required this.reviewMinor,
    required this.onOpenCoaching,
    required this.onOpenFinancial,
  });

  final int cancelledCount;
  final int reviewCount;
  final int reviewMinor;
  final VoidCallback onOpenCoaching;
  final VoidCallback onOpenFinancial;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.assignment_late_outlined,
                  size: 18, color: AppColors.warning),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Needs Attention & Operational Alerts',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Operational states requiring administrator oversight or follow-up.',
            style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: onOpenCoaching,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cancelledCount > 0
                    ? AppColors.surfaceAlt
                    : AppColors.surfaceAlt.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    size: 20,
                    color: cancelledCount > 0
                        ? AppColors.warning
                        : AppColors.inkSoft,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$cancelledCount cancelled bookings',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Appointment outcomes created in selected dates.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.inkSoft),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onOpenFinancial,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: reviewCount > 0
                    ? AppColors.warning.withValues(alpha: 0.08)
                    : AppColors.success.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: reviewCount > 0
                      ? AppColors.warning.withValues(alpha: 0.3)
                      : AppColors.success.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    reviewCount > 0
                        ? Icons.receipt_long_outlined
                        : Icons.check_circle_outline_rounded,
                    size: 20,
                    color: reviewCount > 0
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reviewCount == 0
                              ? 'No payment records awaiting review'
                              : '$reviewCount payment records awaiting review (${reportMoney(reviewMinor)})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: reviewCount > 0
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          reviewCount == 0
                              ? 'All recorded payment transactions are verified and in good order.'
                              : 'Payment clearances in review state during the selected period.',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.inkSoft),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick Links to other reporting modules.
class AnalyticsQuickLinks extends StatelessWidget {
  const AnalyticsQuickLinks({
    super.key,
    required this.onOpenFinancial,
    required this.onOpenFitness,
    required this.onOpenCoaching,
    required this.onOpenEngagement,
  });

  final VoidCallback onOpenFinancial;
  final VoidCallback onOpenFitness;
  final VoidCallback onOpenCoaching;
  final VoidCallback onOpenEngagement;

  @override
  Widget build(BuildContext context) {
    final links = [
      (
        'Financial Analytics',
        'Collections, receipts & subscriptions',
        Icons.account_balance_wallet_outlined,
        onOpenFinancial
      ),
      (
        'Fitness Analytics',
        'AI camera workouts & form scores',
        Icons.fitness_center_outlined,
        onOpenFitness
      ),
      (
        'Coaching Analytics',
        'Coach performance & booking capacity',
        Icons.sports_outlined,
        onOpenCoaching
      ),
      (
        'Engagement Analytics',
        'Branch check-ins & facility visits',
        Icons.qr_code_scanner_rounded,
        onOpenEngagement
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      final mid = constraints.maxWidth >= 500;
      final columns = wide ? 4 : (mid ? 2 : 1);
      final itemWidth = (constraints.maxWidth - (columns - 1) * 12) / columns;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Explore Detailed Reports',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Drill down into domain-specific operational datasets.',
            style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: links.map((link) {
              return InkWell(
                onTap: link.$4,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: itemWidth,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(link.$3,
                            size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              link.$1,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              link.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 16, color: AppColors.inkSoft),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
    });
  }
}
