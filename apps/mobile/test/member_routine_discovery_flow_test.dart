import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/app/mobile_app.dart';
import 'package:gainpath_mobile/app/home/member_home_screen.dart';
import 'package:gainpath_mobile/app/routing/exercise_tutorial_route.dart';
import 'package:gainpath_mobile/app/routing/real_squat_route.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_catalog_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/routine_screen.dart';
import 'package:gainpath_mobile/features/analytics/data/local_member_progress_repository.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/real_workout_sync.dart';
import 'support/fitness_profile_fake.dart';

PublishedRoutine routine(String id, String title) => PublishedRoutine(
        id: id,
        sourceBlueprintId: 'blueprint-$id',
        title: title,
        estimatedMinutes: 30,
        exercises: [
          PublishedRoutineExercise(
              exerciseId: 'unsupported-$id',
              dayNumber: 1,
              name: 'Exercise $id',
              category: 'Core',
              sets: 3,
              reps: 8,
              cue: '',
              imageUrl: '',
              muscleGroup: 'Core')
        ]);

class _Catalog implements PublishedRoutineCatalogRepository {
  _Catalog(this.scope);
  @override
  final SessionScope scope;
  List<PublishedRoutine> records = [
    routine('a', 'Routine A'),
    routine('b', 'Routine B')
  ];
  @override
  Future<PublishedRoutinePage> loadPage({String? afterId}) async =>
      PublishedRoutinePage(records);
  @override
  Future<PublishedRoutine?> loadById(String id) async {
    for (final item in records) {
      if (item.id == id) return item;
    }
    return null;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'Member chooses, refreshes and navigates the same read-only routine across tabs',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = InMemoryAuthRepository(), profiles = FakeProfileGateway();
    final session = await auth.signIn(
        email: 'member@example.test', password: 'password123');
    await profiles.repository(session.scope).save(sampleProfile());
    final catalog = _Catalog(session.scope);
    final store = InMemoryWorkoutSessionStore(scope: session.scope);
    final sync = MemoryRealWorkoutSyncStore(scope: session.scope);
    final before = (await sync.read()).toJson();
    await tester.pumpWidget(GainPathMobileApp.injected(
        authRepository: auth,
        profileRepositoryFactory: profiles.repository,
        routineCatalogFactory: (_, active) => catalog,
        progressRepositoryFactory: (scope, active) async =>
            StoredLocalMemberProgressRepository(
                scope: scope,
                workoutStore: store,
                syncStore: sync,
                activeScope: active)));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<MemberHomeScreen>(find.byType(MemberHomeScreen))
            .publishedRoutine!
            .id,
        'a');
    await tester.tap(find.text('Workout').last);
    await tester.pumpAndSettle();
    final dropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Routine B · b').last);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<WorkoutPrepScreen>(find.byType(WorkoutPrepScreen))
            .publishedRoutine!
            .id,
        'b');
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    final home = tester.widget<MemberHomeScreen>(find.byType(MemberHomeScreen));
    expect(home.publishedRoutine!.id, 'b');
    // A Member already on Home must see a republished snapshot without logout
    // or first visiting Workout. Exercise IDs/targets and local records stay put.
    catalog.records = [
      routine('a', 'Routine A'),
      routine('b', 'Republished B')
    ];
    await tester.drag(
        find.descendant(
            of: find.byType(MemberHomeScreen),
            matching: find.byType(CustomScrollView)),
        const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<MemberHomeScreen>(find.byType(MemberHomeScreen))
            .publishedRoutine!
            .title,
        'Republished B');
    home.onStartWorkout!();
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<WorkoutPrepScreen>(find.byType(WorkoutPrepScreen))
            .publishedRoutine!
            .title,
        'Republished B');
    catalog.records = [routine('a', 'Routine A'), routine('b', 'Updated B')];
    await tester.ensureVisible(find.byTooltip('Refresh routines'));
    await tester.tap(find.byTooltip('Refresh routines'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<WorkoutPrepScreen>(find.byType(WorkoutPrepScreen))
            .publishedRoutine!
            .title,
        'Updated B');
    await tester.ensureVisible(find.text('View routine'));
    await tester.tap(find.text('View routine'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<RoutineScreen>(find.byType(RoutineScreen))
            .publishedRoutine!
            .id,
        'b');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Watch tutorial'));
    await tester.tap(find.text('Watch tutorial'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ExerciseTutorialRoute>(find.byType(ExerciseTutorialRoute))
            .exercise
            .exerciseId,
        'unsupported-b');
    await tester.pageBack();
    await tester.pumpAndSettle();
    final start = find.text('Start guided session');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.byType(RealSquatRoute), findsNothing);
    expect(await store.read(), isEmpty);
    expect((await sync.read()).toJson(), before);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
