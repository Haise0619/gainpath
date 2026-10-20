import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_mobile/features/coaching/presentation/coach/mock_availability_repository_adapter.dart';

class LegacyAvailability implements AvailabilityRepository {
  @override
  final workingDays = List.generate(
      7,
      (i) => WorkingDay('$i', const LocalTime(hour: 9, minute: 0),
          const LocalTime(hour: 17, minute: 0), true));
  @override
  final blockedSlots = <BlockedSlot>[];
  @override
  int dailyBookingCap = 8;
  @override
  int advanceBookingDays = 14;
}

void main() {
  test(
      'weekly save returns saved fields and preserves exact exception instants',
      () async {
    final legacy = LegacyAvailability();
    final adapter = MockAvailabilityRepositoryAdapter(legacy);
    final baseline = await adapter.loadRoster(coachId: 'coach');
    final weekly = CoachWeeklyAvailability(
        dailyCapacityHours: 6,
        advanceBookingWindowDays: 21,
        schedule: List.generate(
            7,
            (i) => CoachWeeklyDay(
                dayOfWeek: i + 1,
                isActive: i < 4,
                startMinute: 600,
                endMinute: 1080,
                branchId: 'main')));
    final start =
        DateTime.parse('2026-10-23T09:30:00+08:00').millisecondsSinceEpoch;
    final end =
        DateTime.parse('2026-10-24T11:00:00+08:00').millisecondsSinceEpoch;
    final exception = CoachTimeException(
        id: 'leave1',
        type: 'leave',
        reason: 'Leave',
        startAtMillis: start,
        endAtMillis: end,
        startLabel: '09:30',
        endLabel: '11:00');
    final saved = await adapter.saveRoster(
        baseline: baseline,
        weeklyAvailability: weekly,
        exceptions: [exception],
        requestId: 'roster1');
    expect(saved.weeklyAvailability!.dailyCapacityHours, 6);
    expect(saved.weeklyAvailability!.schedule.first.startMinute, 600);
    final readback = await MockAvailabilityRepositoryAdapter(legacy)
        .loadRoster(coachId: 'coach');
    expect(readback.exceptions.single.startAtMillis, start);
    expect(readback.exceptions.single.endAtMillis, end);
  });

  test('date overrides including empty days survive adapter recreation',
      () async {
    final legacy = LegacyAvailability();
    final adapter = MockAvailabilityRepositoryAdapter(legacy);
    final context = await adapter.load(
        coachId: 'coach', firstLocalDate: '2026-10-23', dayCount: 2);
    final window = DatedCoachWindow(
        branchId: 'main',
        startAtMillis:
            DateTime.parse('2026-10-23T12:00:00+08:00').millisecondsSinceEpoch,
        endAtMillis:
            DateTime.parse('2026-10-23T13:00:00+08:00').millisecondsSinceEpoch);
    await adapter.save(
        baseline: context.days.first,
        context: context,
        windows: [window],
        requestId: 'day1');
    await adapter.save(
        baseline: context.days.last,
        context: context,
        windows: [],
        requestId: 'day2');
    final readback = await MockAvailabilityRepositoryAdapter(legacy)
        .load(coachId: 'coach', firstLocalDate: '2026-10-23', dayCount: 2);
    expect(readback.days.first.windows.single.toJson(), window.toJson());
    expect(readback.days.last.windows, isEmpty);
  });

  test('weekly windows and boundaries use Kuala Lumpur wall time', () async {
    final context =
        await MockAvailabilityRepositoryAdapter(LegacyAvailability())
            .load(coachId: 'coach', firstLocalDate: '2026-10-23', dayCount: 1);
    final day = context.days.single;
    expect(day.windows.single.startAtMillis,
        DateTime.parse('2026-10-23T09:00:00+08:00').millisecondsSinceEpoch);
    expect(day.boundaries.length, 49);
    expect(day.boundaries.first.label, '00:00');
    expect(day.boundaries.last.label, '24:00');
    expect(day.boundaries.every((b) => b.atMillis % 1800000 == 0), isTrue);
    expect(context.timeZone, 'Asia/Kuala_Lumpur');
  });
}
