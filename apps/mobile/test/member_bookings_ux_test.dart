import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart' as domain;
import 'package:gainpath_mobile/features/coaching/presentation/member/booking_details_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/booking_schedule_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/widgets/booking_card.dart';

Widget _testShell(Widget child, {double width = 360, double scale = 1.0}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: TextScaler.linear(scale),
      ),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  final sampleUpcoming = Booking(
    id: 'bk-upcoming',
    coachId: 'c1',
    coachName: 'Sarah Jenkins',
    memberName: 'Alex',
    start: DateTime(2026, 11, 10, 10, 0),
    branch: 'Mid Valley',
    status: BookingStatus.confirmed,
    durationMin: 60,
    fee: 120.0,
  );

  final sampleCompleted = Booking(
    id: 'bk-completed',
    coachId: 'c2',
    coachName: 'Marcus Vance',
    memberName: 'Alex',
    start: DateTime(2026, 11, 1, 14, 30),
    branch: 'Bangsar',
    status: BookingStatus.completed,
    durationMin: 45,
    fee: 100.0,
  );

  final sampleCancelled = Booking(
    id: 'bk-cancelled',
    coachId: 'c3',
    coachName: 'Elena Rostova',
    memberName: 'Alex',
    start: DateTime(2026, 10, 25, 9, 0),
    branch: 'KLCC',
    status: BookingStatus.cancelled,
    durationMin: 30,
    fee: 150.0,
    cancellationReason: 'Schedule conflict with work.',
  );

  group('BookingScheduleScreen UI/UX optimizations', () {
    testWidgets(
        'renders main tabs (Upcoming, History) with counts and shows upcoming bookings by default',
        (tester) async {
      await tester.pumpWidget(
        _testShell(
          BookingScheduleScreen(
            persistedBookings: [
              sampleUpcoming,
              sampleCompleted,
              sampleCancelled
            ],
            embedded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Main tabs are visible with counts: Upcoming (1), History (2)
      expect(find.widgetWithText(InkWell, 'Upcoming'), findsOneWidget);
      expect(find.byKey(const ValueKey('tab_history')), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);

      // Upcoming tab is active by default
      expect(find.text('UPCOMING'), findsOneWidget);
      expect(find.text('Sarah Jenkins'), findsOneWidget);

      // Completed and Cancelled sessions are hidden on Upcoming tab
      expect(find.text('COMPLETED'), findsNothing);
      expect(find.text('Marcus Vance'), findsNothing);
      expect(find.text('CANCELLED'), findsNothing);
      expect(find.text('Elena Rostova'), findsNothing);
    });

    testWidgets(
        'tapping History tab reveals sub-filters (All, Completed, Cancelled) and shows history',
        (tester) async {
      await tester.pumpWidget(
        _testShell(
          BookingScheduleScreen(
            persistedBookings: [
              sampleUpcoming,
              sampleCompleted,
              sampleCancelled
            ],
            embedded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to History tab
      await tester.ensureVisible(find.byKey(const ValueKey('tab_history')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab_history')));
      await tester.pumpAndSettle();

      // Upcoming is hidden
      expect(find.text('UPCOMING'), findsNothing);
      expect(find.text('Sarah Jenkins'), findsNothing);

      // Sub-filters are visible
      expect(find.byKey(const ValueKey('filter_all')), findsOneWidget);
      expect(find.byKey(const ValueKey('filter_completed')), findsOneWidget);
      expect(find.byKey(const ValueKey('filter_cancelled')), findsOneWidget);

      // In All mode, both completed and cancelled sessions appear
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('Marcus Vance'), findsOneWidget);
      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.text('Elena Rostova'), findsOneWidget);
    });

    testWidgets('filtering History by Completed shows only completed sessions',
        (tester) async {
      await tester.pumpWidget(
        _testShell(
          BookingScheduleScreen(
            persistedBookings: [
              sampleUpcoming,
              sampleCompleted,
              sampleCancelled
            ],
            embedded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('tab_history')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab_history')));
      await tester.pumpAndSettle();

      // Tap on Completed sub-filter
      await tester.tap(find.byKey(const ValueKey('filter_completed')));
      await tester.pumpAndSettle();

      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('Marcus Vance'), findsOneWidget);

      // Cancelled is filtered out
      expect(find.text('CANCELLED'), findsNothing);
      expect(find.text('Elena Rostova'), findsNothing);
    });

    testWidgets('filtering History by Cancelled shows only cancelled sessions',
        (tester) async {
      await tester.pumpWidget(
        _testShell(
          BookingScheduleScreen(
            persistedBookings: [
              sampleUpcoming,
              sampleCompleted,
              sampleCancelled
            ],
            embedded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('tab_history')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab_history')));
      await tester.pumpAndSettle();

      // Tap on Cancelled sub-filter
      await tester.tap(find.byKey(const ValueKey('filter_cancelled')));
      await tester.pumpAndSettle();

      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.text('Elena Rostova'), findsOneWidget);

      // Open details to view cancellation reason
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Schedule conflict with work.'),
        100,
      );
      expect(find.text('Schedule conflict with work.'), findsOneWidget);

      // Completed is filtered out
      expect(find.text('COMPLETED'), findsNothing);
      expect(find.text('Marcus Vance'), findsNothing);
    });

    testWidgets(
        'empty state displays single relevant card with Find a Coach button',
        (tester) async {
      var findCoachTapped = false;
      await tester.pumpWidget(
        _testShell(
          BookingScheduleScreen(
            persistedBookings: const [],
            embedded: true,
            onFindCoach: () => findCoachTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Single empty state on Upcoming tab
      expect(find.text('No upcoming sessions'), findsOneWidget);
      expect(
        find.text(
          'You have no scheduled sessions. Find a coach to book a consultation.',
        ),
        findsOneWidget,
      );
      expect(find.text('Find a Coach'), findsOneWidget);

      // Repetitive empty cards for completed and cancelled are NOT shown
      expect(find.text('No completed sessions yet.'), findsNothing);
      expect(find.text('No cancelled sessions.'), findsNothing);

      // Tapping Find a Coach triggers the callback
      await tester.tap(find.text('Find a Coach'));
      await tester.pumpAndSettle();
      expect(findCoachTapped, isTrue);

      // Switch to History tab with 0 sessions
      await tester.ensureVisible(find.byKey(const ValueKey('tab_history')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab_history')));
      await tester.pumpAndSettle();

      expect(find.text('No session history'), findsOneWidget);
      expect(find.text('No upcoming sessions'), findsNothing);
    });

    testWidgets(
        'BookingCard renders avatar initials, session type and navigates to BookingDetailsScreen',
        (tester) async {
      await tester.pumpWidget(
        _testShell(
          BookingCard(
            booking: sampleUpcoming,
            live: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial 'S' for Sarah Jenkins
      expect(find.text('S'), findsOneWidget);
      expect(find.text('Sarah Jenkins'), findsOneWidget);
      expect(find.text('1-on-1 Consultation · 60 min'), findsOneWidget);
      expect(find.text('View details'), findsOneWidget);

      // Open View Details screen
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();

      expect(find.text('Booking Details'), findsOneWidget);
      expect(find.text('Mid Valley'), findsWidgets);
      expect(find.text('RM 120.00'), findsOneWidget);
    });

    testWidgets(
        'responsive layout fits 320px width at 200% text scale without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _testShell(
          BookingScheduleScreen(
            persistedBookings: [
              sampleUpcoming,
              sampleCompleted,
              sampleCancelled
            ],
            embedded: true,
          ),
          width: 320,
          scale: 2.0,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Drag to scroll down through the list
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Switch to History tab at 320px 2.0x scale
      await tester.ensureVisible(find.byKey(const ValueKey('tab_history')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab_history')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    test(
        'formatters resolve locations, fees, coach names, and distinct expired status',
        () {
      // Human-readable branch formatting (never raw IDs)
      expect(resolveBranchLocation('branch_internal_42'),
          'Location confirmed when booking');
      expect(resolveBranchLocation('removed-branch'),
          'Location confirmed when booking');
      expect(resolveBranchLocation(''), 'Location confirmed when booking');
      expect(resolveBranchLocation('-'), 'Location confirmed when booking');
      expect(resolveBranchLocation('Mid Valley'), 'Mid Valley');
      expect(
        resolveBranchLocation('branch_internal_42',
            branchNames: {'branch_internal_42': 'Pavilion Bukit Jalil'}),
        'Pavilion Bukit Jalil',
      );

      // Fee resolution (never RM 0 or Free)
      expect(resolveBookingFee(0.0), isNull);
      expect(resolveBookingFee(-10.0), isNull);
      expect(resolveBookingFee(120.0), 'RM 120.00');
      expect(resolveBookingFee(0.0, feeMinor: 0), isNull);
      expect(resolveBookingFee(0.0, feeMinor: 15000), 'RM 150.00');

      // Coach name resolution
      expect(resolveCoachName(''), 'Coach');
      expect(resolveCoachName('-'), 'Coach');
      expect(resolveCoachName('-', fallback: 'Marcus Vance'), 'Marcus Vance');
      expect(resolveCoachName('Sarah Jenkins'), 'Sarah Jenkins');

      // Distinct Expired status from Cancelled
      expect(resolveStatusLabel(BookingStatus.cancelled, rawStatus: 'expired'),
          'Expired');
      expect(
          resolveStatusLabel(BookingStatus.cancelled,
              resolution: 'hold_expired'),
          'Expired');
      expect(
          resolveStatusLabel(BookingStatus.cancelled, labelOverride: 'Expired'),
          'Expired');
      expect(resolveStatusLabel(BookingStatus.cancelled), 'Cancelled');
      expect(resolveStatusLabel(BookingStatus.pending), 'Awaiting payment');
      expect(resolveStatusLabel(BookingStatus.confirmed), 'Confirmed');
      expect(resolveStatusLabel(BookingStatus.completed), 'Completed');
    });

    testWidgets(
        'BookingCard hides zero/missing price and resolves raw branch IDs cleanly',
        (tester) async {
      final unpricedBooking = Booking(
        id: 'bk-unpriced',
        coachId: 'c9',
        coachName: '-',
        memberName: 'Alex',
        start: DateTime(2026, 11, 15, 11, 0),
        branch: 'branch_internal_42',
        status: BookingStatus.confirmed,
        durationMin: 45,
        fee: 0.0,
      );

      await tester.pumpWidget(
        _testShell(
          BookingCard(
            booking: unpricedBooking,
            live: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Coach name falls back to "Coach"
      expect(find.text('Coach'), findsOneWidget);
      // Raw branch ID is converted to human-readable
      expect(find.text('branch_internal_42'), findsNothing);
      expect(find.textContaining('Location confirmed when booking'),
          findsOneWidget);
      // Missing/zero price is NOT displayed (never RM 0.00 or Free)
      expect(find.text('RM 0.00'), findsNothing);
      expect(find.text('Free'), findsNothing);
    });

    testWidgets(
        'Tapping entire BookingCard navigates to BookingDetailsScreen with all 6 sections',
        (tester) async {
      await tester.pumpWidget(
        _testShell(
          BookingCard(
            booking: sampleUpcoming,
            live: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap anywhere on the card
      await tester.tap(find.byType(BookingCard));
      await tester.pumpAndSettle();

      // Verify top sections & details
      expect(find.text('Booking Details'), findsOneWidget);
      expect(find.text('BOOKING OVERVIEW'), findsOneWidget);
      expect(find.text('COACH & LOCATION'), findsOneWidget);
      expect(find.text('PAYMENT DETAILS'), findsOneWidget);
      expect(find.text('Sarah Jenkins'), findsOneWidget);
      expect(find.text('RM 120.00'), findsOneWidget);

      // Verify lower sections by scrolling through ListView
      await tester.scrollUntilVisible(find.text('BOOKING MANAGEMENT'), 100);
      expect(find.text('BOOKING MANAGEMENT'), findsOneWidget);

      // No conversation, notes or review destination was supplied.
      expect(find.text('SESSION ACTIVITY'), findsNothing);

      await tester.scrollUntilVisible(find.text('BOOKING REFERENCE'), 100);
      expect(find.text('BOOKING REFERENCE'), findsOneWidget);
    });

    testWidgets(
        'BookingDetailsScreen collapsible Booking Reference expands and allows copying ID',
        (tester) async {
      final testRecord = domain.PersistedBookingRecord(
        bookingId: 'bk-upcoming',
        organizationId: 'org-1',
        memberId: 'mem-1',
        coachId: 'c1',
        branchId: 'branch-1',
        requestId: 'req-abc-123',
        startAtMillis: 1762740000000,
        endAtMillis: 1762740000000 + 3600000,
        durationMinutes: 60,
        status: domain.BookingStatus.confirmed,
        holdExpiresAtMillis: 1762740000000 - 1800000,
        localDate: '2026-11-10',
        timeZone: 'Asia/Kuala_Lumpur',
        policyVersion: 'v2.1',
        createdAtMillis: 1762740000000 - 3600000,
        startLabel: '10:00',
        endLabel: '11:00',
        expiryLabel: '09:30',
        feeMinor: 12000,
      );

      await tester.pumpWidget(
        _testShell(
          BookingDetailsScreen(
            booking: sampleUpcoming,
            record: testRecord,
            live: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to Booking Reference section and ensure fully visible
      await tester.scrollUntilVisible(
        find.text('Technical Details & Identifiers'),
        100,
      );
      await tester.ensureVisible(find.text('Technical Details & Identifiers'));
      await tester.pumpAndSettle();

      // Initially, collapsible tile shows subtitle with truncated ID
      expect(find.text('Technical Details & Identifiers'), findsOneWidget);
      expect(find.text('ID: bk-upcoming'), findsOneWidget);

      // Tap to expand
      await tester.tap(find.text('Technical Details & Identifiers'));
      await tester.pumpAndSettle();

      // Scroll to reveal the expanded details
      await tester.scrollUntilVisible(find.text('Request ID'), 100);
      expect(find.text('Request ID'), findsOneWidget);
      expect(find.text('req-abc-123'), findsOneWidget);
      expect(find.text('Policy Version'), findsOneWidget);
      expect(find.text('v2.1'), findsOneWidget);
      expect(find.text('Timezone'), findsOneWidget);
      expect(find.text('Asia/Kuala_Lumpur'), findsOneWidget);

      // Copy button is present and pressable
      final copyButton = find.byTooltip('Copy ID');
      expect(copyButton, findsOneWidget);
      await tester.ensureVisible(copyButton);
      await tester.pumpAndSettle();
      await tester.tap(copyButton);
      await tester.pumpAndSettle();
    });

    testWidgets(
        'BookingDetailsScreen is responsive at 320px width and 200% text scale without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _testShell(
          BookingDetailsScreen(
            booking: sampleCancelled,
            live: true,
          ),
          width: 320,
          scale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      Object? err = tester.takeException();
      if (err != null) {
        // ignore: avoid_print
        print('OVERFLOW ERROR: $err');
      }
      expect(err, isNull);

      // Drag to scroll down through all sections
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      err = tester.takeException();
      if (err != null) {
        // ignore: avoid_print
        print('OVERFLOW ERROR: $err');
      }
      expect(err, isNull);
    });
  });
}
