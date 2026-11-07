import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/application/workout_program_controller.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_program_screen.dart';
import 'routine_journey_controller_test.dart' show MemoryJourneyStore;
import 'workout_program_controller_test.dart'
    show MemoryProgramStore, programFixture;
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'package:gainpath_mobile/features/workout/domain/program_enrollment.dart';
import 'hybrid_routine_journey_test.dart' show hybridFixture;

void main() {
  for (final catalogFails in [false, true]) {
    testWidgets(
        'fresh discovery blocks withdrawn or unavailable enrollment: failure=$catalogFails',
        (tester) async {
      final scope = SessionScope(userId: 'member', organizationId: 'gym');
      final store = MemoryProgramStore(scope);
      final c = WorkoutProgramController(
          scope: scope,
          activeScope: () => scope,
          store: store,
          routineStore: MemoryJourneyStore(scope),
          newId: () => 'new');
      await c.open();
      var calls = 0;
      await tester.pumpWidget(MaterialApp(
          home: WorkoutProgramScreen(
              controller: c,
              today: DateTime.utc(2026, 11, 2),
              onOpenRoutine: (_) async {},
              loadPrograms: () async {
                calls++;
                if (calls == 1) return [programFixture()];
                if (catalogFails) throw StateError('offline');
                return [];
              })));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start program'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start program'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(c.enrollment, isNull);
      expect(store.journal.enrollments, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
  testWidgets('Program schedule renders timed targets and actual upcoming date',
      (tester) async {
    final json = programFixture().toJson();
    json['schemaVersion'] = 2;
    json['days'] = (json['days'] as List).map((raw) {
      final day = Map<String, dynamic>.from(raw as Map)..remove('restSeconds');
      day['schemaVersion'] = 2;
      day['restOverrideSeconds'] = null;
      if (day['kind'] == 'workout') {
        day['routineId'] = hybridFixture().id;
        day['routineSnapshot'] = routinePlanSnapshot(hybridFixture());
      }
      return day;
    }).toList();
    final program = WorkoutProgram.fromJson(json);
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    final c = WorkoutProgramController(
        scope: scope,
        activeScope: () => scope,
        store: MemoryProgramStore(scope),
        routineStore: MemoryJourneyStore(scope),
        newId: () => 'mixed');
    await c.open();
    await c.enroll(program, DateTime.utc(2026, 11, 2), {1, 3, 5});
    await tester.pumpWidget(MaterialApp(
        home: WorkoutProgramScreen(
            controller: c,
            loadPrograms: () async => [program],
            today: DateTime.utc(2026, 11, 1),
            onOpenRoutine: (_) async {})));
    await tester.pumpAndSettle();
    expect(find.text('Upcoming workout'), findsOneWidget);
    expect(find.textContaining('Mon 2026-11-02'), findsOneWidget);
    expect(find.textContaining('2 sets × 45 sec'), findsOneWidget);
    expect(find.text('Video Timed'), findsWidgets);
    expect(find.textContaining('null reps'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('Malaysia midnight refreshes today on the next minute tick',
      (tester) async {
    final scope = SessionScope(userId: 'member', organizationId: 'gym');
    final c = WorkoutProgramController(
        scope: scope,
        activeScope: () => scope,
        store: MemoryProgramStore(scope),
        routineStore: MemoryJourneyStore(scope),
        newId: () => 'rollover');
    await c.open();
    await c.enroll(programFixture(), DateTime.utc(2026, 11, 2), {1, 3, 5});
    var instant = DateTime.utc(2026, 11, 2, 15, 59);
    await tester.pumpWidget(MaterialApp(
        home: WorkoutProgramScreen(
            controller: c,
            loadPrograms: () async => [programFixture()],
            today: DateTime.utc(2026, 11, 2),
            clock: () => instant,
            onOpenRoutine: (_) async {})));
    await tester.pumpAndSettle();
    expect(find.text('Week 1 · Mon 2026-11-02'), findsOneWidget);
    expect(find.text("Today's workout"), findsOneWidget);
    expect(find.textContaining('null reps'), findsNothing);
    final title = tester.widget<Text>(find.text(programFixture().title).first);
    expect(title.style?.color, const Color(0xFF211A2E));
    instant = DateTime.utc(2026, 11, 2, 16);
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(find.text('Week 1 · Tue 2026-11-03'), findsOneWidget);
    expect(find.text('Active recovery'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('Today screen supports 320px and double text without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scope = SessionScope(userId: 'member', organizationId: 'gym');
    final c = WorkoutProgramController(
        scope: scope,
        activeScope: () => scope,
        store: MemoryProgramStore(scope),
        routineStore: MemoryJourneyStore(scope),
        newId: () => 'small');
    await c.open();
    await c.enroll(programFixture(), DateTime.utc(2026, 11, 2), {1, 3, 5});
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: WorkoutProgramScreen(
            controller: c,
            loadPrograms: () async => [programFixture()],
            today: DateTime.utc(2026, 11, 2),
            onOpenRoutine: (_) async {})));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
        find.text('Week 1 · 0/3 workouts completed'), 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
      'onboarding opens pinned routine and weekly progress remains truthful',
      (tester) async {
    final scope = SessionScope(userId: 'member', organizationId: 'gym');
    final c = WorkoutProgramController(
        scope: scope,
        activeScope: () => scope,
        store: MemoryProgramStore(scope),
        routineStore: MemoryJourneyStore(scope),
        newId: () => 'enrolled');
    await c.open();
    String? opened;
    await tester.pumpWidget(MaterialApp(
        home: WorkoutProgramScreen(
            controller: c,
            loadPrograms: () async => [programFixture()],
            today: DateTime.utc(2026, 11, 2),
            onOpenRoutine: (launch) async {
              opened = launch.routine.id;
            })));
    await tester.pumpAndSettle();
    expect(find.text('Choose your program'), findsOneWidget);
    await tester.ensureVisible(find.text('Start program'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start program'));
    await tester.pumpAndSettle();
    expect(find.text('Week 1 · 0/3 workouts completed'), findsOneWidget);
    await tester.ensureVisible(find.text('Start scheduled routine'));
    await tester.tap(find.text('Start scheduled routine'));
    await tester.pumpAndSettle();
    expect(opened, 'routine_full');
    expect(find.text('Resume scheduled routine'), findsOneWidget);
    expect(c.completedDays(1), 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
      'end plan confirmation cancels safely and conflict retains active history',
      (tester) async {
    final scope = SessionScope(userId: 'member', organizationId: 'gym');
    final store = MemoryProgramStore(scope);
    final c = WorkoutProgramController(
        scope: scope,
        activeScope: () => scope,
        store: store,
        routineStore: MemoryJourneyStore(scope),
        newId: () => 'enrollment');
    await c.open();
    await c.enroll(programFixture(), DateTime.utc(2026, 11, 2), {1, 3, 5});
    final saved = store.journal.enrollments.single.toJson();
    await tester.pumpWidget(MaterialApp(
        home: WorkoutProgramScreen(
            controller: c,
            loadPrograms: () async => [programFixture()],
            today: DateTime.utc(2026, 11, 2),
            onOpenRoutine: (_) async {})));
    await tester.pumpAndSettle();
    Future<void> openEnd() async {
      await tester.scrollUntilVisible(find.text('End current plan'), 180);
      await tester.pumpAndSettle();
      await tester.tap(find.text('End current plan').first);
      await tester.pumpAndSettle();
    }

    await openEnd();
    await tester.tap(find.text('Keep plan'));
    await tester.pumpAndSettle();
    expect(c.enrollment, isNotNull);
    expect(store.journal.enrollments.single.toJson(), saved);
    store.journal = ProgramJournal(
        revision: store.journal.revision + 1,
        activeId: store.journal.activeId,
        enrollments: store.journal.enrollments);
    await openEnd();
    await tester.tap(find.widgetWithText(FilledButton, 'End current plan'));
    await tester.pumpAndSettle();
    expect(c.enrollment, isNotNull);
    expect(store.journal.activeId, 'enrollment');
    expect(store.journal.enrollments.single.toJson(), saved);
    await c.open();
    await tester.pumpAndSettle();
    await openEnd();
    await tester.tap(find.widgetWithText(FilledButton, 'End current plan'));
    await tester.pumpAndSettle();
    expect(c.enrollment, isNull);
    expect(store.journal.activeId, isNull);
    expect(store.journal.enrollments.single.toJson(), saved);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('catalog failure exposes retry without fake programs',
      (tester) async {
    final scope = SessionScope(userId: 'member', organizationId: 'gym');
    final c = WorkoutProgramController(
        scope: scope,
        activeScope: () => scope,
        store: MemoryProgramStore(scope),
        routineStore: MemoryJourneyStore(scope),
        newId: () => 'id');
    await c.open();
    await tester.pumpWidget(MaterialApp(
        home: WorkoutProgramScreen(
            controller: c,
            loadPrograms: () async => throw StateError('not deployed'),
            today: DateTime.utc(2026, 11, 2),
            onOpenRoutine: (_) async {})));
    await tester.pumpAndSettle();
    expect(find.text('Retry programs'), findsOneWidget);
    expect(find.text('Start program'), findsNothing);
    expect(c.enrollment, isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
