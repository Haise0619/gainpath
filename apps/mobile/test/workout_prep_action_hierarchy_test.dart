import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'package:gainpath_mobile/features/workout/application/published_routine_catalog_cubit.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/published_routine_catalog_controls.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final routine = PublishedRoutine(
      id: 'internal-id',
      sourceBlueprintId: 'blueprint',
      title: 'Strength basics',
      estimatedMinutes: 20,
      exercises: const [
        PublishedRoutineExercise(
            exerciseId: 'exercise-id',
            dayNumber: 1,
            name: 'Squat',
            category: 'Strength',
            sets: 3,
            reps: 8,
            cue: '',
            imageUrl: '',
            muscleGroup: ''),
      ]);

  testWidgets(
      'workout presents selected routine and primary action before optional tools',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = AuthBloc(repository: InMemoryAuthRepository());
    addTearDown(auth.close);
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: WorkoutPrepScreen(live: true, publishedRoutine: routine))));
    await tester.pumpAndSettle();
    expect(find.text('Strength basics'), findsOneWidget);
    final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
    expect(appBar.backgroundColor, isNull);
    expect(appBar.foregroundColor, isNull);
    expect(appBar.titleTextStyle, isNull);
    final start = find.text('Start workout');
    expect(start, findsOneWidget);
    final button = tester.widget<FilledButton>(
        find.ancestor(of: start, matching: find.byWidgetPredicate((w) => w is FilledButton)));
    expect(button.style?.backgroundColor?.resolve({}), AppColors.primary);
    expect(button.style?.foregroundColor?.resolve({}), Colors.white);
    expect(tester.getBottomLeft(start).dy, lessThan(700));
    expect(find.text('Workout session'), findsNothing);
    expect(find.text('internal-id'), findsNothing);
  });

  testWidgets('empty routine does not offer a misleading start action',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: WorkoutPrepScreen(live: true)));
    await tester.pumpAndSettle();
    expect(find.text('Start workout'), findsNothing);
    expect(find.text('No workout selected'), findsOneWidget);
  });
  testWidgets('workout chooser shows a name without exposing internal IDs',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PublishedRoutineCatalogControls(
      state: PublishedRoutineCatalogState(
          status: CatalogStatus.ready, items: [routine], selected: routine),
      onRefresh: () async {},
      onSelect: (_) {},
      onLoadMore: () async {},
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change workout'));
    await tester.pumpAndSettle();
    expect(find.text('Strength basics'), findsOneWidget);
    expect(find.textContaining('internal-id'), findsNothing);
    expect(find.textContaining('internal-id'), findsNothing);
  });
  testWidgets('same-named workouts remain separately selectable',
      (tester) async {
    final other = PublishedRoutine(
        id: 'other-id',
        sourceBlueprintId: 'other',
        title: routine.title,
        estimatedMinutes: 35,
        exercises: routine.exercises);
    String? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PublishedRoutineCatalogControls(
      state: PublishedRoutineCatalogState(
          status: CatalogStatus.ready,
          items: [routine, other],
          selected: routine),
      onRefresh: () async {},
      onSelect: (id) => selected = id,
      onLoadMore: () async {},
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Option 2'));
    await tester.pumpAndSettle();
    expect(selected, 'other-id');
    expect(find.textContaining('other-id'), findsNothing);
  });

  testWidgets('workout page remains usable with large text on a small phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = AuthBloc(repository: InMemoryAuthRepository());
    addTearDown(auth.close);
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.65)),
              child: child!),
          home: WorkoutPrepScreen(
              live: true,
              publishedRoutine: routine,
              routineCatalogControls: PublishedRoutineCatalogControls(
                  state: PublishedRoutineCatalogState(
                      status: CatalogStatus.ready,
                      items: [routine],
                      selected: routine),
                  onRefresh: () async {},
                  onSelect: (_) {},
                  onLoadMore: () async {})),
        )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start workout'));
    await tester.pumpAndSettle();
    expect(find.text('Start workout'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Scan equipment'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    // Framework reports any layout overflow at the end of the test.
  });
  testWidgets('selected workout primary action is visible on a normal phone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = AuthBloc(repository: InMemoryAuthRepository());
    addTearDown(auth.close);
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.1)),
              child: child!),
          home: Scaffold(
              bottomNavigationBar: const SizedBox(height: 68),
              body: WorkoutPrepScreen(
                  live: true,
                  publishedRoutine: routine,
                  routineCatalogControls: PublishedRoutineCatalogControls(
                      state: PublishedRoutineCatalogState(
                          status: CatalogStatus.ready,
                          items: [routine],
                          selected: routine),
                      onRefresh: () async {},
                      onSelect: (_) {},
                      onLoadMore: () async {}))),
        )));
    await tester.pumpAndSettle();
    final start = find.text('Start workout');
    expect(start, findsOneWidget);
    expect(tester.getBottomLeft(start).dy, lessThanOrEqualTo(776));
  });

  testWidgets('workout loading error gives a retry and no start action',
      (tester) async {
    var refreshed = 0;
    await tester.pumpWidget(MaterialApp(
        home: WorkoutPrepScreen(
      live: true,
      routineLoadFailed: true,
      routineStatusMessage: 'Workouts unavailable',
      routineCatalogControls: PublishedRoutineCatalogControls(
          state: const PublishedRoutineCatalogState(
              status: CatalogStatus.error,
              message: 'Could not load published routines. Please refresh.'),
          onRefresh: () async {
            refreshed++;
          },
          onSelect: (_) {},
          onLoadMore: () async {}),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Start workout'), findsNothing);
    expect(
        find.text(
            'Could not load workouts. Check your connection and try again.'),
        findsOneWidget);
    await tester.tap(find.text('Refresh workouts'));
    await tester.pump();
    expect(refreshed, 1);
  });
}
