import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

/// Keeps prototype workflows on the canonical availability contracts.
class MockAvailabilityRepositoryAdapter
    implements CoachAvailabilityRepository, CoachRosterRepository {
  MockAvailabilityRepositoryAdapter(this._legacy);
  final AvailabilityRepository _legacy;
  static final _states = Expando<_MockAvailabilityState>();
  static final _exactExceptions = Expando<CoachTimeException>();
  _MockAvailabilityState get _state =>
      _states[_legacy] ??= _MockAvailabilityState();
  static DateTime _localNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 8));
  static String _date(DateTime date) => date.toIso8601String().substring(0, 10);
  static int _midnight(String date) =>
      DateTime.parse('${date}T00:00:00+08:00').millisecondsSinceEpoch;
  static String _label(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

  @override
  SessionScope get scope =>
      SessionScope(userId: 'mock-coach', organizationId: 'mock-org');

  CoachWeeklyAvailability get _weekly =>
      _state.weekly ??
      CoachWeeklyAvailability(
        dailyCapacityHours:
            _legacy.dailyBookingCap > 0 ? _legacy.dailyBookingCap : 8,
        advanceBookingWindowDays:
            _legacy.advanceBookingDays > 0 ? _legacy.advanceBookingDays : 14,
        schedule: List.generate(7, (i) {
          final old =
              _legacy.workingDays.length > i ? _legacy.workingDays[i] : null;
          return CoachWeeklyDay(
              dayOfWeek: i + 1,
              isActive: old?.active ?? i < 5,
              startMinute: old?.start.minutesSinceMidnight ?? 540,
              endMinute: old?.end.minutesSinceMidnight ?? 1020,
              branchId: 'main');
        }),
      );

  @override
  Future<CoachRosterSnapshot> loadRoster({required String coachId}) async {
    final now = _localNow();
    final exceptions = _legacy.blockedSlots.map((block) {
      final exact = _exactExceptions[block];
      if (exact != null) return exact;
      final midnight = _midnight(_date(block.date));
      final start =
          block.fullDay ? 0 : block.startTime?.minutesSinceMidnight ?? 0;
      final end =
          block.fullDay ? 1440 : block.endTime?.minutesSinceMidnight ?? 1440;
      return CoachTimeException(
          id: block.id,
          type: block.type.name,
          reason: block.reason,
          startAtMillis: midnight + start * 60000,
          endAtMillis: midnight + end * 60000,
          startLabel: block.fullDay ? 'Full day' : _label(start),
          endLabel: block.fullDay ? 'Full day' : _label(end));
    }).toList();
    return CoachRosterSnapshot(
        coachId: coachId,
        revision: _state.rosterRevision,
        serverNowMillis: DateTime.now().millisecondsSinceEpoch,
        todayLocalDate: _date(now),
        timeZone: 'Asia/Kuala_Lumpur',
        policyVersion: 'v1',
        throughLocalDate: _date(now.add(const Duration(days: 30))),
        assignedBranchIds: const ['main'],
        weeklyAvailability: _weekly,
        exceptions: exceptions);
  }

  @override
  Future<CoachRosterSnapshot> saveRoster(
      {required CoachRosterSnapshot baseline,
      required CoachWeeklyAvailability weeklyAvailability,
      required List<CoachTimeException> exceptions,
      required String requestId}) async {
    _legacy.dailyBookingCap = weeklyAvailability.dailyCapacityHours;
    _legacy.advanceBookingDays = weeklyAvailability.advanceBookingWindowDays;
    _state.weekly = weeklyAvailability;
    _state.rosterRevision++;
    for (final day in weeklyAvailability.schedule) {
      final index = day.dayOfWeek - 1;
      if (index < _legacy.workingDays.length) {
        final old = _legacy.workingDays[index];
        old.active = day.isActive;
        old.start = LocalTime(
            hour: day.startMinute ~/ 60, minute: day.startMinute % 60);
        old.end = LocalTime(
            hour: (day.endMinute ~/ 60) % 24, minute: day.endMinute % 60);
      }
    }
    _legacy.blockedSlots.clear();
    for (final exception in exceptions) {
      final start = DateTime.fromMillisecondsSinceEpoch(exception.startAtMillis,
              isUtc: true)
          .add(const Duration(hours: 8));
      final end = DateTime.fromMillisecondsSinceEpoch(exception.endAtMillis,
              isUtc: true)
          .add(const Duration(hours: 8));
      final block = BlockedSlot(
          id: exception.id,
          type: switch (exception.type) {
            'breakTime' => BlockType.breakTime,
            'offDay' => BlockType.offDay,
            _ => BlockType.leave
          },
          reason: exception.reason,
          date: DateTime(start.year, start.month, start.day),
          fullDay: exception.startLabel == 'Full day',
          startTime: LocalTime(hour: start.hour, minute: start.minute),
          endTime: LocalTime(hour: end.hour, minute: end.minute));
      // Legacy slots cannot express multi-day intervals; retain the exact value.
      _exactExceptions[block] = exception;
      _legacy.blockedSlots.add(block);
    }
    return loadRoster(coachId: baseline.coachId);
  }

  @override
  Future<CoachAvailabilityContext> load(
      {required String coachId,
      String? firstLocalDate,
      int dayCount = 7}) async {
    final now = _localNow();
    final start = DateTime.parse(firstLocalDate ?? _date(now));
    final today = _date(now);
    final through = _date(now.add(const Duration(days: 30)));
    final weekly = _weekly;
    final days = List.generate(dayCount, (i) {
      final date = _date(start.add(Duration(days: i)));
      final weekday = start.add(Duration(days: i)).weekday;
      final day =
          weekly.schedule.where((d) => d.dayOfWeek == weekday).firstOrNull;
      final midnight = _midnight(date);
      final key = '$coachId:$date';
      final windows = day?.isActive == true
          ? [
              DatedCoachWindow(
                  branchId: day!.branchId,
                  startAtMillis: midnight + day.startMinute * 60000,
                  endAtMillis: midnight + day.endMinute * 60000)
            ]
          : <DatedCoachWindow>[];
      return CoachAvailabilityDay(
          localDate: date,
          revision: _state.revisions[key] ?? 1,
          editable: date.compareTo(today) > 0 && date.compareTo(through) <= 0,
          reviewRequired: false,
          windows: _state.overrides[key] ?? windows,
          boundaries: List.generate(
              49,
              (j) => CoachTimeBoundary(
                  atMillis: midnight + j * 1800000, label: _label(j * 30))));
    });
    return CoachAvailabilityContext(
        coachId: coachId,
        serverNowMillis: DateTime.now().millisecondsSinceEpoch,
        timeZone: 'Asia/Kuala_Lumpur',
        todayLocalDate: today,
        policyVersion: 'v1',
        rosterRevision: _state.rosterRevision,
        writableFromLocalDate: _date(now.add(const Duration(days: 1))),
        writableThroughLocalDate: through,
        assignedBranchIds: const ['main'],
        days: days);
  }

  @override
  Future<CoachAvailabilitySaveResult> save(
      {required CoachAvailabilityDay baseline,
      required CoachAvailabilityContext context,
      required List<DatedCoachWindow> windows,
      required String requestId}) async {
    final key = '${context.coachId}:${baseline.localDate}';
    _state.overrides[key] = List.unmodifiable(windows);
    final revision = (_state.revisions[key] ?? baseline.revision ?? 1) + 1;
    _state.revisions[key] = revision;
    return CoachAvailabilitySaveResult(
        coachId: context.coachId,
        localDate: baseline.localDate,
        revision: revision,
        requestId: requestId,
        outcome: 'saved');
  }
}

class _MockAvailabilityState {
  int rosterRevision = 1;
  CoachWeeklyAvailability? weekly;
  final overrides = <String, List<DatedCoachWindow>>{};
  final revisions = <String, int>{};
}
