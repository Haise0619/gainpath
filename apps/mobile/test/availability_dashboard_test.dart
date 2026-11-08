import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_mobile/app/shells/coach_shell.dart';
import 'package:gainpath_mobile/app/di/coach_module8_dependencies.dart';
import 'coach_profile_state_test.dart' show ProfileFake;
import 'support/coach_account_gateway_fake.dart';
import 'support/availability_dashboard_fixture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/coaching/presentation/coach/availability_screens.dart';
import 'coach_roster_ui_test.dart' show RosterUiFake, editor;

class RefreshFailRoster extends DashboardRosterFake {
  bool fail = false;
  @override
  Future<CoachAvailabilityContext> load(
      {required String coachId,
      String? firstLocalDate,
      int dayCount = 7}) async {
    if (fail) throw const CoachAvailabilityException('unavailable');
    return super.load(
        coachId: coachId, firstLocalDate: firstLocalDate, dayCount: dayCount);
  }
}

void main() {
  test(
      'copy selected weekdays preserves source, limits and off-day semantics without saving',
      () async {
    final repo = RosterUiFake(), e = editor(repo);
    await e.reload();
    e.copyDay(1, [2, 3]);
    expect(e.dayFor(2)!.startMinute, 540);
    expect(e.dayFor(3)!.branchId, 'main');
    e.copyDay(6, [4]);
    expect(e.dayFor(4)!.isActive, isFalse);
    expect(e.dayFor(1)!.isActive, isTrue);
    expect(e.dailyHours, 8);
    expect(e.advanceDays, 14);
    expect(repo.rosterRequests, isEmpty);
    expect(e.dirty, isTrue);
    expect(() => e.copyDay(1, [8]), throwsArgumentError);
    e.dispose();
  });
  testWidgets(
      'save is sticky only for dirty drafts and weekly editor uses Done/time pickers',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: AvailabilityScreen(
            liveRepository: RosterUiFake(),
            coachId: 'coach',
            isCurrent: () => true)));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('availability-save-bar')), findsNothing);
    await t.scrollUntilVisible(find.byKey(const ValueKey('weekly-day-1')), 180,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(
        t.element(find.byKey(const ValueKey('weekly-day-1'))),
        alignment: .5);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('weekly-day-1')));
    await t.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Copy to other days'), findsOneWidget);
    await t.tap(find.byType(Switch).last);
    await t.pumpAndSettle();
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('availability-save-bar')).hitTestable(),
        findsOneWidget);
    await t.tap(find.byKey(const ValueKey('save-roster')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('availability-save-bar')), findsNothing);
    expect(find.text('Saved'), findsWidgets);
    await t.pumpWidget(const SizedBox());
  });
  Future<void> openMonday(WidgetTester t) async {
    await t.scrollUntilVisible(find.byKey(const ValueKey('weekly-day-1')), 160,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(
        t.element(find.byKey(const ValueKey('weekly-day-1'))),
        alignment: .5);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('weekly-day-1')));
    await t.pumpAndSettle();
  }

  testWidgets(
      'copy Off to selected days stays draft until Save and supports the time picker',
      (t) async {
    final repo = DashboardRosterFake();
    await t.pumpWidget(MaterialApp(
        home: AvailabilityScreen(
            liveRepository: repo, coachId: 'coach', isCurrent: () => true)));
    await t.pumpAndSettle();
    await openMonday(t);
    await t.tap(find.byKey(const Key('weekly-start-time')));
    await t.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await t.tap(find.text('Cancel').last);
    await t.pumpAndSettle();
    await t.tap(find.byType(Switch).last);
    await t.tap(find.text('Copy to other days'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(CheckboxListTile, 'Tuesday'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Done'), 140,
        scrollable: find.byType(Scrollable).last);
    await Scrollable.ensureVisible(t.element(find.text('Done')), alignment: .5);
    await t.pumpAndSettle();
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(repo.weekly!.schedule[1].isActive, isTrue);
    expect(repo.rosterRequests, isEmpty);
    await t.tap(find.byKey(const ValueKey('save-roster')));
    await t.pumpAndSettle();
    expect(repo.weekly!.schedule[0].isActive, isFalse);
    expect(repo.weekly!.schedule[1].isActive, isFalse);
    expect(repo.weekly!.schedule[2].isActive, isTrue);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'failed save exposes Retry, preserves intent and only confirms after readback',
      (t) async {
    final repo = DashboardRosterFake()..rosterFailure = 'unavailable';
    await t.pumpWidget(MaterialApp(
        home: AvailabilityScreen(
            liveRepository: repo, coachId: 'coach', isCurrent: () => true)));
    await t.pumpAndSettle();
    await openMonday(t);
    await t.tap(find.byType(Switch).last);
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('save-roster')));
    await t.pumpAndSettle();
    expect(find.text('Retry Save'), findsOneWidget);
    expect(find.text('Saved'), findsNothing);
    final id = repo.rosterRequests.single;
    repo.rosterFailure = null;
    await t.tap(find.byKey(const ValueKey('save-roster')));
    await t.pumpAndSettle();
    expect(repo.rosterRequests.last, id);
    expect(find.byKey(const Key('availability-save-bar')), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'leaving Availability through Coach bottom navigation protects the draft',
      (t) async {
    final repo = DashboardRosterFake();
    await t.pumpWidget(MaterialApp(
        home: CoachShell(
            initialIndex: 1,
            module8: CoachModule8Dependencies(
                account: CoachAccountGatewayFake(), profile: ProfileFake()),
            liveAvailabilityBuilder: (_) => AvailabilityScreen(
                liveRepository: repo, coachId: 'coach', isCurrent: () => true),
            liveRosterBuilder: (_) => const SizedBox(),
            liveEarningsBuilder: (_) => const SizedBox())));
    await t.pumpAndSettle();
    await openMonday(t);
    await t.tap(find.byType(Switch).last);
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    await t.tap(find.text('Profile').last);
    await t.pumpAndSettle();
    expect(find.text('Discard & reload'), findsOneWidget);
    await t.tap(find.text('Not now'));
    await t.pumpAndSettle();
    expect(
        t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
    await t.tap(find.text('Profile').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Discard & reload'));
    await t.pumpAndSettle();
    expect(
        t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 3);
    expect(repo.rosterRequests, isEmpty);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'time picker rejects unsupported minutes and accepts half-hour times',
      (t) async {
    final repo = DashboardRosterFake();
    await t.pumpWidget(MaterialApp(
        home: AvailabilityScreen(
            liveRepository: repo, coachId: 'coach', isCurrent: () => true)));
    await t.pumpAndSettle();
    await openMonday(t);
    await t.tap(find.byKey(const Key('weekly-start-time')));
    await t.pumpAndSettle();
    Navigator.of(t.element(find.byType(TimePickerDialog)))
        .pop(const TimeOfDay(hour: 9, minute: 17));
    await t.pumpAndSettle();
    expect(find.textContaining('Use 30-minute steps'), findsOneWidget);
    expect(find.text('Start 09:00'), findsOneWidget);
    await t.tap(find.byKey(const Key('weekly-start-time')));
    await t.pumpAndSettle();
    Navigator.of(t.element(find.byType(TimePickerDialog)))
        .pop(const TimeOfDay(hour: 10, minute: 30));
    await t.pumpAndSettle();
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('save-roster')));
    await t.pumpAndSettle();
    expect(repo.weekly!.schedule[0].startMinute, 630);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'selected date carries into the separate date editor and time-off form',
      (t) async {
    final repo = DashboardRosterFake();
    await t.pumpWidget(MaterialApp(
        home: AvailabilityScreen(
            liveRepository: repo, coachId: 'coach', isCurrent: () => true)));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('availability-date-2026-11-10')));
    await t.pumpAndSettle();
    expect(find.text('Tue, 10 Nov 2026'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Change This Date'), 100,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(t.element(find.text('Change This Date')),
        alignment: .4);
    await t.pumpAndSettle();
    await t.tap(find.text('Change This Date'));
    await t.pumpAndSettle();
    expect(find.text('Changes to this date only'), findsOneWidget);
    await t.tap(find.byIcon(Icons.close).last);
    await t.pumpAndSettle();
    await t.tap(find.text('Add Time Off').first);
    await t.pumpAndSettle();
    final start = t
        .widgetList<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>))
        .firstWhere((w) => w.decoration.labelText == 'Start date');
    expect(start.initialValue, '2026-11-10');
    expect(repo.rosterRequests, isEmpty);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'booking limit control edits the same local draft and persists only on Save',
      (t) async {
    final repo = DashboardRosterFake();
    await t.pumpWidget(MaterialApp(
        home: AvailabilityScreen(
            liveRepository: repo, coachId: 'coach', isCurrent: () => true)));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
        find.byKey(const Key('availability-booking-limits')), 180,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(
        t.element(find.byKey(const Key('availability-booking-limits'))),
        alignment: .4);
    await t.pumpAndSettle();
    await t.tap(find.text('Booking limits'));
    await t.pumpAndSettle();
    final field =
        find.byKey(const ValueKey<(String, int?)>(('daily-capacity', 8)));
    await t.scrollUntilVisible(field, 120,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(t.element(field), alignment: .4);
    await t.pumpAndSettle();
    await t.tap(field);
    await t.pumpAndSettle();
    await t.tap(find.text('6 hours total').last);
    await t.pumpAndSettle();
    expect(repo.weekly!.dailyCapacityHours, 8);
    await t.tap(find.byKey(const ValueKey('save-roster')));
    await t.pumpAndSettle();
    expect(repo.weekly!.dailyCapacityHours, 6);
    expect(repo.weekly!.advanceBookingWindowDays, 14);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'cached day refresh failure is visible rather than silently stale',
      (t) async {
    final repo = RefreshFailRoster();
    await t.pumpWidget(MaterialApp(
        home: AvailabilityScreen(
            liveRepository: repo, coachId: 'coach', isCurrent: () => true)));
    await t.pumpAndSettle();
    repo.fail = true;
    await t.tap(find.byTooltip('Refresh availability'));
    await t.pumpAndSettle();
    expect(
        find.text(
            'Could not complete the schedule operation. Refresh or retry.'),
        findsOneWidget);
    expect(find.text('Showing the last loaded schedule.'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'saved weekly draft with failed day readback reports both outcomes',
      (t) async {
    final repo = RefreshFailRoster();
    await t.pumpWidget(MaterialApp(
        home: AvailabilityScreen(
            liveRepository: repo, coachId: 'coach', isCurrent: () => true)));
    await t.pumpAndSettle();
    await openMonday(t);
    await t.tap(find.byType(Switch).last);
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    repo.fail = true;
    await t.tap(find.byKey(const ValueKey('save-roster')));
    await t.pumpAndSettle();
    expect(repo.rosterRequests, hasLength(1));
    expect(find.text('Changes saved. Schedule preview could not refresh.'),
        findsOneWidget);
    await t.scrollUntilVisible(
        find.text('Showing the last loaded schedule.'), -180,
        scrollable: find.byType(Scrollable).first);
    expect(
        find.text(
            'Could not complete the schedule operation. Refresh or retry.'),
        findsOneWidget);
    expect(find.text('Showing the last loaded schedule.'), findsOneWidget);
    expect(find.byKey(const Key('availability-save-bar')), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
}
