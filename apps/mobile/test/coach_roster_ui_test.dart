import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_mobile/features/coaching/presentation/coach/live_coach_availability_view.dart';
import 'package:gainpath_mobile/features/coaching/presentation/coach/coach_roster_editor.dart';
import 'package:gainpath_mobile/features/coaching/presentation/coach/coach_time_exception_sheet.dart';
import 'support/coach_availability_fake.dart';

class RosterUiFake extends AvailabilityFake implements CoachRosterRepository {
  CoachWeeklyAvailability? weekly = CoachWeeklyAvailability(
      dailyCapacityHours: 8,
      advanceBookingWindowDays: 14,
      schedule: List.generate(
          7,
          (i) => CoachWeeklyDay(
              dayOfWeek: i + 1,
              isActive: i < 5,
              startMinute: 540,
              endMinute: 1020,
              branchId: 'main')));
  List<CoachTimeException> exceptions = [];
  Completer<CoachRosterSnapshot>? rosterPending, savePending;
  final rosterRequests = <String>[];
  String? rosterFailure;
  CoachRosterSnapshot snapshot() => CoachRosterSnapshot(
      coachId: 'coach',
      revision: revision,
      serverNowMillis: 1,
      todayLocalDate: '2026-10-15',
      timeZone: 'Asia/Kuala_Lumpur',
      policyVersion: 'booking-v1',
      throughLocalDate: '2026-10-16',
      assignedBranchIds: ['main'],
      weeklyAvailability: weekly,
      exceptions: exceptions);
  @override
  Future<CoachRosterSnapshot> loadRoster({required String coachId}) async =>
      rosterPending?.future ?? snapshot();
  @override
  Future<CoachRosterSnapshot> saveRoster(
      {required CoachRosterSnapshot baseline,
      required CoachWeeklyAvailability weeklyAvailability,
      required List<CoachTimeException> exceptions,
      required String requestId}) async {
    rosterRequests.add(requestId);
    if (rosterFailure != null) throw CoachAvailabilityException(rosterFailure!);
    if (savePending != null) return savePending!.future;
    weekly = weeklyAvailability;
    this.exceptions = [...exceptions];
    revision++;
    return snapshot();
  }
}

CoachRosterEditor editor(RosterUiFake repo, {bool Function()? current}) =>
    CoachRosterEditor(
        repository: repo,
        coachId: 'coach',
        isCurrent: current ?? () => true,
        onSaved: () {});

