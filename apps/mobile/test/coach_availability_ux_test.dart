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

    // - Actions: "Manage This Day" is the primary unified action
    expect(find.text('Manage This Day'), findsOneWidget);
    expect(find.text('Change This Date'), findsNothing);

    // - Redundant "Edit Weekly Hours" button inside selected day card is removed
    expect(find.text('Edit Weekly Hours'), findsNothing);

    // 3. Weekly Working Hours:
    // - Weekday rows display title and subtitle compactly with switch and edit button
    expect(find.text('Monday'), findsOneWidget);
    expect(find.textContaining('09:00 – 17:00 · GainPath Main'), findsWidgets);
    expect(find.byKey(const ValueKey('weekly-day-1')), findsOneWidget);

    // 4. Header actions: Monthly Calendar icon is present, Refresh button is removed
    expect(find.byKey(const ValueKey('open-monthly-calendar-btn')), findsOneWidget);
    expect(find.byTooltip('Refresh availability'), findsNothing);

    // 5. Date cards display Work and Off status indicators with distinct colors/labels
    expect(find.text('Work'), findsWidgets);
    expect(find.text('Off'), findsWidgets);
  });

  testWidgets('Manage This Day opens Action Bottom Sheet with all 3 management options',
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

    // Tap "Manage This Day"
    await tester.tap(find.text('Manage This Day'));
    await tester.pumpAndSettle();

    // Verify Action Bottom Sheet title and all 3 options
    expect(find.textContaining('Manage'), findsWidgets);
    expect(find.text('Edit Day Hours'), findsOneWidget);
    expect(find.text('Add Time Off / Break'), findsOneWidget);
    expect(find.textContaining('Edit Weekly Schedule'), findsOneWidget);

    // Option 1 opens CoachSpecificDateSheet
    await tester.tap(find.byKey(const ValueKey('open-specific-date-btn')));
    await tester.pumpAndSettle();
    expect(find.text('Save day'), findsOneWidget);
  });

  testWidgets('Monthly Calendar opens, navigates months, shows statuses and synchronizes date',
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
        loadBranchNames: () async => {'main': 'GainPath Main'},
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Tap Monthly Calendar icon in AppBar
    await tester.tap(find.byKey(const ValueKey('open-monthly-calendar-btn')));
    await tester.pumpAndSettle();

    // 2. Monthly schedule screen is presented
    expect(find.text('Monthly Schedule'), findsOneWidget);
    expect(find.text('November 2026'), findsOneWidget);

    // 3. Calendar Legend is displayed
    expect(find.text('Working'), findsWidgets);
    expect(find.text('Off'), findsWidgets);
    expect(find.text('Custom Hours'), findsWidgets);
    expect(find.text('Time Off'), findsWidgets);

    // 4. Month navigation (< and >)
    await tester.tap(find.byKey(const ValueKey('next-month-btn')));
    await tester.pumpAndSettle();
    expect(find.text('December 2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('prev-month-btn')));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);

    // 5. Today shortcut button
    await tester.tap(find.byKey(const ValueKey('jump-to-today-btn')));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);

    // 6. Scroll to and verify Selected day panel beneath calendar
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('view-in-weekly-btn')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('monthly-manage-day-btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('view-in-weekly-btn')), findsOneWidget);

    // Tap "View in Weekly Schedule"
    await tester.tap(find.byKey(const ValueKey('view-in-weekly-btn')));
    await tester.pumpAndSettle();

    // Verify back on Weekly view
    expect(find.text('Availability'), findsOneWidget);
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
