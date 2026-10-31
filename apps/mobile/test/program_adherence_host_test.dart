import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_mobile/features/analytics/domain/program_adherence.dart';
import 'package:gainpath_mobile/features/analytics/presentation/program_adherence_host.dart';
import 'package:gainpath_mobile/features/workout/domain/program_enrollment.dart';
import 'workout_program_controller_test.dart' show programFixture;

void main() {
  test('calendar helper uses Malaysia week and excludes skipped or rest', () {
    final p = programFixture();
    final enrollment = ProgramEnrollment(
        id: 'e',
        program: p,
        schedule:
            ProgramSchedule.create(p, DateTime.utc(2026, 11, 2), {1, 3, 5}));
    final summary = ProgramAdherenceSummary(
        enrollment,
        [
          ProgramAdherenceDay('old', DateTime.utc(2026, 11, 1), 1,
              ProgramAdherenceStatus.completed),
          ProgramAdherenceDay('done', DateTime.utc(2026, 11, 2), 1,
              ProgramAdherenceStatus.completed),
          ProgramAdherenceDay('skip', DateTime.utc(2026, 11, 3), 1,
              ProgramAdherenceStatus.skipped),
          ProgramAdherenceDay('rest', DateTime.utc(2026, 11, 4), 1,
              ProgramAdherenceStatus.rest),
          ProgramAdherenceDay('later', DateTime.utc(2026, 11, 6), 1,
              ProgramAdherenceStatus.pending),
          ProgramAdherenceDay('overdue', DateTime.utc(2026, 11, 4), 1,
              ProgramAdherenceStatus.partial),
        ],
        isCurrent: true);
    final now = DateTime.utc(2026, 11, 1, 16);
    expect(completedScheduledThisWeek([summary], now), 1);
    expect(summary.nextUnfinished!.key, 'overdue');
    expect(summary.weekAt(now).length, 5);
  });
  testWidgets(
      'compact current program fits 320px with large text and expands details',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scope = SessionScope(userId: 'one', organizationId: 'g');
    final p = programFixture();
    final enrollment = ProgramEnrollment(
        id: 'e',
        program: p,
        schedule:
            ProgramSchedule.create(p, DateTime.utc(2026, 11, 2), {1, 3, 5}));
    final summary = ProgramAdherenceSummary(
        enrollment,
        [
          ProgramAdherenceDay('done', DateTime.utc(2026, 11, 2), 1,
              ProgramAdherenceStatus.completed),
          ProgramAdherenceDay('pending', DateTime.utc(2026, 11, 4), 1,
              ProgramAdherenceStatus.partial),
        ],
        isCurrent: true);
    var opened = '';
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: SingleChildScrollView(
                    child: ProgramAdherenceHost(
                        scope: scope,
                        activeScope: () => scope,
                        now: DateTime.utc(2026, 11, 5),
                        load: () async => [summary],
                        summaryBuilder: (_, count) => Text('Count: $count'),
                        weeklySummaryBuilder: (_, done, total) =>
                            Text('Week facts: $done/$total'),
                        onOpenProgram: (id) => opened = id))))));
    await tester.pumpAndSettle();
    expect(find.text('Count: 1'), findsOneWidget);
    expect(find.text('Week facts: 1/2'), findsOneWidget);
    expect(find.byType(Chip), findsNothing);
    expect(find.textContaining('Overdue'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('View program'));
    expect(opened, 'e');
    await tester.ensureVisible(find.text('Program details & past programs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Program details & past programs'));
    await tester.pumpAndSettle();
    expect(find.byType(Chip), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'loading and failure do not fabricate counts; retry and choose work',
      (tester) async {
    final scope = SessionScope(userId: 'one', organizationId: 'g');
    final pending = Completer<List<ProgramAdherenceSummary>>();
    var attempts = 0;
    var chosen = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ProgramAdherenceHost(
                scope: scope,
                activeScope: () => scope,
                summaryBuilder: (_, count) => Text('Count: $count'),
                onChooseProgram: () => chosen = true,
                load: () =>
                    attempts++ == 0 ? pending.future : Future.value([])))));
    expect(find.text('Loading program progress…'), findsOneWidget);
    expect(find.text('Count: null'), findsOneWidget);
    pending.completeError(StateError('read failed'));
    await tester.pumpAndSettle();
    expect(find.text('Program progress unavailable.'), findsOneWidget);
    expect(find.text('Count: null'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Count: 0'), findsOneWidget);
    expect(find.text('No current program on this device.'), findsOneWidget);
    await tester.tap(find.text('Choose a program'));
    expect(chosen, isTrue);
  });
  testWidgets('past enrollment is not presented as current', (tester) async {
    final scope = SessionScope(userId: 'one', organizationId: 'g');
    final p = programFixture();
    final old = ProgramAdherenceSummary(
        ProgramEnrollment(
            id: 'old',
            program: p,
            schedule: ProgramSchedule.create(
                p, DateTime.utc(2026, 10, 1), {1, 3, 5})),
        []);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ProgramAdherenceHost(
                    scope: scope,
                    activeScope: () => scope,
                    load: () async => [old],
                    onChooseProgram: () {})))));
    await tester.pumpAndSettle();
    expect(find.text('No current program on this device.'), findsOneWidget);
    expect(find.text(p.title), findsNothing);
    expect(find.text('Choose a program'), findsOneWidget);
    await tester.ensureVisible(find.text('Program details & past programs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Program details & past programs'));
    await tester.pumpAndSettle();
    expect(find.text('Past program: ${p.title}'), findsOneWidget);
  });
  testWidgets(
      'account replacement hides prior completed snapshot during new read',
      (tester) async {
    final one = SessionScope(userId: 'one', organizationId: 'g');
    final two = SessionScope(userId: 'two', organizationId: 'g');
    var active = one;
    final program = programFixture();
    final snapshot = ProgramAdherenceSummary(
        ProgramEnrollment(
            id: 'old',
            program: program,
            schedule: ProgramSchedule.create(
                program, DateTime.utc(2026, 11, 2), {1, 3, 5})),
        [],
        isCurrent: true);
    Widget host(SessionScope scope,
            Future<List<ProgramAdherenceSummary>> Function() load) =>
        MaterialApp(
            home: Scaffold(
                body: ProgramAdherenceHost(
                    scope: scope, activeScope: () => active, load: load)));
    await tester.pumpWidget(host(one, () async => [snapshot]));
    await tester.pump();
    expect(find.text('Current program'), findsOneWidget);
    active = two;
    final pending = Completer<List<ProgramAdherenceSummary>>();
    await tester.pumpWidget(host(two, () => pending.future));
    expect(find.text(snapshot.enrollment.program.title), findsNothing);
    pending.complete([]);
    await tester.pump();
  });
}
