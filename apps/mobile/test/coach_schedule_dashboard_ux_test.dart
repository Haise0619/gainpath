import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart' as domain;
import 'package:gainpath_mobile/features/coaching/presentation/coach/coach_session_details_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/coach/roster_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize =
        const Size(1000, 1800);
    binding.platformDispatcher.views.first.devicePixelRatio = 1;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  final today = DateTime.now();
  final y = today.year.toString().padLeft(4, '0');
  final m = today.month.toString().padLeft(2, '0');
  final d = today.day.toString().padLeft(2, '0');
  final todayStr = '$y-$m-$d';

  final baseSlot = (today.millisecondsSinceEpoch ~/ 1800000) * 1800000;
  final futureStart = baseSlot + 1800000 * 2;
  final futureEnd = futureStart + 3600000;

  final pastStart = baseSlot - 1800000 * 4;
  final pastEnd = pastStart + 3600000;

  final futureHoldExpiry = futureStart - 1800000;
  final futureCreatedAt = futureHoldExpiry - 60000;

  final pastHoldExpiry = pastStart - 1800000;
  final pastCreatedAt = pastHoldExpiry - 60000;

  final bookingFuture = Booking(
    id: 'bk-future-1',
    coachId: 'coach-1',
    coachName: 'Coach John',
    memberName: 'David Miller',
    branch: 'Downtown Branch',
    start: DateTime.fromMillisecondsSinceEpoch(futureStart),
    durationMin: 60,
    fee: 120.0,
    status: BookingStatus.confirmed,
  );

  final bookingPastNeedsNotes = Booking(
    id: 'bk-past-1',
    coachId: 'coach-1',
    coachName: 'Coach John',
    memberName: 'Sarah Connor',
    branch: 'Mid Valley Branch',
    start: DateTime.fromMillisecondsSinceEpoch(pastStart),
    durationMin: 60,
    fee: 90.0,
    status: BookingStatus.confirmed, // ended confirmed session without notes
    notes: null,
  );

  final recordFuture = domain.PersistedBookingRecord(
    bookingId: 'bk-future-1',
    organizationId: 'org-1',
    memberId: 'member-1',
    coachId: 'coach-1',
    branchId: 'branch-1',
    requestId: 'req-f',
    startAtMillis: futureStart,
    endAtMillis: futureEnd,
    durationMinutes: 60,
    status: domain.BookingStatus.confirmed,
    holdExpiresAtMillis: futureHoldExpiry,
    localDate: todayStr,
    timeZone: 'Asia/Kuala_Lumpur',
    policyVersion: '1',
    createdAtMillis: futureCreatedAt,
    startLabel: '14:00',
    endLabel: '15:00',
    expiryLabel: '13:30',
    memberDisplayName: 'David Miller',
  );

  final recordPast = domain.PersistedBookingRecord(
    bookingId: 'bk-past-1',
    organizationId: 'org-1',
    memberId: 'member-2',
    coachId: 'coach-1',
    branchId: 'branch-2',
    requestId: 'req-p',
    startAtMillis: pastStart,
    endAtMillis: pastEnd,
    durationMinutes: 60,
    status: domain.BookingStatus.confirmed,
    holdExpiresAtMillis: pastHoldExpiry,
    localDate: todayStr,
    timeZone: 'Asia/Kuala_Lumpur',
    policyVersion: '1',
    createdAtMillis: pastCreatedAt,
    startLabel: '10:00',
    endLabel: '11:00',
    expiryLabel: '09:30',
    memberDisplayName: 'Sarah Connor',
  );

  Widget createTestWidget({
    List<Booking>? bookings,
    Map<String, domain.PersistedBookingRecord>? records,
    void Function(Booking)? onMessage,
    void Function(Booking)? onNotes,
    void Function(Booking)? onCancel,
    VoidCallback? onOpenMessages,
    void Function(bool)? onRangeChanged,
    bool? historyRange,
    Size size = const Size(1000, 1800),
    double textScale = 1.0,
  }) {
    final list = bookings ?? [bookingFuture, bookingPastNeedsNotes];
    final map = records ??
        {
          'bk-future-1': recordFuture,
          'bk-past-1': recordPast,
        };

    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: CoachRosterScreen(
            persistedBookings: list,
            recordFor: (id) => map[id],
            todayLocalDate: todayStr,
            serverNowMillis: today.millisecondsSinceEpoch,
            onMessage: onMessage,
            onNotes: onNotes,
            onCancel: onCancel,
            onOpenMessages: onOpenMessages,
            onRangeChanged: onRangeChanged,
            historyRange: historyRange,
          ),
        ),
      ),
    );
  }

  testWidgets(
      'Coach Roster displays modern Dashboard layout with summary, next session & attention alerts',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var messagesOpened = false;
    var notesTarget = '';

    await tester.pumpWidget(createTestWidget(
      onOpenMessages: () => messagesOpened = true,
      onNotes: (b) => notesTarget = b.id,
    ));
    await tester.pumpAndSettle();

    // 1. Header checks
    expect(find.text('My schedule'), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsWidgets);

    // Tap message inbox in header
    final inboxButton = find.widgetWithIcon(IconButton, Icons.chat_bubble_outline_rounded).first;
    await tester.tap(inboxButton);
    expect(messagesOpened, isTrue);

    // 2. Main tabs
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    // 3. Daily summary
    expect(find.text('Scheduled'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Notes Due'), findsOneWidget);
    expect(find.text('1'), findsWidgets); // 1 notes due

    // 4. Needs Attention section
    expect(find.text('1 session needs consultation notes'), findsOneWidget);
    final writeButton = find.widgetWithText(TextButton, 'Write');
    expect(writeButton, findsOneWidget);
    await tester.tap(writeButton);
    expect(notesTarget, 'bk-past-1');

    // 5. Next session highlight card
    expect(find.text('NEXT UP'), findsOneWidget);
    expect(find.text('with David Miller'), findsOneWidget);

    // 6. Appointments list
    expect(find.text('Appointments'), findsOneWidget);
    expect(find.text('David Miller'), findsOneWidget);
    expect(find.text('Sarah Connor'), findsOneWidget);
  });

  testWidgets('Search control toggles and filters appointment list',
      (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Tap search icon to open field
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);

    // Enter search term
    await tester.enterText(find.byType(TextField), 'David');
    await tester.pumpAndSettle();

    expect(find.text('David Miller'), findsWidgets);
    expect(find.text('Sarah Connor'), findsNothing);

    // Close search
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('David Miller'), findsWidgets);
    expect(find.text('Sarah Connor'), findsWidgets);
  });

  testWidgets('Filter bottom sheet configures Status and Date Scope without resetting dates',
      (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Tap filter icon
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Filter Schedule'), findsOneWidget);
    expect(find.text('DATE SCOPE'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);

    // Select 'This Week' and 'Confirmed'
    await tester.tap(find.widgetWithText(ChoiceChip, 'This Week'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Confirmed'));
    await tester.pumpAndSettle();

    // Tap Apply Filters
    await tester.tap(find.widgetWithText(ElevatedButton, 'Apply Filters'));
    await tester.pumpAndSettle();

    // Filter badge should show '2'
    expect(find.text('2'), findsWidgets);
    expect(find.text('Appointments (This Week)'), findsOneWidget);
  });

  testWidgets('History tab allows filtering past sessions by status chips',
      (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Tap History tab
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('All'), findsWidgets);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Cancelled'), findsWidgets);
    expect(find.text('Expired'), findsWidgets);

    // Sarah Connor is past/ended, so appears in History
    expect(find.text('Sarah Connor'), findsOneWidget);

    // Filter to Cancelled -> empty state
    await tester.tap(find.widgetWithText(FilterChip, 'Cancelled'));
    await tester.pumpAndSettle();

    expect(find.text('No past sessions'), findsOneWidget);
    expect(find.text('Return to Schedule'), findsOneWidget);
  });

  testWidgets(
      'Switching between Schedule and History triggers onRangeChanged and eliminates conflicting date toggle',
      (tester) async {
    bool? requestedHistory;
    await tester.pumpWidget(createTestWidget(
      onRangeChanged: (showHistory) => requestedHistory = showHistory,
    ));
    await tester.pumpAndSettle();

    // Verify neither the redundant date toggle pill nor the refresh icon button exist
    expect(find.byTooltip('Refresh bookings'), findsNothing);
    expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);

    // Tap History -> triggers onRangeChanged(true)
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(requestedHistory, isTrue);

    // Tap Schedule -> triggers onRangeChanged(false)
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    expect(requestedHistory, isFalse);
  });

  testWidgets('Card tap navigates to dedicated CoachSessionDetailsScreen with 9 sections',
      (tester) async {
    await tester.pumpWidget(createTestWidget(
      onCancel: (b) {},
      onMessage: (b) {},
    ));
    await tester.pumpAndSettle();

    // Find the appointment card for David Miller and tap it
    final card = find.widgetWithText(InkWell, 'David Miller').first;
    await tester.tap(card);
    await tester.pumpAndSettle();

    // Verify CoachSessionDetailsScreen opened
    expect(find.byType(CoachSessionDetailsScreen), findsOneWidget);
    expect(find.text('Session details'), findsOneWidget);

    // Section 1: Overview
    expect(find.text('1-on-1 Coaching Consultation'), findsOneWidget);
    expect(find.text('Confirmed'), findsWidgets);

    // Section 2: Member Info & Stats
    expect(find.text('MEMBER INFORMATION'), findsOneWidget);
    expect(find.text('Together'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);

    // Section 3: Date, Time & Location
    expect(find.text('DATE, TIME & LOCATION'), findsOneWidget);
    expect(find.text('Location confirmed when booking'), findsWidgets);

    // Section 4: Status
    expect(find.text('BOOKING STATUS'), findsOneWidget);

    // Section 5: Payment
    expect(find.text('PAYMENT INFORMATION'), findsOneWidget);
    expect(find.text('RM 120.00'), findsOneWidget);

    // Section 6: Consultation Notes
    expect(find.text('CONSULTATION NOTES'), findsOneWidget);

    // Section 7: Form History
    expect(find.text('FORM HISTORY & MEASUREMENTS'), findsOneWidget);
    expect(find.text('View Form History'), findsOneWidget);

    // Section 8: Management Actions (Cancel session)
    expect(find.text('BOOKING MANAGEMENT'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Cancel Session'), findsOneWidget);

    // Section 9: Reference (collapsible)
    await tester.scrollUntilVisible(find.text('BOOKING REFERENCE'), 200);
    expect(find.text('BOOKING REFERENCE'), findsOneWidget);

    // Expand reference
    await tester.tap(find.text('BOOKING REFERENCE'));
    await tester.pumpAndSettle();
    expect(find.text('bk-future-1'), findsWidgets);
  });

  testWidgets('Responsive at 320px width and 200% text scale without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(createTestWidget(
      size: const Size(320, 640),
      textScale: 2.0,
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('My schedule'), findsOneWidget);
  });
}
