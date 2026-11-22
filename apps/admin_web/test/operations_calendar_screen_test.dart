import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/operations_calendar/operations_calendar_data.dart';
import 'package:gainpath_admin_web/features/operations_calendar/operations_calendar_screen.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import '../../../test_support/fyp_render_support.dart';

final _now = DateTime.utc(2026, 11, 22, 16, 30);
DateTime _myt(int day, [int hour = 0]) => DateTime.utc(2026, 11, day, hour - 8);

OperationsEvent _booking(String id, String coach, String branch, int day,
        int hour, String status,
        {int minutes = 60}) =>
    OperationsEvent(
      id: id,
      sourceId: id,
      title: coach,
      type: CalendarEventType.booking,
      start: _myt(day, hour),
      end: _myt(day, hour).add(Duration(minutes: minutes)),
      branchId: branch,
      coachId: 'fixture-coach',
      status: status,
      paymentStatus: status == 'pending_hold' ? 'pending' : 'cleared',
    );

final _events = [
  _booking('booking-1', 'Jackson Tan', 'main', 23, 10, 'confirmed'),
  _booking('booking-2', 'Nadia Low', 'east', 23, 10, 'pending_hold'),
  _booking('booking-3', 'Ravi Kumar', 'archived', 17, 9, 'completed'),
  _booking('booking-4', 'Maya Wong', 'main', 24, 13, 'cancelled'),
  _booking('booking-5', 'Nur Aisyah', 'east', 23, 23, 'confirmed',
      minutes: 120),
  _booking('booking-6', 'Ravi Kumar', 'main', 26, 15, 'confirmed'),
  _booking('booking-7', 'Nadia Low', 'east', 28, 9, 'confirmed'),
  _booking('booking-8', 'Prem Naidu', 'main', 4, 14, 'completed'),
  _booking('booking-9', 'Nur Aisyah', 'east', 12, 12, 'completed'),
  _booking('booking-10', 'Maya Wong', 'main', 18, 14, 'completed'),
  for (var i = 0; i < 5; i++)
    _booking(
        'busy-$i', 'Coaching session ${i + 1}', 'main', 19, 9 + i, 'completed'),
  OperationsEvent(
    id: 'availability-1',
    sourceId: 'availability-1',
    title: 'Jackson Tan',
    type: CalendarEventType.availability,
    start: _myt(23, 9),
    end: _myt(23, 12),
    status: 'published',
    branchId: 'main',
    coachId: 'fixture-coach',
  ),
  OperationsEvent(
    id: 'availability-2',
    sourceId: 'availability-2',
    title: 'Nadia Low',
    type: CalendarEventType.availability,
    start: _myt(25, 15),
    end: _myt(25, 19),
    status: 'published',
    branchId: 'east',
    coachId: 'fixture-coach-east',
  ),
  OperationsEvent(
    id: 'announcement-1',
    sourceId: 'announcement-1',
    title: 'Equipment maintenance',
    type: CalendarEventType.announcement,
    start: _myt(23),
    end: _myt(26),
    status: 'active',
    category: 'maintenance',
    allDay: true,
    description: 'The strength area will reopen on Thursday morning.',
  ),
  OperationsEvent(
    id: 'announcement-2',
    sourceId: 'announcement-2',
    title: 'Weekend hours',
    type: CalendarEventType.announcement,
    start: _myt(28),
    end: _myt(30),
    status: 'scheduled',
    category: 'operating_hours',
    allDay: true,
    branchIds: const ['main'],
    description: 'The Main Branch closes at 8 PM this weekend.',
  ),
];

typedef _Query = ({DateTime start, DateTime end, String? branch});

class _Repository implements OperationsCalendarRepository {
  final events = <OperationsEvent>[..._events];
  final eventQueries = <_Query>[];
  final insightQueries = <_Query>[];
  final unavailableEvents = <CalendarEventType>{};
  final unavailableMetrics = <String>{};
  Future<CalendarEventsResult>? nextEvents;

  @override
  Future<List<CalendarBranch>> loadBranches() async => const [
        CalendarBranch(id: 'main', name: 'Main Branch', active: true),
        CalendarBranch(id: 'east', name: 'GainPath 2', active: true),
        CalendarBranch(id: 'archived', name: 'Old Studio', active: false),
      ];

