import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
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
            persistedBookings: [sampleUpcoming, sampleCompleted, sampleCancelled],
            embedded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Main tabs are visible with counts: Upcoming (1), History (2)
      expect(find.widgetWithText(InkWell, 'Upcoming'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'History'), findsOneWidget);
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
            persistedBookings: [sampleUpcoming, sampleCompleted, sampleCancelled],
            embedded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to History tab
      await tester.tap(find.widgetWithText(InkWell, 'History'));
      await tester.pumpAndSettle();

      // Upcoming is hidden
      expect(find.text('UPCOMING'), findsNothing);
      expect(find.text('Sarah Jenkins'), findsNothing);

      // Sub-filters are visible
      expect(find.widgetWithText(InkWell, 'All'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Completed'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Cancelled'), findsOneWidget);

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
            persistedBookings: [sampleUpcoming, sampleCompleted, sampleCancelled],
            embedded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(InkWell, 'History'));
      await tester.pumpAndSettle();

      // Tap on Completed sub-filter
      await tester.tap(find.widgetWithText(InkWell, 'Completed'));
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
            persistedBookings: [sampleUpcoming, sampleCompleted, sampleCancelled],
            embedded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(InkWell, 'History'));
      await tester.pumpAndSettle();

      // Tap on Cancelled sub-filter
      await tester.tap(find.widgetWithText(InkWell, 'Cancelled'));
      await tester.pumpAndSettle();

      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.text('Elena Rostova'), findsOneWidget);
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
          'You have no scheduled sessions. Connect with a top coach to plan your next workout.',
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
      await tester.tap(find.widgetWithText(InkWell, 'History'));
      await tester.pumpAndSettle();

      expect(find.text('No session history'), findsOneWidget);
      expect(find.text('No upcoming sessions'), findsNothing);
    });

    testWidgets(
        'BookingCard renders avatar initials, session type and View details sheet',
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

      // Open View Details sheet
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();

      expect(find.text('Session Details'), findsOneWidget);
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
            persistedBookings: [sampleUpcoming, sampleCompleted, sampleCancelled],
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
      await tester.tap(find.widgetWithText(InkWell, 'History'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
