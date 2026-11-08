import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show PersistedBookingRecord;
import 'package:gainpath_mobile/features/coaching/presentation/coach/roster_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/live_booking_list_view.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/persisted_booking_presentation.dart';
import 'member_booking_refresh_test.dart' show WatchedRangeBookings;
import 'booking_history_coach_fix_test.dart' show bookingJson;
import 'member_coach_ux_test.dart' show shell;

void main() {
  testWidgets(
      'Coach roster is manual refresh without sync subscription or technical header',
      (t) async {
    final repo = WatchedRangeBookings();
    await t.pumpWidget(shell(LiveBookingListView(
        repository: repo, isCurrent: () => true, coachId: 'coach')));
    await t.pumpAndSettle();
    expect(repo.events.hasListener, false);
    expect(find.textContaining('Auto-syncs'), findsNothing);
    expect(find.textContaining('loaded session'), findsNothing);
    await t.pump(const Duration(seconds: 61));
    await t.pumpAndSettle();
    expect(repo.calls.length, 1);
    await t.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
    await t.pumpAndSettle();
    expect(repo.calls.length, 2);
    await t.pumpWidget(const SizedBox());
    await repo.events.close();
  });
  testWidgets('summary cards show their own local date and start/end times',
      (t) async {
    final record = PersistedBookingRecord.fromJson(bookingJson(
        'summary', DateTime.utc(2026, 11, 1, 2, 30),
        status: 'completed'));
    await t.pumpWidget(shell(CoachRosterScreen(
        historyRange: true,
        persistedBookings: [persistedBookingPresentation(record)],
        recordFor: (_) => record,
        onNotes: (_) {},
        todayLocalDate: '2026-11-08',
        serverNowMillis: DateTime.utc(2026, 11, 8).millisecondsSinceEpoch)));
    await t.pumpAndSettle();
    expect(find.text('1 Nov 2026'), findsOneWidget);
    expect(find.text('10:30 GMT+8 – 11:00 GMT+8'), findsOneWidget);
    expect(find.text('View notes'), findsOneWidget);
    expect(find.text('Write notes'), findsNothing);
  });
  testWidgets(
      'History tabs and All filter remain reachable after scrolling many cards',
      (t) async {
    final rows = List.generate(
        35,
        (i) => Booking(
            id: 'session-$i',
            coachId: 'coach',
            coachName: 'Coach',
            memberName: 'Member $i',
            branch: 'Main Branch',
            start: DateTime(2026, 10, 10).add(Duration(hours: i)),
            durationMin: 30,
            status: BookingStatus.completed,
            fee: 100));
    await t.pumpWidget(shell(CoachRosterScreen(
        historyRange: true,
        persistedBookings: rows,
        todayLocalDate: '2026-11-08',
        serverNowMillis: DateTime.utc(2026, 11, 8).millisecondsSinceEpoch)));
    await t.pumpAndSettle();
    await t.drag(find.byType(ListView).first, const Offset(0, -1800));
    await t.pumpAndSettle();
    expect(
        find.widgetWithText(FilterChip, 'All').hitTestable(), findsOneWidget);
    expect(find.text('Schedule').hitTestable(), findsOneWidget);
    await t.tap(find.widgetWithText(FilterChip, 'Completed').hitTestable());
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilterChip, 'All').hitTestable());
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
