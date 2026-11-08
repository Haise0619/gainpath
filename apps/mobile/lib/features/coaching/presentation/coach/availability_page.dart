import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// The canonical availability layout, shared by local and persisted data adapters.
class AvailabilityPage extends StatelessWidget {
  const AvailabilityPage(
      {super.key,
      required this.weekAtGlance,
      required this.workingHours,
      required this.timeOff,
      required this.limits,
      this.header = const [],
      this.footer = const [],
      this.actions,
      this.onAddTimeOff,
      this.workingHoursTitle = 'Working hours',
      this.limitsTitle = 'Booking limits',
      this.saveBar,
      this.onRefresh,
      this.timeOffSummary,
      this.limitsSummary});
  final Widget? saveBar;
  final Future<void> Function()? onRefresh;
  final String? timeOffSummary, limitsSummary;
  final Widget weekAtGlance;
  final List<Widget> workingHours, timeOff, limits, header, footer;
  final List<Widget>? actions;
  final VoidCallback? onAddTimeOff;
  final String workingHoursTitle, limitsTitle;
  @override
  Widget build(BuildContext context) {
    final content = PageBody(children: [
      ...header,
      weekAtGlance,
      const SizedBox(height: 22),
      Eyebrow(workingHoursTitle),
      const SizedBox(height: 8),
      ...workingHours,
      const SizedBox(height: 20),
      const Eyebrow('Quick Settings'),
      const SizedBox(height: 8),
      Card(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.hairline)),
          margin: EdgeInsets.zero,
          child: ExpansionTile(
              key: const Key('availability-time-off'),
              title: const Text('Time Off & Breaks'),
              subtitle: Text(timeOffSummary ?? 'Manage blocked periods'),
              leading: const Icon(Icons.event_busy_outlined,
                  color: AppColors.primary),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                        onPressed: onAddTimeOff,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Time Off'))),
                ...timeOff
              ])),
      const SizedBox(height: 12),
      Card(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.hairline)),
          margin: EdgeInsets.zero,
          child: ExpansionTile(
              key: const Key('availability-booking-limits'),
              title: Text(limitsTitle),
              subtitle: Text(limitsSummary ?? 'Capacity and advance booking'),
              leading: const Icon(Icons.tune_rounded, color: AppColors.primary),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: limits)),
      if (footer.isNotEmpty) ...[const SizedBox(height: 16), ...footer]
    ]);
    return Scaffold(
        appBar: AppBar(title: const Text('Availability'), actions: actions),
        body: onRefresh == null
            ? content
            : RefreshIndicator(onRefresh: onRefresh!, child: content),
        bottomNavigationBar: saveBar);
  }
}
