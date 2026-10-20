import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/workout/presentation/admin/routine_templates_screen.dart';
import 'package:gainpath_admin_web/features/workout/presentation/admin/exercise_tutorials_screen.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';

class _ExerciseCatalog implements TutorialRepository {
  final entries = <TutorialVideo>[
    TutorialVideo(
        id: 'squat-1',
        title: 'Squat',
        category: 'Lower body',
        status: TutorialStatus.active,
        videoUrl: ''),
  ];

  @override
  List<TutorialVideo> get tutorials => entries;
  @override
  bool get requiresCatalogSelection => true;
  @override
  Future<List<TutorialVideo>> load() async => entries;
  @override
  Future<TutorialVideo> save(TutorialVideo tutorial) async {
    final saved = TutorialVideo(
      id: tutorial.id.isEmpty ? 'exercise-${entries.length + 1}' : tutorial.id,
      title: tutorial.title,
      category: tutorial.category,
      status: tutorial.status,
      videoUrl: tutorial.videoUrl,
    );
    final index = entries.indexWhere((entry) => entry.id == saved.id);
    if (index == -1) {
      entries.add(saved);
    } else {
      entries[index] = saved;
    }
    return saved;
  }
}

class _RoutineRepository implements RoutineTemplateRepository {
  final entries = <RoutineBlueprint>[];
  String? publishedId;
  Object? saveFailure;
  Object? publishFailure;
  int saveCalls = 0;

  @override
  List<RoutineBlueprint> get routineTemplates => entries;
  @override
  Future<List<RoutineBlueprint>> load() async => entries;
  @override
  Future<RoutineBlueprint> save(RoutineBlueprint blueprint) async {
    saveCalls++;
    if (saveFailure != null) throw saveFailure!;
    entries.add(blueprint);
    return blueprint;
  }

  @override
  Future<void> publish(String blueprintId) async {
    if (publishFailure != null) throw publishFailure!;
    publishedId = blueprintId;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('stale routine disables Save until explicit discard and reload',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final routines = _RoutineRepository()
      ..entries.add(RoutineBlueprint(
          id: 'r',
          name: 'Strength A',
          level: 'Beginner',
          assignedMembers: 0,
          days: [
            const RoutineDay(
                1, [RoutineExerciseRef('Squat', 3, 8, exerciseId: 'squat-1')])
          ]))
      ..saveFailure = const RoutineEditConflict();
    await tester.pumpWidget(MultiRepositoryProvider(
        providers: [
          RepositoryProvider<TutorialRepository>.value(
              value: _ExerciseCatalog()),
          RepositoryProvider<RoutineTemplateRepository>.value(value: routines),
        ],
        child: MaterialApp(
            theme: AppTheme.build(), home: const RoutineTemplatesScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strength A'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.edit_outlined));
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save changes');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(routines.saveCalls, 1);
    await tester.ensureVisible(find.text('Discard and reload'));
    await tester.tap(find.text('Discard and reload'));
    await tester.pumpAndSettle();
    expect(find.text('New template'), findsOneWidget);
  });

  testWidgets(
      'routine builder stores catalog IDs and publishes through its repository',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final exercises = _ExerciseCatalog();
    final routines = _RoutineRepository();
    await tester.pumpWidget(MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TutorialRepository>.value(value: exercises),
        RepositoryProvider<RoutineTemplateRepository>.value(value: routines),
      ],
      child: MaterialApp(
          theme: AppTheme.build(), home: const RoutineTemplatesScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New template'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Strength A');
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
    final exercisePicker = find.byType(DropdownButtonFormField<String>).last;
    await tester.ensureVisible(exercisePicker);
    await tester.tap(exercisePicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Squat').last);
    await tester.pumpAndSettle();
    final create = find.widgetWithText(FilledButton, 'Create template');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(routines.entries.single.days.single.exercises.single.exerciseId,
        'squat-1');
    expect(
        find.text('Blueprint saved. Publish it to update the Member catalog.'),
        findsOneWidget);
    await tester.tap(find.text('Strength A'));
    await tester.pumpAndSettle();
    final publish = find.text('Publish');
    expect(publish, findsOneWidget);
    await tester.ensureVisible(publish);
    await tester.tap(publish);
    await tester.pumpAndSettle();
    expect(routines.publishedId, routines.entries.single.id);
    expect(
        find.text(
            'Routine published. Members can pull to refresh Home or refresh Workout.'),
        findsOneWidget);
  });

  testWidgets(
      'Exercise Tutorials screen saves catalog fields through its repository',
      (tester) async {
    final exercises = _ExerciseCatalog()..entries.clear();
    await tester.pumpWidget(MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TutorialRepository>.value(value: exercises)
      ],
      child: MaterialApp(
          theme: AppTheme.build(), home: const ExerciseTutorialsScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Goblet Squat');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'https://example.test/squat');
    final createExercise = find.widgetWithText(FilledButton, 'Create exercise');
    await tester.ensureVisible(createExercise);
    await tester.tap(createExercise);
    await tester.pumpAndSettle();
    expect(exercises.entries.single.id, 'exercise-1');
    expect(exercises.entries.single.title, 'Goblet Squat');
  });

  testWidgets('Exercise Catalog lets staff activate an exercise for routines',
      (tester) async {
    final exercises = _ExerciseCatalog()..entries.clear();
    await tester.pumpWidget(MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TutorialRepository>.value(value: exercises)
      ],
      child: MaterialApp(
          theme: AppTheme.build(), home: const ExerciseTutorialsScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();
    expect(find.text('CATALOG PREVIEW'), findsOneWidget);
    expect(
        find.textContaining(
            'Active exercises can be added to routine templates.'),
        findsOneWidget);
    expect(
        find.textContaining(
            'visible in the member tutorial library immediately'),
        findsNothing);
    await tester.enterText(find.byType(TextFormField).first, 'Goblet Squat');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'https://example.test/squat');
    final dropdowns = find.byType(DropdownButtonFormField<String>);
    expect(dropdowns, findsNWidgets(2));
    await tester.tap(dropdowns.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create exercise'));
    await tester.pumpAndSettle();
    expect(exercises.entries.single.status, TutorialStatus.active);
  });
}