  @override
  Future<CalendarEventsResult> loadEvents({
    required DateTime start,
    required DateTime end,
    required Set<CalendarEventType> types,
    String? branchId,
  }) async {
    eventQueries.add((start: start, end: end, branch: branchId));
    final next = nextEvents;
    if (next != null) {
      nextEvents = null;
      return next;
    }
    return CalendarEventsResult(
      events.where((event) {
        if (!types.contains(event.type) ||
            unavailableEvents.contains(event.type) ||
            !event.start.isBefore(end) ||
            !event.end.isAfter(start)) {
          return false;
        }
        return branchId == null ||
            event.branchId == branchId ||
            (event.type == CalendarEventType.announcement &&
                (event.branchIds.isEmpty ||
                    event.branchIds.contains(branchId)));
      }).toList(),
      unavailableEvents.intersection(types),
    );
  }

  @override
  Future<CalendarInsightsResult> loadInsights({
    required DateTime start,
    required DateTime end,
    String? branchId,
  }) async {
    insightQueries.add((start: start, end: end, branch: branchId));
    final month = start.add(const Duration(hours: 8));
    final count = DateTime.utc(month.year, month.month + 1, 0).day;
    return CalendarInsightsResult(
      [
        for (var day = 1; day <= count; day++)
          CalendarInsightDay(
            date: DateTime.utc(month.year, month.month, day),
            visits: day > 23 || unavailableMetrics.contains('visits')
                ? null
                : day.isOdd
                    ? day * (branchId == null ? 3 : 2)
                    : day ~/ 2,
            bookings: day > 23 || unavailableMetrics.contains('bookings')
                ? null
                : day % 10,
            coachingMinor:
                day > 23 || unavailableMetrics.contains('coachingMinor')
                    ? null
                    : day % 5 * 16475,
          ),
      ],
      unavailableMetrics,
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 180));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(finder);
  }
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _choose(WidgetTester tester, String menu, String item) async {
  await _tap(tester, find.byTooltip(menu));
  await _tap(
      tester,
      find
          .ancestor(
            of: find.text(item).last,
            matching:
                find.byWidgetPredicate((widget) => widget is PopupMenuItem),
          )
          .last);
}

class _Harness {
  _Harness(this.repository);
  final _Repository repository;
  final boundary = GlobalKey();
  final opened = <String>[];
  final reports = <(String?, DateTime)>[];

