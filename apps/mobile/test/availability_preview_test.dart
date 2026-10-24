import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_mobile/features/coaching/presentation/coach/availability_preview.dart';

void main() {
  final start =
      DateTime.parse('2026-10-22T00:00:00+08:00').millisecondsSinceEpoch;
  CoachAvailabilityDay day(int revision) => CoachAvailabilityDay(
      localDate: '2026-10-22',
      revision: revision,
      windows: [
        DatedCoachWindow(
            branchId: 'main',
            startAtMillis: start + 9 * 3600000,
            endAtMillis: start + 17 * 3600000)
      ],
      boundaries: List.generate(
          49,
          (i) => CoachTimeBoundary(
              atMillis: start + i * 1800000,
              label:
                  '${(i ~/ 2 % 24).toString().padLeft(2, '0')}:${i.isEven ? '00' : '30'} GMT+8')));
  const changed = CoachWeeklyDay(
      dayOfWeek: 4,
      isActive: true,
      startMinute: 600,
      endMinute: 960,
      branchId: 'main');
  test(
      'weekly draft immediately changes ordinary date preview without a network request',
      () {
    final windows = previewScheduledWindows(
        day: day(0), weeklyDay: changed, weeklyChanged: true);
    expect(windows.single.startAtMillis, start + 10 * 3600000);
    expect(windows.single.endAtMillis, start + 16 * 3600000);
  });
  test('saved custom dates keep their own hours when the weekly draft changes',
      () {
    final windows = previewScheduledWindows(
        day: day(2), weeklyDay: changed, weeklyChanged: true);
    expect(windows.single.startAtMillis, start + 9 * 3600000);
    expect(windows.single.endAtMillis, start + 17 * 3600000);
  });
}
