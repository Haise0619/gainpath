import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class AdminCoachScheduleView extends StatefulWidget {
  const AdminCoachScheduleView(
      {super.key,
      required this.repository,
      required this.coachId,
      required this.isCurrent});
  final CoachAvailabilityRepository repository;
  final String coachId;
  final bool Function() isCurrent;
  @override
  State<AdminCoachScheduleView> createState() => _AdminCoachScheduleViewState();
}

class _AdminCoachScheduleViewState extends State<AdminCoachScheduleView> {
  late Future<CoachAvailabilityContext> future =
      widget.repository.load(coachId: widget.coachId);
  Future<CoachRosterSnapshot>? roster;
  void _loadRoster() {
    final repository = widget.repository;
    if (repository is CoachRosterRepository) {
      roster = (repository as CoachRosterRepository)
          .loadRoster(coachId: widget.coachId);
    }
  }

  void _load([String? date]) => setState(() {
    future = widget.repository.load(coachId: widget.coachId, firstLocalDate: date);
  });
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Coach schedule'), actions: [
        IconButton(
            tooltip: 'Refresh schedule',
            onPressed: () {
              roster = null;
              _load();
            },
            icon: const Icon(Icons.refresh))
      ]),
      body: FutureBuilder<CoachAvailabilityContext>(
          future: future,
          builder: (context, snapshot) {
            if (!widget.isCurrent()) {
              return const Center(
                  child: Text('Schedule unavailable for this session.'));
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                  child: Text('Coach schedule unavailable. Refresh to retry.'));
            }
            final data = snapshot.data!;
            if (roster == null) _loadRoster();
            final first = data.days.first.localDate;
            final next = DateTime.parse('${first}T00:00:00Z')
                .add(const Duration(days: 7))
                .toIso8601String()
                .substring(0, 10);
            final through = DateTime.parse('${data.todayLocalDate}T00:00:00Z')
                .add(const Duration(days: 30))
                .toIso8601String()
                .substring(0, 10);
            return PageBody(children: [
              Text('Organization time: ${data.timeZone}'),
              if (roster != null)
                FutureBuilder<CoachRosterSnapshot>(
                    future: roster,
                    builder: (context, snapshot) {
                      if (!widget.isCurrent()) return const SizedBox.shrink();
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const LinearProgressIndicator();
                      }
                      if (snapshot.hasError || snapshot.data == null) {
                        return const Text(
                            'Roster details unavailable. Refresh to retry.');
                      }
                      final schedule = snapshot.data!,
                          weekly = schedule.weeklyAvailability;
                      return Panel(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Eyebrow('Roster scheduling limits'),
                            DetailRow(
                                'Maximum bookable hours per day',
                                weekly == null
                                    ? '-'
                                    : '${weekly.dailyCapacityHours} hours'),
                            DetailRow(
                                'Advance booking window',
                                weekly == null
                                    ? '-'
                                    : '${weekly.advanceBookingWindowDays} days'),
                            const SizedBox(height: 12),
                            const Eyebrow('Recurring working hours'),
                            if (weekly == null)
                              const Text('-')
                            else
                              for (final day in weekly.schedule)
                                DetailRow(
                                    [
                                      'Mon',
                                      'Tue',
                                      'Wed',
                                      'Thu',
                                      'Fri',
                                      'Sat',
                                      'Sun'
                                    ][day.dayOfWeek - 1],
                                    day.isActive
                                        ? '${_minutes(day.startMinute)} – ${_minutes(day.endMinute)} · ${day.branchId}'
                                        : 'Off'),
                            const SizedBox(height: 12),
                            const Eyebrow('Time off and breaks'),
                            if (schedule.exceptions.isEmpty)
                              const Text('No blocked time exceptions.')
                            else
                              for (final block in schedule.exceptions)
                                ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                        '${block.startLabel ?? _utc(block.startAtMillis)} – ${block.endLabel ?? _utc(block.endAtMillis)}'),
                                    subtitle: Text(block.reason.isEmpty
                                        ? '-'
                                        : block.reason)),
                          ]));
                    }),
              const Text('Coach schedule; booking unavailable.'),
              Row(children: [
                TextButton(
                    onPressed: first == data.todayLocalDate
                        ? null
                        : () {
                            final previous =
                                DateTime.parse('${first}T00:00:00Z')
                                    .subtract(const Duration(days: 7))
                                    .toIso8601String()
                                    .substring(0, 10);
                            _load(previous.compareTo(data.todayLocalDate) < 0
                                ? data.todayLocalDate
                                : previous);
                          },
                    child: const Text('Previous 7 days')),
                TextButton(
                    onPressed:
                        next.compareTo(through) > 0 ? null : () => _load(next),
                    child: const Text('Next 7 days'))
              ]),
              for (final day in data.days) ...[
                Text(day.localDate,
                    style: Theme.of(context).textTheme.titleMedium),
                if (day.windows.isEmpty)
                  const Text('No permitted availability windows.'),
                for (final w in day.windows)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          '${day.labelFor(w.startAtMillis)} – ${day.labelFor(w.endAtMillis)}'),
                      subtitle: Text(w.branchId))
              ],
            ]);
          }));
}

String _minutes(int value) =>
    '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
String _utc(int value) =>
    '${DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toIso8601String()} UTC';
