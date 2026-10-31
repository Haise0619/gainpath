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
      description: tutorial.description,
      thumbnailUrl: tutorial.thumbnailUrl,
      difficulty: tutorial.difficulty,
      equipment: tutorial.equipment,
      tutorialSteps: tutorial.tutorialSteps,
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
  testWidgets('catalog authors overview and ordered tutorial steps',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final catalog = _ExerciseCatalog()..entries.clear();
    await tester.pumpWidget(RepositoryProvider<TutorialRepository>.value(
        value: catalog,
        child: MaterialApp(
            theme: AppTheme.build(), home: const ExerciseTutorialsScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();
    Finder field(String label) => find.widgetWithText(TextFormField, label);
    await tester.enterText(field('Title'), 'Cable row');
    await tester.ensureVisible(field('Exercise overview'));
    await tester.enterText(
        field('Exercise overview'), 'A controlled pulling movement.');
    final add = find.text('Add tutorial step');
    for (final title in ['Prepare', 'Pull']) {
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.ensureVisible(field('Step title').last);
      await tester.enterText(field('Step title').last, title);
      await tester.ensureVisible(field('Step description').last);
      await tester.enterText(
          field('Step description').last, '$title with control.');
    }
    await tester.ensureVisible(find.byTooltip('Move step 2 up'));
    await tester.tap(find.byTooltip('Move step 2 up'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(field('Step title').first)
            .controller!
            .text,
        'Pull');
    await tester.ensureVisible(find.byTooltip('Remove step 2'));
    await tester.tap(find.byTooltip('Remove step 2'));
    await tester.pumpAndSettle();
    expect(field('Step title'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'Create exercise');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
        catalog.entries.single.description, 'A controlled pulling movement.');
    expect(catalog.entries.single.tutorialSteps.single.title, 'Pull');
    expect(catalog.entries.single.tutorialSteps.single.description,
        'Pull with control.');
  });
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
      'routine builder moves catalog exercises with their targets before publication',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final exercises = _ExerciseCatalog()
      ..entries.add(TutorialVideo(
          id: 'row-1',
          title: 'Cable row',
          category: 'Upper body',
          status: TutorialStatus.active,
          videoUrl: ''));
    final routines = _RoutineRepository()
      ..entries.add(RoutineBlueprint(
          id: 'routine-a',
          name: 'Ordered routine',
          level: 'Beginner',
          assignedMembers: 0,
          days: [
            const RoutineDay(1, [
              RoutineExerciseRef('Squat', 3, 8, exerciseId: 'squat-1'),
              RoutineExerciseRef('Cable row', 4, 12, exerciseId: 'row-1'),
            ])
          ]));
    await tester.pumpWidget(MultiRepositoryProvider(
        providers: [
          RepositoryProvider<TutorialRepository>.value(value: exercises),
          RepositoryProvider<RoutineTemplateRepository>.value(value: routines),
        ],
        child: MaterialApp(
            theme: AppTheme.build(), home: const RoutineTemplatesScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ordered routine'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.edit_outlined));
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Move down').first);
    await tester.tap(find.text('Move down').first);
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save changes');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final ordered = routines.entries.last.days.single.exercises;
    expect(ordered.map((e) => e.exerciseId), ['row-1', 'squat-1']);
    expect(ordered.map((e) => [e.sets, e.reps]), [
      [4, 12],
      [3, 8]
    ]);
    expect(routines.entries.last.days.single.dayNumber, 1);
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

  testWidgets(
      'guided-only exercise can be registered without a video or an AI toggle',
      (tester) async {
    final exercises = _ExerciseCatalog()..entries.clear();
    await tester.pumpWidget(RepositoryProvider<TutorialRepository>.value(
        value: exercises,
        child: MaterialApp(
            theme: AppTheme.build(), home: const ExerciseTutorialsScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Cable row');
    expect(find.text('Guided only'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    final save = find.widgetWithText(FilledButton, 'Create exercise');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(exercises.entries.single.title, 'Cable row');
    expect(exercises.entries.single.videoUrl, isEmpty);
    expect(exercises.entries.single.trackingCapability.hasPoseTracking, false);
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
    expect(dropdowns, findsNWidgets(3));
    await tester.ensureVisible(dropdowns.last);
    await tester.tap(dropdowns.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active').last);
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Create exercise'));
    await tester.tap(find.widgetWithText(FilledButton, 'Create exercise'));
    await tester.pumpAndSettle();
    expect(exercises.entries.single.status, TutorialStatus.active);
  });
}
