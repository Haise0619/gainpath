import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_mobile/features/coaching/presentation/coach/availability_screens.dart';
import 'support/availability_dashboard_fixture.dart';

void main() {
  testWidgets('Availability displays compact date range, daily booking cap, and no redundant edit button',
      (tester) async {
    final repo = DashboardRosterFake();
    await tester.pumpWidget(MaterialApp(
      home: AvailabilityScreen(
        liveRepository: repo,
        coachId: 'coach',
        isCurrent: () => true,
        loadBranchNames: () async => {'main': 'GainPath Main'},
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Compact date range navigation header (e.g. 8–14 Nov 2026) without timezone string
    expect(find.text('8–14 Nov 2026'), findsOneWidget);
    expect(find.textContaining('Asia/Kuala_Lumpur'), findsNothing);

    // 2. Selected Day Overview:
    // - Daily booking cap: 8h (accurate format)
    expect(find.text('Daily booking cap: 8h'), findsOneWidget);
    expect(find.textContaining('booked hours total'), findsNothing);

    // - Working hours clarification note
    expect(
        find.text(
            'Working hours define duty schedule, not remaining bookable slots.'),
        findsOneWidget);

    // - Actions: Change This Date & Add Time Off are present
    expect(find.text('Change This Date'), findsOneWidget);
    expect(find.text('Add Time Off'), findsWidgets);

    // - Redundant "Edit Weekly Hours" button inside selected day card is removed
    expect(find.text('Edit Weekly Hours'), findsNothing);

    // 3. Weekly Working Hours:
    // - Weekday rows display title and subtitle compactly with switch and edit button
    expect(find.text('Monday'), findsOneWidget);
    expect(find.textContaining('09:00 – 17:00 · GainPath Main'), findsWidgets);
    expect(find.byKey(const ValueKey('weekly-day-1')), findsOneWidget);
  });

  testWidgets('Time off summary formats singular 1 blocked period accurately',
      (tester) async {
    final repo = DashboardRosterFake()
      ..exceptions = [
        CoachTimeException(
          id: 'ex-1',
          type: 'breakTime',
          reason: 'Lunch break',
          startAtMillis: DashboardRosterFake.now + 3600000,
          endAtMillis: DashboardRosterFake.now + 7200000,
        ),
      ];

    await tester.pumpWidget(MaterialApp(
      home: AvailabilityScreen(
        liveRepository: repo,
        coachId: 'coach',
        isCurrent: () => true,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('availability-time-off')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Verify singular form in Quick Settings subtitle and Tooltip
    expect(find.text('1 blocked period'), findsOneWidget);
    expect(find.text('1 blocked periods'), findsNothing);
  });

  testWidgets('Responsive at 320px width and 200% text scale without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = DashboardRosterFake();
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2.0),
        ),
        child: AvailabilityScreen(
          liveRepository: repo,
          coachId: 'coach',
          isCurrent: () => true,
          loadBranchNames: () async => {'main': 'GainPath Main'},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Availability'), findsOneWidget);
  });
}