class CountingRosterFake extends RosterUiFake {
  int loads = 0;
  @override
  Future<CoachAvailabilityContext> load(
      {required String coachId, String? firstLocalDate, int dayCount = 7}) {
    loads++;
    return super.load(
        coachId: coachId, firstLocalDate: firstLocalDate, dayCount: dayCount);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'weekly save refreshes once; date editor reuses the current snapshot',
      (tester) async {
    final repo = CountingRosterFake();
    await tester.pumpWidget(MaterialApp(
        home: LiveCoachAvailabilityView(
            repository: repo, coachId: 'coach', isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(repo.loads, 1);
    expect(find.byKey(const ValueKey('edit-selected-date-btn')), findsNothing);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('weekly-day-1')), 250);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('save-roster')), 350);
    await tester.tap(find.byKey(const ValueKey('save-roster')));
    await tester.pumpAndSettle();
    expect(repo.loads, 2);
    expect(repo.rosterRequests, hasLength(1));
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('open-specific-date-btn')), -250);
    expect(
        find.byKey(const ValueKey('open-specific-date-btn')), findsOneWidget);
    // The expanded page can align ensureVisible behind the pinned app bar.
    // Scroll to a hittable position before exercising the date editor.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 100));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-specific-date-btn')));
    await tester.pumpAndSettle();
    expect(repo.loads, 2);
    expect(find.text('Save day'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'calendar shows loaded working hours and selected blocked periods',
      (tester) async {
    final repo = RosterUiFake()
      ..stored = [
        DatedCoachWindow(
            branchId: 'main',
            startAtMillis: 1792116000000,
            endAtMillis: 1792119600000)
      ]
      ..exceptions = [
        const CoachTimeException(
            id: 'break',
            type: 'breakTime',
            reason: 'Break',
            startAtMillis: 1792117800000,
            endAtMillis: 1792119600000)
      ];
    await tester.pumpWidget(MaterialApp(
        home: LiveCoachAvailabilityView(
            repository: repo, coachId: 'coach', isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.text('0.5h'), findsOneWidget);
    expect(find.text('Blocked periods on 2026-10-16'), findsOneWidget);
    expect(find.textContaining('10:30 GMT+8 – 11:00 GMT+8'), findsOneWidget);
    expect(find.byTooltip('1 blocked period'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
      'aggregate saves weekly hours and limits then accepts persisted readback',
      () async {
    final repo = RosterUiFake();
    final value = editor(repo);
    await value.reload();
    value.limits(hours: 6, days: 20);
    value.day(const CoachWeeklyDay(
        dayOfWeek: 1,
        isActive: true,
        startMinute: 600,
        endMinute: 960,
        branchId: 'main'));
    expect(value.dirty, isTrue);
    await value.save();
    expect(repo.weekly!.dailyCapacityHours, 6);
    expect(repo.weekly!.advanceBookingWindowDays, 20);
    expect(repo.weekly!.schedule.first.startMinute, 600);
    expect(value.dirty, isFalse);
    expect(value.message, 'Roster saved and refreshed.');
    value.dispose();
  });
  test('missing limits and days do not fabricate persisted configuration',
      () async {
    final repo = RosterUiFake()..weekly = null;
    final value = editor(repo);
    await value.reload();
    expect(value.dailyHours, isNull);
    expect(value.schedule, isEmpty);
    value.limits(hours: 8);
    await value.save();
    expect(repo.rosterRequests, isEmpty);
    expect(value.message, contains('all seven'));
    value.dispose();
  });
  test('exception add edit remove preserves aggregate and cancels never mutate',
      () async {
    final repo = RosterUiFake();
    final value = editor(repo);
    await value.reload();
    value.exception(const CoachTimeException(
        id: 'a',
        type: 'offDay',
        reason: '',
        startAtMillis: 1792116000000,
        endAtMillis: 1792119600000));
    value.exception(const CoachTimeException(
        id: 'a',
        type: 'leave',
        reason: 'Personal',
        startAtMillis: 1792116000000,
        endAtMillis: 1792119600000));
    await value.save();
    expect(repo.exceptions.single.type, 'leave');
    expect(repo.exceptions.single.reason, 'Personal');
    value.remove('a');
    await value.save();
    expect(repo.exceptions, isEmpty);
    value.dispose();
  });
  test('pending duplicate guard and uncertain retry preserve request identity',
      () async {
    final repo = RosterUiFake()..savePending = Completer();
    final value = editor(repo);
    await value.reload();
    value.limits(hours: 6);
    final save = value.save();
    await value.save();
    expect(repo.rosterRequests, hasLength(1));
    repo.savePending!
        .completeError(const CoachAvailabilityException('unavailable'));
    await save;
    expect(value.uncertain, isTrue);
    value.limits(hours: 10);
    expect(value.dailyHours, 6);
    repo.savePending = null;
    await value.save();
    expect(repo.rosterRequests[0], repo.rosterRequests[1]);
    expect(repo.weekly!.dailyCapacityHours, 6);
    value.dispose();
  });
  test('stale conflicts freeze writes until explicit discard and reload',
      () async {
    final repo = RosterUiFake()..rosterFailure = 'aborted';
    final value = editor(repo);
    await value.reload();
    value.limits(hours: 6);
    await value.save();
    value.limits(hours: 10);
    await value.save();
    expect(value.conflict, isTrue);
    expect(value.dailyHours, 6);
    expect(repo.rosterRequests, hasLength(1));
    await value.reload(discard: true);
    expect(value.conflict, isFalse);
    expect(value.dailyHours, 8);
    value.dispose();
  });
  test(
      'late previous account load and save cannot restore roster or report success',
      () async {
    var current = true;
    final repo = RosterUiFake()..rosterPending = Completer();
    final value = editor(repo, current: () => current);
    final load = value.reload();
    current = false;
    repo.rosterPending!.complete(repo.snapshot());
    await load;
    expect(value.baseline, isNull);
    value.dispose();
    current = true;
    repo.rosterPending = null;
    final next = editor(repo, current: () => current);
    await next.reload();
    next.limits(hours: 6);
    repo.savePending = Completer();
    final save = next.save();
    current = false;
    repo.savePending!.complete(repo.snapshot());
    await save;
    expect(next.message, isNull);
    expect(next.dirty, isTrue);
    next.dispose();
  });
  testWidgets('dated editor identifies overrides and capacity in hours',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: LiveCoachAvailabilityView(
            repository: AvailabilityFake(),
            coachId: 'coach',
            isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.text('DATED OVERRIDES'), findsNothing);
    await tester.scrollUntilVisible(
        find.text('Load your schedule to configure booking limits.'), 300);
    expect(find.text('Load your schedule to configure booking limits.'),
        findsOneWidget);
  });
  testWidgets(
      'loading and unset roster show hyphens then all seven editable cards',
      (tester) async {
    final repo = RosterUiFake()
      ..weekly = null
      ..rosterPending = Completer();
    await tester.pumpWidget(MaterialApp(
        home: LiveCoachAvailabilityView(
            repository: repo, coachId: 'coach', isCurrent: () => true)));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    repo.rosterPending!.complete(repo.snapshot());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Monday'), 250);
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('-'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('weekly-day-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply day'));
    await tester.pumpAndSettle();
    expect(repo.weekly, isNull);
    expect(
        find.descendant(
            of: find.ancestor(
                of: find.text('Monday'), matching: find.byType(ListTile)),
            matching: find.text('Off')),
        findsOneWidget);
  });
  testWidgets(
      'exception sheet uses returned boundaries and does not write until aggregate save',
      (tester) async {
    final repo = RosterUiFake();
    CoachTimeException? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async {
                      result = await showModalBottomSheet<CoachTimeException>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => CoachTimeExceptionSheet(
                              repository: repo,
                              roster: repo.snapshot(),
                              isCurrent: () => true));
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('10:00 GMT+8'), findsOneWidget);
    await tester.ensureVisible(find.text('Apply blocked time'));
    await tester.tap(find.text('Apply blocked time'));
    await tester.pumpAndSettle();
    expect(result!.startAtMillis, 1792116000000);
    expect(result!.endAtMillis, 1792117800000);
    expect(result!.id, matches(RegExp(r'^[a-f0-9]{32}$')));
    expect(repo.rosterRequests, isEmpty);
  });
  testWidgets('load failure displays clear error and retry action in UI',
      (tester) async {
    var fail = true;
    final repo = _FailingRosterRepo(() => fail);
    await tester.pumpWidget(MaterialApp(
        home: LiveCoachAvailabilityView(
            repository: repo, coachId: 'coach', isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('App Check or authentication verification failed'),
        findsOneWidget);
    expect(find.text('Retry loading roster'), findsWidgets);
    fail = false;
    await tester.tap(find.text('Retry loading roster').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Monday'), 250);
    expect(find.text('Monday'), findsOneWidget);
  });
}

class _FailingRosterRepo extends RosterUiFake {
  _FailingRosterRepo(this.shouldFail);
  final bool Function() shouldFail;
  @override
  Future<CoachRosterSnapshot> loadRoster({required String coachId}) async {
    if (shouldFail()) {
      throw const CoachAvailabilityException('unauthenticated');
    }
    return snapshot();
  }
}
