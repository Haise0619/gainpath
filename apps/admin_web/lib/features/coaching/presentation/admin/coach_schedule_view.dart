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
  void _load([String? date]) => setState(() => future =
      widget.repository.load(coachId: widget.coachId, firstLocalDate: date));
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Coach schedule'), actions: [
        IconButton(
            tooltip: 'Refresh schedule',
            onPressed: () => _load(),
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
