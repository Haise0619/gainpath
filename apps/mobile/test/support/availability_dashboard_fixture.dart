import 'package:gainpath_domain/coaching.dart';
import '../coach_roster_ui_test.dart' show RosterUiFake;

class DashboardRosterFake extends RosterUiFake {
  static final now = DateTime.utc(2026, 11, 8, 2).millisecondsSinceEpoch;
  @override
  CoachRosterSnapshot snapshot() => CoachRosterSnapshot(
      coachId: 'coach',
      revision: revision,
      serverNowMillis: now,
      todayLocalDate: '2026-11-08',
      timeZone: 'Asia/Kuala_Lumpur',
      policyVersion: 'booking-v1',
      throughLocalDate: '2026-12-08',
      assignedBranchIds: ['main'],
      weeklyAvailability: weekly,
      exceptions: exceptions);
  @override
  CoachAvailabilityContext context(String id) => calendar(id);
  CoachAvailabilityContext calendar(String id,
      {String? firstLocalDate, int dayCount = 7}) {
    final first = DateTime.parse(firstLocalDate ?? '2026-11-08');
    return CoachAvailabilityContext(
        coachId: id,
        serverNowMillis: now,
        todayLocalDate: '2026-11-08',
        timeZone: 'Asia/Kuala_Lumpur',
        policyVersion: 'booking-v1',
        writableFromLocalDate: '2026-11-09',
        writableThroughLocalDate: '2026-12-08',
        assignedBranchIds: ['main'],
        days: List.generate(dayCount, (i) {
          final date = first.add(Duration(days: i)),
              label = date.toIso8601String().substring(0, 10);
          final midnight = DateTime.utc(date.year, date.month, date.day)
              .subtract(const Duration(hours: 8))
              .millisecondsSinceEpoch;
          final day = weekly?.schedule
              .where((d) => d.dayOfWeek == date.weekday)
              .firstOrNull;
          return CoachAvailabilityDay(
              localDate: label,
              editable: label.compareTo('2026-11-09') >= 0,
              windows: day?.isActive == true
                  ? [
                      DatedCoachWindow(
                          branchId: day!.branchId,
                          startAtMillis: midnight + day.startMinute * 60000,
                          endAtMillis: midnight + day.endMinute * 60000)
                    ]
                  : [],
              boundaries: List.generate(
                  49,
                  (j) => CoachTimeBoundary(
                      atMillis: midnight + j * 1800000,
                      label:
                          '${(j ~/ 2).toString().padLeft(2, '0')}:${j.isEven ? '00' : '30'} GMT+8')));
        }));
  }

  @override
  Future<CoachAvailabilityContext> load(
          {required String coachId,
          String? firstLocalDate,
          int dayCount = 7}) async =>
      calendar(coachId, firstLocalDate: firstLocalDate, dayCount: dayCount);
}