  Future<void> mount(WidgetTester tester,
      {double width = 1440,
      double height = 900,
      bool fixture = false,
      String? initialBranchId}) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (fixture) {
      addTearDown(await installFypOfflineFonts());
      final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
      final icons =
          File('${artifacts.path}/material_fonts/materialicons-regular.otf');
      await (FontLoader('MaterialIcons')
            ..addFont(
                Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
          .load();
    }
    await tester.pumpWidget(RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        theme: fixture ? AppTheme.build() : ThemeData(useMaterial3: true),
        debugShowCheckedModeBanner: false,
        home: Stack(
          fit: StackFit.expand,
          children: [
            OperationsCalendarScreen(
              repository: repository,
              initialBranchId: initialBranchId,
              onOpenSource: (event) => opened.add(event.sourceId),
              onOpenCoach: (event) => opened.add('coach/${event.coachId}'),
              onOpenReport: (branch, date) => reports.add((branch, date)),
              clock: () => _now,
            ),
            if (fixture)
              const Positioned(
                top: 4,
                right: 4,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark,
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      child: Text('FIXTURE DATA',
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'FypChart',
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          )),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ));
    await _settle(tester);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final renderObject =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(boundary));
    await tester.runAsync(() async {
      final image = await renderObject.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('../../build/operations-calendar/fixture-$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }
}

void main() {
  testWidgets('requests visible month, week and day in Malaysia Time',
      (tester) async {
    final repository = _Repository();
    await _Harness(repository).mount(tester);
    expect(find.text('November 2026'), findsWidgets);
    expect(repository.eventQueries.last.start, _myt(-5));
    expect(repository.eventQueries.last.end, DateTime.utc(2026, 12, 6, 16));
    await _choose(tester, 'Calendar view', 'Week');
    expect(repository.eventQueries.last.start, _myt(23));
    expect(repository.eventQueries.last.end, _myt(30));
    await _choose(tester, 'Calendar view', 'Day');
    expect(repository.eventQueries.last.start, _myt(23));
    expect(repository.eventQueries.last.end, _myt(24));
    await _tap(tester, find.byTooltip('Next period'));
    expect(repository.eventQueries.last.start, _myt(24));
    expect(find.textContaining('Nur Aisyah'), findsWidgets);
    await _tap(tester, find.text('Today'));
    expect(find.text('Monday, November 23, 2026'), findsWidgets);
    await _tap(tester, find.byTooltip('Previous period'));
    expect(repository.eventQueries.last.start, _myt(22));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mini calendar jumps across weeks of the same month',
      (tester) async {
    final repository = _Repository();
    await _Harness(repository).mount(tester);
    await _choose(tester, 'Calendar view', 'Week');
    expect(repository.eventQueries.last.start, _myt(23));

    await _tap(tester, find.byTooltip('Jump to Thursday, November 19, 2026'));
    expect(repository.eventQueries.last.start, _myt(16));
    expect(repository.eventQueries.last.end, _myt(23));
    expect(find.textContaining('Coaching session 1'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the complete overflow agenda and routes selected events',
      (tester) async {
    final harness = _Harness(_Repository());
    await harness.mount(tester);
    await _tap(tester, find.textContaining(RegExp(r'\+\d+ more')).first);
    expect(find.text('Coaching session 5'), findsWidgets);
    await _tap(tester, find.text('Coaching session 5').last);
    expect(find.text('Booking details'), findsOneWidget);
    await _tap(tester, find.text('View Booking'));
    expect(harness.opened, ['busy-4']);
    await _tap(tester, find.byKey(const ValueKey('calendar-day-2026-11-22')));
    expect(find.text('No scheduled activities for this day.'), findsOneWidget);
  });

  testWidgets('filters an inactive branch and ignores stale scope results',
      (tester) async {
    final repository = _Repository();
    await _Harness(repository).mount(tester);
    final pending = Completer<CalendarEventsResult>();
    repository.nextEvents = pending.future;
    await _tap(tester, find.byTooltip('Branch filter'));
    await tester.tap(find.text('Main Branch').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.tap(find.byTooltip('Branch filter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _tap(tester, find.text('Old Studio (Inactive)').last);
    expect(repository.eventQueries.last.branch, 'archived');
    pending.complete(CalendarEventsResult([_events.first], const {}));
    await _settle(tester);
    expect(find.text('Jackson Tan'), findsNothing);
    expect(find.textContaining('Ravi Kumar'), findsWidgets);
    expect(find.textContaining('Equipment maintenance'), findsWidgets);
    expect(find.textContaining('Weekend hours'), findsNothing);
  });

  testWidgets('shows partial failure and distinct booking and payment states',
      (tester) async {
    final repository = _Repository()
      ..unavailableEvents.add(CalendarEventType.availability);
    await _Harness(repository).mount(tester, width: 1024, height: 768);
    expect(find.textContaining('Coach availability could not load'),
        findsOneWidget);
    await _tap(tester, find.byTooltip('Event filters'));
    await _tap(
        tester,
        find
            .ancestor(
              of: find.text('Include cancelled and expired'),
              matching:
                  find.byWidgetPredicate((widget) => widget is PopupMenuItem),
            )
            .first);
    await _tap(tester, find.byKey(const ValueKey('calendar-day-2026-11-24')));
    expect(find.textContaining('Cancelled'), findsWidgets);
    await _tap(tester, find.byTooltip('Close panel'));
    await _tap(tester, find.byKey(const ValueKey('calendar-day-2026-11-23')));
    await _tap(tester, find.byKey(const ValueKey('drawer-booking-2')));
    expect(find.text('Pending hold'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'retains Insights scope and selection and drills into Branch Reports',
      (tester) async {
    final repository = _Repository()..unavailableMetrics.add('visits');
    final harness = _Harness(repository);
    await harness.mount(tester, initialBranchId: 'east');
    await _choose(tester, 'Calendar view', 'Week');
    await _tap(tester, find.text('Insights'));
    expect(repository.insightQueries.single, (
      start: _myt(1),
      end: DateTime.utc(2026, 11, 30, 16),
      branch: 'east',
    ));
    expect(find.textContaining('Gym Visits could not load'), findsOneWidget);
    await _choose(tester, 'Heatmap metric', 'Confirmed Sandbox Receipts (MYR)');
    expect(find.text('MYR 494.25'), findsWidgets);
    await _tap(tester, find.text('View Full Report'));
    expect(harness.reports, [('east', DateTime.utc(2026, 11, 23))]);
    await _tap(tester, find.text('Schedule'));
    expect(find.text('Week'), findsOneWidget);
    expect(repository.eventQueries.last.branch, 'east');
  });

  testWidgets('fits desktop and narrow viewports with scaled text',
      (tester) async {
    await _Harness(_Repository()).mount(tester, width: 1366, height: 768);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final width in [1366.0, 1024.0, 780.0, 390.0]) {
      tester.view.physicalSize = Size(width, 768);
      tester.platformDispatcher.textScaleFactorTestValue =
          width < 400 ? 1.4 : 1;
      await _settle(tester);
      await _choose(tester, 'Calendar view', 'Week');
      expect(tester.takeException(), isNull);
      await _choose(tester, 'Calendar view', 'Month');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'keeps a 420-event month responsive across ranges and branch filters',
      (tester) async {
    final repository = _Repository();
    repository.events
      ..clear()
      ..addAll([
        for (var i = 0; i < 420; i++)
          _booking(
            'busy-$i',
            'Coach ${i % 21}',
            i.isEven ? 'main' : 'east',
            1 + i % 28,
            8 + i % 11,
            'confirmed',
          ),
      ]);
    final stopwatch = Stopwatch()..start();
    await _Harness(repository).mount(tester);
    expect(find.text('420 events in view'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\+\d+ more')), findsWidgets);

    for (var iteration = 0; iteration < 3; iteration++) {
      await _tap(tester, find.byTooltip('Next period'));
      await _tap(tester, find.byTooltip('Previous period'));
    }
    expect(repository.eventQueries.length, 2);
    await _choose(tester, 'Branch filter', 'Main Branch');
    expect(find.text('210 events in view'), findsOneWidget);
    await _choose(tester, 'Calendar view', 'Week');
    await _choose(tester, 'Calendar view', 'Day');
    await _choose(tester, 'Calendar view', 'Month');
    expect(find.text('210 events in view'), findsOneWidget);
    expect(repository.eventQueries.length, 5);
    expect(tester.takeException(), isNull);
    debugPrint('Operations Calendar fixture benchmark: 420 events, '
        '${repository.eventQueries.length} bounded loads, '
        '${stopwatch.elapsedMilliseconds}ms widget-test wall time.');
  });

  testWidgets('renders twelve labeled Flutter screenshots', (tester) async {
    final harness = _Harness(_Repository());
    await harness.mount(tester, fixture: true);
    await harness.capture(tester, '01-month');
    await _choose(tester, 'Calendar view', 'Week');
    await harness.capture(tester, '02-week');
    await _choose(tester, 'Calendar view', 'Day');
    await harness.capture(tester, '03-day');
    await _choose(tester, 'Branch filter', 'Main Branch');
    await harness.capture(tester, '04-specific-branch');
    await _choose(tester, 'Branch filter', 'All branches');
    await harness.capture(tester, '05-all-branches');
    for (final entry in {
      'booking-1': '06-booking-details',
      'availability-1': '07-availability-details',
      'announcement-1': '08-announcement-details',
    }.entries) {
      await _tap(tester, find.byKey(ValueKey('agenda-${entry.key}')));
      await harness.capture(tester, entry.value);
      await _tap(tester, find.byTooltip('Close panel'));
    }
    await _tap(tester, find.text('Insights'));
    await harness.capture(tester, '09-insights-gym-visits');
    await _choose(tester, 'Heatmap metric', 'Confirmed Sandbox Receipts (MYR)');
    await harness.capture(tester, '10-insights-coaching-receipts');
    await _tap(tester, find.text('Schedule'));
    await _choose(tester, 'Calendar view', 'Month');
    await _tap(tester, find.textContaining(RegExp(r'\+\d+ more')).first);
    await harness.capture(tester, '11-busy-day-overflow');
    await _tap(tester, find.byTooltip('Close panel'));
    tester.view.physicalSize = const Size(1024, 768);
    await _settle(tester);
    await harness.capture(tester, '12-responsive-1024');
    expect(tester.takeException(), isNull);
  }, skip: !const bool.fromEnvironment('CAPTURE_OPERATIONS_CALENDAR'));
}
