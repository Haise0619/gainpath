import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/recommendation/application/admin_ai_repository.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/admin_ai_pages.dart';
import 'package:gainpath_admin_web/features/workout/domain/admin_workout_program_repository.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../test_support/fyp_render_support.dart';

Map<String, dynamic> draft(String type, [int n = 1]) => {
      'type': type,
      'name': type == 'exercise'
          ? 'Glute Bridge $n'
          : type == 'routine'
              ? 'Lower Body Foundations $n'
              : 'Strength Foundations $n',
      'description':
          'Beginner-friendly guidance using the current exercise catalog.',
      'difficulty': 'Beginner',
      'category': 'Accessory',
      'muscleGroups': ['Glutes'],
      'equipment': 'Bodyweight',
      'instructions': [
        'Start in a comfortable position.',
        'Move slowly and return to the start.'
      ],
      'durationMinutes': 20,
      'goal': 'Muscle gain',
      'exercises': [
        {
          'exerciseId': 'squat',
          'name': 'Squat',
          'sets': 3,
          'reps': 8,
          'restSeconds': 60,
          'executionMode': 'aiTracked',
          'revision': 1
        }
      ],
      'routineIds': ['foundation'],
      'evidence': [
        'Fixture: one published lower-body routine; beginner catalog coverage.'
      ],
      'sources': []
    };
final ai = {
  'model': 'fixture-model',
  'providerSource': 'mock_or_recorded',
  'latencyMillis': 8,
  'totalTokens': 90
};

class Catalog extends TutorialRepository {
  TutorialVideo? saved;
  @override
  bool get requiresCatalogSelection => true;
  @override
  List<TutorialVideo> get tutorials => [
        TutorialVideo(
            id: 'squat',
            title: 'Squat',
            category: 'Legs',
            status: TutorialStatus.active,
            executionMode: ExerciseExecutionMode.aiTracked,
            trackingCapability: ExerciseTrackingCapability.sideViewSquat,
            editRevision: 1)
      ];
  @override
  Future<TutorialVideo> save(TutorialVideo t) async {
    saved = t;
    return t;
  }
}

class Routines extends RoutineTemplateRepository
    implements RoutineCoverRepository {
  RoutineBlueprint? saved;
  EquipmentImage? uploaded;
  int publishes = 0;
  @override
  List<RoutineBlueprint> get routineTemplates => [];
  @override
  Future<RoutineBlueprint> save(RoutineBlueprint t) async {
    saved = t;
    return t;
  }

  @override
  Future<RoutineBlueprint> saveWithCover(
      RoutineBlueprint t, EquipmentImage image) async {
    uploaded = image;
    return save(t);
  }

  @override
  Future<void> publish(String id) async {
    publishes++;
  }
}

class Picker implements EquipmentImagePicker {
  @override
  Future<EquipmentImage?> pick() async => EquipmentImage(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII='));
}

class Programs implements AdminWorkoutProgramRepository {
  WorkoutProgram? saved;
  @override
  bool get current => true;
  @override
  Future<AdminProgramCatalog> load() async =>
      const AdminProgramCatalog(programs: [], drafts: [], routines: []);
  @override
  Future<int> saveDraft(WorkoutProgram p,
      {required int expectedRevision, required String requestId}) async {
    saved = p;
    return 1;
  }

