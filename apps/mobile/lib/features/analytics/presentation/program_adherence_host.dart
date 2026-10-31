import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../domain/program_adherence.dart';

class ProgramAdherenceHost extends StatefulWidget {
  const ProgramAdherenceHost(
      {super.key,
      required this.scope,
      required this.activeScope,
      required this.load,
      this.summaryBuilder,
      this.weeklySummaryBuilder,
      this.onChooseProgram,
      this.onOpenProgram,
      this.now});
  final Widget Function(BuildContext, int?)? summaryBuilder;
  final Widget Function(BuildContext, int?, int?)? weeklySummaryBuilder;
  final VoidCallback? onChooseProgram;
  final void Function(String enrollmentId)? onOpenProgram;
  final DateTime? now;
  final SessionScope scope;
  final SessionScope? Function() activeScope;
  final Future<List<ProgramAdherenceSummary>> Function() load;
  @override
  State<ProgramAdherenceHost> createState() => _ProgramAdherenceHostState();
}

class _ProgramAdherenceHostState extends State<ProgramAdherenceHost> {
  late Future<List<ProgramAdherenceSummary>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  @override
  void didUpdateWidget(covariant ProgramAdherenceHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) _future = widget.load();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activeScope() != widget.scope) return const SizedBox.shrink();
    return FutureBuilder<List<ProgramAdherenceSummary>>(
        future: _future,
        builder: (context, snapshot) {
          if (widget.activeScope() != widget.scope) {
            return const SizedBox.shrink();
          }
          final ready = snapshot.connectionState == ConnectionState.done &&
              !snapshot.hasError &&
              snapshot.hasData;
          final summaries =
              ready ? snapshot.data! : <ProgramAdherenceSummary>[];
          final now = widget.now ?? DateTime.now();
          final current = summaries.where((s) => s.isCurrent).firstOrNull;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.weeklySummaryBuilder != null)
                  widget.weeklySummaryBuilder!(
                      context,
                      ready ? completedScheduledThisWeek(summaries, now) : null,
                      ready
                          ? summaries
                              .expand((s) => s.weekAt(now))
                              .where((d) =>
                                  d.status != ProgramAdherenceStatus.rest)
                              .length
                          : null),
                if (widget.summaryBuilder != null)
                  widget.summaryBuilder!(
                      context,
                      ready
                          ? completedScheduledThisWeek(summaries, now)
                          : null),
                if (widget.weeklySummaryBuilder != null ||
                    widget.summaryBuilder != null)
                  const SizedBox(height: 12),
                Card(
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: AppColors.hairline)),
                    child: DefaultTextStyle.merge(
                        style: const TextStyle(color: AppColors.ink),
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Row(children: [
                                    Icon(Icons.calendar_month_rounded,
                                        color: AppColors.primary, size: 20),
                                    SizedBox(width: 8),
                                    Expanded(
                                        child: Text('Current program',
                                            style: TextStyle(
                                                color: AppColors.inkSoft,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600))),
                                  ]),
                                  const SizedBox(height: 8),
                                  if (!ready && !snapshot.hasError)
                                    const Text('Loading program progress…'),
                                  if (snapshot.hasError) ...[
                                    const Text('Program progress unavailable.'),
                                    TextButton(
                                        onPressed: () => setState(() {
                                              _future = widget.load();
                                            }),
                                        child: const Text('Retry')),
                                  ],
                                  if (ready && current == null) ...[
                                    const Text(
                                        'No current program on this device.'),
                                    if (widget.onChooseProgram != null)
                                      TextButton(
                                          onPressed: widget.onChooseProgram,
                                          child:
                                              const Text('Choose a program')),
                                  ],
                                  if (current != null) ...[
                                    Text(current.enrollment.program.title,
                                        style: const TextStyle(
                                            color: AppColors.ink,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold)),
                                    Builder(builder: (context) {
                                      final week = current.weekAt(now);
                                      final scheduled = week
                                          .where((d) =>
                                              d.status !=
                                              ProgramAdherenceStatus.rest)
                                          .length;
                                      final done = week
                                          .where((d) =>
                                              d.status ==
                                              ProgramAdherenceStatus.completed)
                                          .length;
                                      final next = current.nextUnfinished;
                                      final definition = next == null
                                          ? null
                                          : current.enrollment.schedule
                                              .where((d) => d.key == next.key)
                                              .firstOrNull
                                              ?.definition;
                                      final nextTitle = definition
                                              ?.routineSnapshot?['title'] ??
                                          definition?.category ??
                                          'Workout';
                                      final today = programMalaysiaDate(now);
                                      final restToday = current.days.any((d) =>
                                          d.date == today &&
                                          d.status ==
                                              ProgramAdherenceStatus.rest);
                                      return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            if (week.isNotEmpty)
                                              Text(
                                                  'Program week ${week.first.week}',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            Text(
                                                'This week: $done/$scheduled scheduled workouts completed'),
                                            LinearProgressIndicator(
                                                value: scheduled == 0
                                                    ? 0
                                                    : done / scheduled),
                                            if (restToday)
                                              const Text(
                                                  'Today: rest / active recovery'),
                                            if (next == null)
                                              const Text(
                                                  'No unfinished scheduled workouts.'),
                                            if (next != null) ...[
                                              const SizedBox(height: 8),
                                              Text('Next · $nextTitle',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              Text(
                                                  '${next.date.day}/${next.date.month}/${next.date.year} · ${next.date.isBefore(today) ? "Overdue" : next.date == today ? "Today" : "Upcoming"}',
                                                  style: const TextStyle(
                                                      color: AppColors.inkSoft,
                                                      fontSize: 12)),
                                            ],
                                          ]);
                                    }),
                                    if (widget.onOpenProgram != null)
                                      TextButton(
                                          onPressed: () =>
                                              widget.onOpenProgram!(
                                                  current.enrollment.id),
                                          child: const Text('View program')),
                                  ],
                                  if (summaries.isNotEmpty)
                                    ExpansionTile(
                                        tilePadding: EdgeInsets.zero,
                                        title: const Text(
                                            'Program details & past programs'),
                                        children: [
                                          const Text(
                                              'Device records; completion may include self-reported sets.',
                                              style: TextStyle(
                                                  color: AppColors.inkSoft,
                                                  fontSize: 12)),
                                          for (final summary in [
                                            ...summaries
                                                .where((s) => s.isCurrent),
                                            ...summaries
                                                .where((s) => !s.isCurrent)
                                          ])
                                            Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Text(
                                                      '${summary.isCurrent ? "Current" : "Past program"}: ${summary.enrollment.program.title}',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                  Text(
                                                      '${summary.completed}/${summary.scheduled} scheduled workouts completed'),
                                                  Text(
                                                      'Partial: ${summary.count(ProgramAdherenceStatus.partial)} · Skipped: ${summary.skipped} · Pending: ${summary.count(ProgramAdherenceStatus.pending)}'),
                                                  for (final week
                                                      in summary.weeks)
                                                    if (week.isNotEmpty) ...[
                                                      Text(
                                                          'Week ${week.first.week}'),
                                                      Wrap(
                                                          spacing: 8,
                                                          children: [
                                                            for (final day
                                                                in week)
                                                              Chip(
                                                                  label: Text(
                                                                      '${day.date.day}/${day.date.month} ${day.status.name}'))
                                                          ]),
                                                    ],
                                                ]),
                                        ]),
                                ])))),
              ]);
        });
  }
}
