import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_mobile/features/coaching/presentation/coach/coach_time_exception_sheet.dart';
import 'support/coach_availability_fake.dart';

class SameDayBreakFake extends AvailabilityFake {
  @override
  CoachAvailabilityContext context(String id) => CoachAvailabilityContext(
      coachId: id,
      serverNowMillis: 1792116000000,
      todayLocalDate: '2026-10-16',
      timeZone: 'Asia/Kuala_Lumpur',
      policyVersion: 'booking-v1',
      assignedBranchIds: ['main'],
      writableFromLocalDate: '2026-10-17',
      writableThroughLocalDate: '2026-10-17',
      days: [
        CoachAvailabilityDay(
            localDate: '2026-10-16',
            editable: false,
            windows: [],
            boundaries: const [
              CoachTimeBoundary(atMillis: 1792114200000, label: '09:30 GMT+8'),
              CoachTimeBoundary(atMillis: 1792116000000, label: '10:00 GMT+8'),
              CoachTimeBoundary(atMillis: 1792117800000, label: '10:30 GMT+8'),
              CoachTimeBoundary(atMillis: 1792119600000, label: '11:00 GMT+8'),
            ])
      ]);
}

void main() {
  testWidgets(
      'today future break uses server time even when dated overrides are read only',
      (tester) async {
    final repo = SameDayBreakFake();
    final roster = CoachRosterSnapshot(
        coachId: 'coach',
        revision: 0,
        serverNowMillis: 1792116000000,
        todayLocalDate: '2026-10-16',
        timeZone: 'Asia/Kuala_Lumpur',
        policyVersion: 'booking-v1',
        throughLocalDate: '2026-10-16',
        assignedBranchIds: ['main'],
        exceptions: []);
    CoachTimeException? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async {
                      result = await showModalBottomSheet<CoachTimeException>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => CoachTimeExceptionSheet(
                              repository: repo,
                              roster: roster,
                              isCurrent: () => true));
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('10:30 GMT+8'), findsOneWidget);
    expect(find.text('09:30 GMT+8'), findsNothing);
    expect(find.text('10:00 GMT+8'), findsNothing);
    final fullDay = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(fullDay.onChanged, isNull);
    expect(fullDay.value, isFalse);
    await tester.ensureVisible(find.text('Apply blocked time'));
    await tester.tap(find.text('Apply blocked time'));
    await tester.pumpAndSettle();
    expect(result!.startAtMillis, 1792117800000);
    expect(result!.endAtMillis, 1792119600000);
    expect(result!.type, 'breakTime');
  });
}