  @override
  Future<AdminProgramDraft> publish(String id,
          {required int expectedRevision, required String requestId}) async =>
      throw UnimplementedError();
}

Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('GAINPATH_RENDER_ADMIN_AI')) return;
  await t.pump();
  await t.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final f = File('../../build/module13-admin-ai/screenshots/$name.png');
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  Future<void> open(WidgetTester t, Widget page,
      {Catalog? catalog,
      Routines? routines,
      Programs? programs,
      GlobalKey? key,
      double width = 1400,
      double scale = 1}) async {
    addTearDown(await installFypOfflineFonts());
    await (FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.sublistView(File(
                  'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
              .readAsBytesSync()))))
        .load();
    t.view.physicalSize = Size(width, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MultiRepositoryProvider(
        providers: [
          RepositoryProvider<TutorialRepository>.value(
              value: catalog ?? Catalog()),
          RepositoryProvider<RoutineTemplateRepository>.value(
              value: routines ?? Routines()),
          RepositoryProvider<EquipmentImagePicker>.value(value: Picker()),
          RepositoryProvider<AdminWorkoutProgramRepository>.value(
              value: programs ?? Programs())
        ],
        child: RepaintBoundary(
            key: key,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.build(),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!),
                home: Scaffold(backgroundColor: AppColors.bg, body: page)))));
    await t.pumpAndSettle();
  }

  AdminAiRepository planner() => AdminAiRepository(
      organizationId: 'gainpath',
      isCurrent: () => true,
      invoke: (op, q) async => {
            'summary': 'Fixture: expand beginner lower-body options.',
            'scope': 'Synthetic test fixture; no live Gemini call.',
            'suggestions': [
              for (var i = 1; i <= 3; i++) draft('${q['type']}', i)
            ],
            'ai': ai
          });
  Future<void> tap(WidgetTester t, String text) async {
    await t.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, text);
    final f =
        button.evaluate().isNotEmpty ? button.first : find.text(text).first;
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets(
      'planner calls only on Generate and applies to the existing Exercise editor',
      (t) async {
    var calls = 0;
    final repo = AdminAiRepository(
        organizationId: 'gainpath',
        isCurrent: () => true,
        invoke: (op, q) async {
          calls++;
          return {
            'summary': 'Catalog opportunities',
            'suggestions': [draft('exercise')],
            'ai': ai
          };
        });
    final c = Catalog(), key = GlobalKey();
    await open(t, AiContentPlannerPage(repository: repo), catalog: c, key: key);
    expect(calls, 0);
    await tap(t, 'Generate suggestions');
    expect(calls, 1);
    await capture(t, key, 'planner-exercise');
    await tap(t, 'Apply suggestion');
    expect(find.text('Glute Bridge 1'), findsWidgets);
    expect(c.saved, isNull);
    expect(
        find.widgetWithText(FilledButton, 'Create exercise'), findsOneWidget);
    await capture(t, key, 'exercise-prefill');
    final title = find.byType(TextFormField).first;
    await t.enterText(title, 'Edited Glute Bridge');
    await t.enterText(
        find.byType(TextFormField).at(1), 'https://example.test/tutorial.mp4');
    await tap(t, 'Create exercise');
    expect(c.saved!.title, 'Edited Glute Bridge');
    expect(c.saved!.status, TutorialStatus.draft);
    expect(c.saved!.trackingCapability.hasPoseTracking, isFalse);
  });
  testWidgets(
      'Routine Apply retains catalog ID and supports manual cover and Save',
      (t) async {
    final r = Routines(), key = GlobalKey();
    await open(t, AiContentPlannerPage(repository: planner()),
        routines: r, key: key);
    await tap(t, 'Routine');
    await tap(t, 'Generate suggestions');
    await capture(t, key, 'planner-routine');
    await tap(t, 'Apply suggestion');
    expect(find.text('Lower Body Foundations 1'), findsWidgets);
    expect(r.saved, isNull);
    await capture(t, key, 'routine-prefill');
    final cover = find.textContaining(
        'cover image'); // Existing image picker remains the form's own control.
    expect(cover, findsWidgets);
    final upload = find
        .byType(OutlinedButton)
        .evaluate()
        .where((e) => (e.widget as OutlinedButton).onPressed != null)
        .map((e) => e.widget)
        .toList();
    expect(upload, isNotEmpty);
    await tap(t, 'Choose cover image');
    await tap(t, 'Structure');
    expect(find.text('Squat'), findsWidgets);
    await tap(t, 'Review');
    await tap(t, 'Create template');
    expect(r.saved!.days.single.exercises.single.exerciseId, 'squat');
    expect(r.uploaded, isNotNull);
    expect(r.publishes, 0);
  });
  testWidgets('Program Apply uses existing Program editor without saving',
      (t) async {
    final p = Programs();
    await open(t, AiContentPlannerPage(repository: planner()), programs: p);
    await tap(t, 'Program');
    await tap(t, 'Generate suggestions');
    await tap(t, 'Apply suggestion');
    expect(find.text('Strength Foundations 1'), findsWidgets);
    expect(p.saved, isNull);
    expect(t.takeException(), isNull);
  });
  testWidgets('Outreach analyzes, previews, edits and sends selected content',
      (t) async {
    Map<String, Object?>? sent;
    var generateCalls = 0;
    final repo = AdminAiRepository(
        organizationId: 'gainpath',
        isCurrent: () => true,
        invoke: (op, q) async {
          if (op.endsWith('.members')) {
            return {
              'members': [
                {
                  'memberId': 'member',
                  'name': 'Fixture Member',
                  'goals': ['buildMuscle'],
                  'workouts': 8,
                  'completedRoutines': 2,
                  'lastWorkout': 1794931200000
                }
              ]
            };
          }
          if (op.endsWith('.member')) {
            return {
              'memberId': 'member',
              'name': 'Fixture Member',
              'goals': ['buildMuscle'],
              'experience': 'beginner',
              'workouts': 8,
              'completedRoutines': 2,
              'exercises': [
                {'name': 'Squat', 'count': 4}
              ],
              'routines': [],
              'muscleGroups': {},
              'existing': []
            };
          }
          if (op.endsWith('.generate')) {
            generateCalls++;
            return {
              'previewId': 'fixture-preview',
              'ai': ai,
              'recommendations': [
                for (final (i, kind)
                    in ['content', 'routine', 'trainer'].indexed)
                  {
                    'index': i,
                    'kind': kind,
                    'title': 'Fixture $kind',
                    'message': 'Review this beginner guidance.',
                    'why': ['Matches the saved beginner experience.'],
                    'context': 'Four recent Squat summaries.',
                    'target': {
                      'imageUrl': null,
                      'specialization': kind == 'trainer' ? 'Strength' : null
                    }
                  }
              ]
            };
          }
          if (op.endsWith('.send')) {
            sent = q;
            return {
              'ids': ['one'],
              'status': 'delivered'
            };
          }
          throw StateError(op);
        });
    final key = GlobalKey();
    await open(t, AiMemberOutreachPage(repository: repo), key: key);
    expect(generateCalls, 0);
    await capture(t, key, 'outreach-members');
    await t.tap(find.byTooltip('Analyze member'));
    await t.pumpAndSettle();
    await tap(t, 'Generate AI recommendations');
    await capture(t, key, 'outreach-preview');
    await t.ensureVisible(find.byType(Checkbox).first);
    await t.tap(find.byType(Checkbox).first);
    await t.pumpAndSettle();
    await t.enterText(
        find.byType(TextField).first, 'A message edited by your gym.');
    await tap(t, 'Send 1 recommendation');
    expect((sent!['selections'] as List).single['message'],
        'A message edited by your gym.');
    expect(find.textContaining('Recommendations delivered'), findsOneWidget);
  });
  testWidgets('narrow layout and large text retain controls and empty state',
      (t) async {
    final key = GlobalKey();
    await open(t, AiContentPlannerPage(repository: planner()),
        key: key, width: 420, scale: 1.5);
    await tap(t, 'Generate suggestions');
    expect(t.takeException(), isNull);
    await capture(t, key, 'planner-narrow-large-text');
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });
  testWidgets('failed generation exits Loading and offers a retry', (t) async {
    final repo = AdminAiRepository(
        organizationId: 'gainpath',
        isCurrent: () => true,
        invoke: (op, q) async => throw StateError('offline'));
    await open(t, AiContentPlannerPage(repository: repo));
    await tap(t, 'Generate suggestions');
    expect(find.textContaining('could not be generated'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
