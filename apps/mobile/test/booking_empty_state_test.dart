import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/widgets/booking_selection_page.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/book_session_screen.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'live_booking_cubit_test.dart' show Writer;

class DailyOptions implements MemberBookingOptionsRepository {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'org');
  @override
  Future<BookingOptionsContext> load(
          {required String coachId,
          String? localDate,
          required int durationMinutes}) async =>
      BookingOptionsContext.fromJson({
        'schemaVersion': 1,
        'coachId': coachId,
        'durationMinutes': durationMinutes,
        'serverNowMillis': 1791936000000,
        'todayLocalDate': '2026-10-14',
        'localDate': localDate ?? '2026-10-14',
        'timeZone': 'Asia/Kuala_Lumpur',
        'throughLocalDate': '2026-11-13',
        'permittedBranchIds': ['branch'],
        'options': [],
        'unavailableReason': 'daily_limit',
      });
}

void main() {
  testWidgets(
      'daily-limit response explains active bookings and links to My bookings',
      (tester) async {
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
        home: BookSessionScreen(
            options: DailyOptions(),
            writer: Writer(),
            coachId: 'coach',
            isCurrent: () => true,
            onOpenBookings: () => opened++)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Daily booking limit reached for 2026-10-14'),
        findsOneWidget);
    expect(find.textContaining('active unpaid hold'), findsOneWidget);
    await tester.ensureVisible(find.text('View My bookings'));
    await tester.tap(find.text('View My bookings'));
    expect(opened, 1);
  });
  testWidgets('empty slots provide visible guidance instead of a dash',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: BookingSelectionPage(days: [], times: [], details: [])));
    expect(
        find.text('No available times. Choose another date.'), findsOneWidget);
  });
}
