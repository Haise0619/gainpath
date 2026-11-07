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
import 'hybrid_routine_journey_test.dart' show hybridFixture;

void main() {
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
