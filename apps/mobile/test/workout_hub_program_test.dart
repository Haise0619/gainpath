import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/app/routing/workout_prep_route.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/routine_screen.dart';
import 'package:gainpath_mobile/features/workout/application/published_routine_catalog_cubit.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/published_routine_catalog_controls.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/application/workout_program_controller.dart';
import 'package:gainpath_mobile/features/workout/application/workout_hub_program.dart';
import 'routine_journey_controller_test.dart' show MemoryJourneyStore;
import 'workout_program_controller_test.dart'
    show MemoryProgramStore, programFixture;

void main() {
  test('program preview reads the scheduled workout without changing progress',
      () async {
    final scope = SessionScope(userId: 'member', organizationId: 'gym');
    final store = MemoryProgramStore(scope);
    final controller = WorkoutProgramController(
        scope: scope,
        activeScope: () => scope,
        store: store,
        routineStore: MemoryJourneyStore(scope),
        newId: () => 'id_1');
    addTearDown(controller.dispose);
    await controller.open();
    await controller
        .enroll(programFixture(), DateTime.utc(2026, 11, 2), {1, 3, 5});
    final before = store.journal.revision;
    final hub = WorkoutHubProgram(controller);
    final view = await hub.refresh();
    expect(view?.routine.title, 'Full body');
    expect(view?.day, 1);
    expect(view?.inProgress, false);
    expect(store.journal.revision, before);
    expect(store.journal.active!.progress, isEmpty);
  });

  test(
      'starting a changed scheduled workout is rejected before writing progress',
      () async {
    final scope = SessionScope(userId: 'member', organizationId: 'gym');
    final store = MemoryProgramStore(scope);
    final controller = WorkoutProgramController(
        scope: scope,
        activeScope: () => scope,
        store: store,
        routineStore: MemoryJourneyStore(scope),
        newId: () => 'id_1');
    addTearDown(controller.dispose);
    await controller.open();
    await controller
        .enroll(programFixture(), DateTime.utc(2026, 11, 2), {1, 3, 5});
    final hub = WorkoutHubProgram(controller);
    final shown = (await hub.refresh())!;
    await controller.skip(shown.dayKey);
    final revision = store.journal.revision;
    await expectLater(hub.start(shown), throwsStateError);
    expect(store.journal.revision, revision);
    expect(store.journal.active!.progress[shown.dayKey]?.attemptId, isNull);
  });
  test('explicit start creates one program attempt and can resume it',
      () async {
    final scope = SessionScope(userId: 'member', organizationId: 'gym');
    final store = MemoryProgramStore(scope);
    var id = 0;
    final controller = WorkoutProgramController(
        scope: scope,
        activeScope: () => scope,
        store: store,
        routineStore: MemoryJourneyStore(scope),
        newId: () => 'id_${++id}');
    addTearDown(controller.dispose);
    await controller.open();
    await controller
        .enroll(programFixture(), DateTime.utc(2026, 11, 2), {1, 3, 5});
    final hub = WorkoutHubProgram(controller);
    final first = (await hub.refresh())!;
    final launch = await hub.start(first);
    expect(launch.routine.id, 'routine_full');
    expect(store.journal.active!.progress[first.dayKey]!.attemptId,
        launch.attemptId);
    final resume = (await hub.refresh())!;
    expect(resume.inProgress, true);
    final next = await hub.start(resume);
    expect(next.attemptId, launch.attemptId);
  });

  testWidgets(
      'program is shown first and choosing a free workout does not change it',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = InMemoryAuthRepository(organizationId: 'gym');
    late AuthBloc auth;
    await tester.runAsync(() async {
      auth = AuthBloc(repository: repository);
      await Future<void>.delayed(Duration.zero);
      auth.add(const LoginSubmitted(
          email: 'member@example.com', password: 'password123'));
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedIn);
    });
    final scope = auth.state.session!.scope;
    final store = MemoryProgramStore(scope);
    final routineStore = MemoryJourneyStore(scope);
    var id = 0;
    final seed = WorkoutProgramController(
        scope: scope,
        activeScope: () => scope,
        store: store,
        routineStore: routineStore,
        newId: () => 'id_${++id}');
    await seed.open();
    await seed.enroll(programFixture(), DateTime.utc(2026, 11, 2), {1, 3, 5});
    seed.dispose();
    final revision = store.journal.revision;
    final free = PublishedRoutine.fromDocument('free', {
      'schemaVersion': 1,
      'kind': 'routine',
      'status': 'published',
      'sourceBlueprintId': 'source',
      'title': 'Free strength',
      'estimatedMinutes': 10,
      'exercises': [
        {'exerciseId': 'manual', 'name': 'Free movement', 'sets': 2, 'reps': 8}
      ],
    });
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
          home: WorkoutPrepRoute(
              publishedRoutine: free,
              programStoreFactory: (_) async => store,
              routineStoreFactory: (_) async => routineStore,
              routineCatalogControls: PublishedRoutineCatalogControls(
                  state: PublishedRoutineCatalogState(
                      status: CatalogStatus.ready,
                      items: [free],
                      selected: free),
                  onRefresh: () async {},
                  onSelect: (_) {},
                  onLoadMore: () async {})),
        )));
    await tester.pumpAndSettle();
    expect(find.text('Full body'), findsOneWidget);
    expect(find.textContaining('YOUR PROGRAM'), findsOneWidget);
    expect(store.journal.revision, revision);
    await tester.tap(find.text('View routine'));
    await tester.pumpAndSettle();
    expect(find.byType(RoutineScreen), findsOneWidget);
    expect(store.journal.revision, revision);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Free strength'));
    await tester.pumpAndSettle();
    expect(find.text('Free strength'), findsOneWidget);
    expect(find.text('SELECTED WORKOUT'), findsOneWidget);
    expect(store.journal.revision, revision);
    await tester.tap(find.text('Change workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('From your training plan'));
    await tester.pumpAndSettle();
    expect(find.text('Full body'), findsOneWidget);
    expect(store.journal.revision, revision);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(auth.close);
    await repository.dispose();
  });
  test('account change prevents a preview from starting', () async {
    final scope = SessionScope(userId: 'member', organizationId: 'gym');
    SessionScope? active = scope;
    final store = MemoryProgramStore(scope);
    final controller = WorkoutProgramController(
        scope: scope,
        activeScope: () => active,
        store: store,
        routineStore: MemoryJourneyStore(scope),
        newId: () => 'id_1');
    addTearDown(controller.dispose);
    await controller.open();
    await controller
        .enroll(programFixture(), DateTime.utc(2026, 11, 2), {1, 3, 5});
    final hub = WorkoutHubProgram(controller);
    final shown = (await hub.refresh())!;
    final revision = store.journal.revision;
    active = null;
    await expectLater(hub.start(shown), throwsStateError);
    expect(store.journal.revision, revision);
    expect(store.journal.active!.progress, isEmpty);
  });
}
