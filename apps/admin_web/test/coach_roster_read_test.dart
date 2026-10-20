import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_admin_web/features/coaching/presentation/admin/coach_schedule_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'coach_availability_read_test.dart' show ScheduleFake;

class _Roster extends ScheduleFake implements CoachRosterRepository {
  _Roster() : super(SessionScope(userId: 'admin', organizationId: 'org'));
  int reads = 0;
  bool fail = false;
  @override
  Future<CoachRosterSnapshot> loadRoster({required String coachId}) async {
    reads++;
    if (fail) throw StateError('private transport detail');
    return CoachRosterSnapshot(
        coachId: coachId,
        revision: 1,
        serverNowMillis: 1,
        todayLocalDate: '2026-10-15',
        throughLocalDate: '2026-11-14',
        timeZone: 'Asia/Kuala_Lumpur',
        policyVersion: 'booking-v1',
        assignedBranchIds: ['main'],
        weeklyAvailability: CoachWeeklyAvailability(
            dailyCapacityHours: 4,
            advanceBookingWindowDays: 14,
            schedule: List.generate(
                7,
                (i) => CoachWeeklyDay(
                    dayOfWeek: i + 1,
                    isActive: i < 5,
                    startMinute: 540,
                    endMinute: 1020,
                    branchId: 'main'))),
        exceptions: [
          const CoachTimeException(
              id: 'block',
              type: 'leave',
              reason: 'Time off',
              startAtMillis: 1800000,
              endAtMillis: 3600000,
              startLabel: '16/10/2026 09:00 GMT+8',
              endLabel: '16/10/2026 10:00 GMT+8')
        ]);
  }

  @override
  Future<CoachRosterSnapshot> saveRoster(
          {required CoachRosterSnapshot baseline,
          required CoachWeeklyAvailability weeklyAvailability,
          required List<CoachTimeException> exceptions,
          required String requestId}) =>
      throw StateError('Admin must never save a Coach roster');
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'Admin reads private hours, reasons and limits with no write controls',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _Roster();
    await tester.pumpWidget(MaterialApp(
        home: AdminCoachScheduleView(
            repository: repository, coachId: 'coach', isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.text('4 hours'), findsOneWidget);
    expect(find.text('14 days'), findsOneWidget);
    expect(find.text('Time off'), findsOneWidget);
    expect(find.text('16/10/2026 09:00 GMT+8 – 16/10/2026 10:00 GMT+8'),
        findsOneWidget);
    expect(find.text('Save roster'), findsNothing);
    expect(find.text('Save day'), findsNothing);
    repository.fail = true;
    await tester.tap(find.byTooltip('Refresh schedule'));
    await tester.pumpAndSettle();
    expect(repository.reads, 2);
    expect(find.text('Roster details unavailable. Refresh to retry.'),
        findsOneWidget);
    expect(find.text('Time off'), findsNothing);
    expect(find.textContaining('private transport'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
