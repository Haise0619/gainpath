import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'support/admin_test_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/recommendation/application/admin_ai_repository.dart';
import 'package:gainpath_admin_web/app/routing/admin_ai_draft_route.dart';
import 'package:gainpath_admin_web/features/recommendation/application/admin_ai_drafts.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/admin_ai_pages.dart';
import 'package:gainpath_admin_web/features/workout/domain/admin_workout_program_repository.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../test_support/fyp_render_support.dart';

Map<String, dynamic> draft(String type, [int n = 1]) => {
      'type': type,
      'name': type == 'exercise'
          ? ['Glute Bridge', 'Dead Bug', 'Bird Dog'][n - 1]
          : type == 'routine'
              ? 'Lower Body Foundations $n'
              : 'Strength Foundations $n',
      'description':
          'Beginner-friendly guidance using the current exercise catalog.',
      'difficulty': 'Beginner',
      'contentGap': type == 'exercise'
          ? 'Adds beginner-friendly movement coverage.'
          : type == 'routine'
              ? 'Adds a combined knee and hip workout.'
              : 'Adds a consistent four-week training schedule.',
      'whyRecommended': type == 'exercise'
          ? 'Expands movement variety with a controlled floor exercise.'
          : type == 'routine'
              ? 'Pairs complementary movements in one manageable session.'
              : 'Organizes published routines with recovery between training days.',
      'evidence': [
        'Fixture: one published lower-body routine; beginner catalog coverage.'
      ],
      'sources': [],
      if (type == 'exercise') ...{
        'category': 'Accessory',
        'primaryMuscleGroup': n == 1 ? 'Glutes' : 'Core',
        'equipment': 'Bodyweight',
        'variantDifference': '',
        'instructions': [
          'Start in a comfortable position.',
          'Move slowly and return to the start.'
        ]
      },
      if (type == 'routine') ...{
        'durationMinutes': 20,
        'goal': 'Muscle gain',
        'muscleGroups': ['Glutes'],
        'equipment': 'Bodyweight',
        'exercises': [
          {
            'exerciseId': 'squat',
            'name': 'Squat',
            'sets': 3,
            'reps': 8,
            'restSeconds': 60,
            'executionMode': 'aiTracked',
            'revision': 1
          },
          {
            'exerciseId': 'bridge',
            'name': 'Glute Bridge',
            'sets': 3,
            'reps': 10,
            'restSeconds': 60,
            'executionMode': 'videoGuidedTimed',
            'revision': 1
          }
        ]
      },
      if (type == 'program') ...{
        'weeks': 4,
        'goal': 'Muscle gain',
        'trainingDays': [
          {
            'weekday': 2,
            'routineId': 'foundation',
            'routineDay': 1,
            'routineName': 'Foundation Workout',
            'category': 'Lower Body'
          },
          {
            'weekday': 5,
            'routineId': 'foundation',
            'routineDay': 1,
            'routineName': 'Foundation Workout',
            'category': 'Lower Body'
          }
        ]
      },
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
            editRevision: 1),
        TutorialVideo(
            id: 'bridge',
            title: 'Glute Bridge',
            category: 'Accessory',
            status: TutorialStatus.active,
            executionMode: ExerciseExecutionMode.videoGuidedTimed,
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
    final f = File(name.startsWith('workspace-')
        ? '../../build/module13-completion-20261118/screenshots/$name.png'
        : name.startsWith('outreach-fix-')
            ? '../../build/outreach-fix-20261118/screenshots/$name.png'
            : '../../build/planner-types-fix/screenshots/$name.png');
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
    await loadAdminMaterialIcons();
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
                    child: Column(children: [
                      if (const bool.fromEnvironment(
                          'GAINPATH_RENDER_ADMIN_AI'))
                        const Material(
                            child: SizedBox(
                                width: double.infinity,
                                child: Text(
                                    'OFFLINE WIDGET FIXTURE · no live provider request'))),
                      Expanded(child: child!),
                    ])),
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

  test(
      'Program seed preserves weekly choices and the existing four-week contract',
      () {
    final p = aiProgramSeed(draft('program'), 'local-program');
    expect(p.weeks, 4);
    expect(p.days.length, 28);
    expect(
        p.days
            .where((d) => d.toJson()['kind'] == 'workout')
            .map((d) => d.weekday)
            .toSet(),
        {2, 5});
    expect(
        p.days
            .where((d) => d.kind == 'workout')
            .every((d) => d.routineId == 'foundation'),
        isTrue);
  });
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
    await open(t, AiContentPlannerPage(repository: repo, onApply: openAdminAiDraft), catalog: c, key: key);
    expect(calls, 0);
    await tap(t, 'Generate suggestions');
    expect(calls, 1);
    await capture(t, key, 'planner-exercise');
    await tap(t, 'Apply suggestion');
    expect(find.text('Glute Bridge'), findsWidgets);
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
    expect(c.saved!.executionMode, ExerciseExecutionMode.videoGuidedTimed);
    expect(c.saved!.status, TutorialStatus.draft);
    expect(c.saved!.trackingCapability.hasPoseTracking, isFalse);
  });
  testWidgets(
      'Routine Apply retains catalog ID and supports manual cover and Save',
      (t) async {
    final r = Routines(), key = GlobalKey();
    await open(t, AiContentPlannerPage(repository: planner(), onApply: openAdminAiDraft),
        routines: r, key: key);
    await tap(t, 'Routine');
    await tap(t, 'Generate suggestions');
    await t.ensureVisible(find.text('Lower Body Foundations 1'));
    await t.pumpAndSettle();
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
    expect(r.saved!.days.single.exercises.first.exerciseId, 'squat');
    expect(r.uploaded, isNotNull);
    expect(r.publishes, 0);
  });
  testWidgets('Program Apply uses existing Program editor without saving',
      (t) async {
    final p = Programs(), key = GlobalKey();
    await open(t, AiContentPlannerPage(repository: planner(), onApply: openAdminAiDraft),
        programs: p, key: key);
    await tap(t, 'Program');
    await tap(t, 'Generate suggestions');
    await t.ensureVisible(find.text('Strength Foundations 1'));
    await t.pumpAndSettle();
    await capture(t, key, 'planner-program');
    await tap(t, 'Apply suggestion');
    await capture(t, key, 'program-prefill');
    expect(find.text('Strength Foundations 1'), findsWidgets);
    expect(p.saved, isNull);
    expect(t.takeException(), isNull);
  });
  testWidgets('Outreach uses one home branch for member search and ranking',
      (tester) async {
    final listScopes = <Object?>[];
    final searchScopes = <Object?>[];
    final repo = AdminAiRepository(
      organizationId: 'gainpath',
      isCurrent: () => true,
      invoke: (op, input) async {
        if (op.endsWith('.members')) {
          listScopes.add(input['branchId']);
          return {'members': [], 'branches': [{'id': 'north', 'name': 'North Gym'}]};
        }
        if (op.endsWith('.search')) {
          searchScopes.add(input['branchId']);
          return {'members': []};
        }
        throw StateError('Unexpected operation');
      },
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: AiMemberOutreachPage(repository: repo),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Branches'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('North Gym').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'fixture');
    await tester.tap(find.byTooltip('Search members'));
    await tester.pumpAndSettle();
    expect(listScopes, [null, 'north']);
    expect(searchScopes, ['north']);
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
    await t.pumpAndSettle();
    await t.tap(find.byType(Checkbox).first);
    await t.pumpAndSettle();
    await t.enterText(
        find.byType(TextField).at(1), 'A message edited by your gym.');
    await tap(t, 'Send 1 recommendation');
    expect((sent!['selections'] as List).single['message'],
        'A message edited by your gym.');
    expect(find.textContaining('Recommendations delivered'), findsOneWidget);
  });
  testWidgets('narrow layout and large text retain controls and empty state',
      (t) async {
    final key = GlobalKey();
    await open(t, AiContentPlannerPage(repository: planner(), onApply: openAdminAiDraft),
        key: key, width: 420, scale: 1.5);
    await tap(t, 'Generate suggestions');
    expect(t.takeException(), isNull);
    await capture(t, key, 'planner-narrow-large-text');
    await t.ensureVisible(find.text('Glute Bridge'));
    await t.pumpAndSettle();
    await capture(t, key, 'planner-narrow-cards');
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });
  testWidgets(
      'Exercise grid is two columns and hides routine metadata, with ordered instructions',
      (t) async {
    final key = GlobalKey();
    await open(t, AiContentPlannerPage(repository: planner(), onApply: openAdminAiDraft), key: key);
    await tap(t, 'Generate suggestions');
    expect(t.getTopLeft(find.text('Glute Bridge')).dy,
        t.getTopLeft(find.text('Dead Bug')).dy);
    expect(find.textContaining(RegExp(r'[0-9]+ min$')), findsNothing);
    expect(find.textContaining('Published routine:'), findsNothing);
    await t.ensureVisible(find.text('Glute Bridge'));
    await t.pumpAndSettle();
    await capture(t, key, 'exercise-grid');
    await tap(t, 'Preview details');
    expect(find.text('1. Start in a comfortable position.'), findsOneWidget);
    await capture(t, key, 'exercise-expanded');
    expect(t.takeException(), isNull);
  });
  for (final (failed, width, scale) in [
    (true, 1400.0, 1.0),
    (false, 1400.0, 1.0),
    (false, 420.0, 1.3),
    (false, 1024.0, 1.0),
    (false, 1280.0, 1.0),
    (false, 1366.0, 1.25),
    (false, 1536.0, 1.5),
  ]) {
    testWidgets(
        'Outreach search outside Top 10, goal labels and generation $failed at $width (scale $scale)',
        (t) async {
      var generations = 0, sends = 0;
      final repo = AdminAiRepository(
          organizationId: 'gainpath',
          isCurrent: () => true,
          invoke: (op, q) async {
            if (op == 'admin.ai.members') return {'members': []};
            if (op == 'admin.ai.member.search') {
              return {
                'members': [
                  {
                    'memberId': 'm13-e2e-fixture',
                    'name': 'Module 13 TEST',
                    'isTest': true,
                    'canAnalyze': true
                  }
                ]
              };
            }
            if (op == 'admin.ai.member') {
              return {
                'memberId': 'm13-e2e-fixture',
                'name': 'Module 13 TEST',
                'goals': ['increaseFlexibility', 'generalFitness'],
                'experience': 'intermediate',
                'workouts': 14,
                'completedRoutines': 0
              };
            }
            if (op == 'admin.ai.outreach.generate') {
              generations++;
              if (failed) {
                throw FirebaseFunctionsException(
                    code: 'failed-precondition',
                    message:
                        'No usable AI recommendations (invalid_candidate_id). Your member analysis is retained.');
              }
              return {
                'previewId': 'fixture-preview',
                'ai': ai,
                'availabilityNotes': [
                  'No eligible coach is currently available.'
                ],
                'recommendations': [
                  {
                    'index': 0,
                    'kind': 'content',
                    'title': 'Squat',
                    'message':
                        'Review your recent Squat practice for general training.',
                    'target': {'label': 'Squat'},
                    'why': ['Recent exercise practice.']
                  }
                ]
              };
            }
            if (op == 'admin.ai.outreach.send') sends++;
            throw StateError('Unexpected fixture operation');
          });
      final key = GlobalKey();
      await open(t, AiMemberOutreachPage(repository: repo),
          key: key, width: width, scale: scale);
      await t.enterText(find.byType(TextField).first, 'Module 13 TEST');
      final searchButton = find.byTooltip('Search members');
      await t.ensureVisible(searchButton);
      await t.tap(searchButton);
      await t.pumpAndSettle();
      await t.ensureVisible(find.byTooltip('Analyze search result'));
      await t.tap(find.byTooltip('Analyze search result'));
      await t.pumpAndSettle();
      expect(find.textContaining('Improve Flexibility'), findsWidgets);
      expect(find.textContaining('increaseFlexibility'), findsNothing);
      if (width >= 1000) {
        expect(
            t.getTopLeft(find.text('Selected member')).dx,
            lessThan(
                t.getTopLeft(find.text('Generate AI recommendations')).dx));
      }
      await capture(t, key, 'workspace-analysis-$width');
      await tap(t, 'Generate AI recommendations');
      expect(generations, 1);
      expect(sends, 0);
      expect(find.textContaining('14 workouts'), findsWidgets);
      if (failed) {
        final error = find.textContaining('invalid_candidate_id');
        expect(error, findsOneWidget);
        await t.ensureVisible(error);
        await t.pumpAndSettle();
        expect(
            t.getTopLeft(error).dy,
            greaterThan(
                t.getTopLeft(find.text('Generate AI recommendations')).dy));
      } else {
        expect(find.text('Squat'), findsWidgets);
        await t.ensureVisible(find.text('Squat').first);
        await t.pumpAndSettle();
      }
      await capture(t, key,
          failed ? 'workspace-error-$width' : 'workspace-preview-$width');
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('failed generation exits Loading and offers a retry', (t) async {
    final repo = AdminAiRepository(
        organizationId: 'gainpath',
        isCurrent: () => true,
        invoke: (op, q) async => throw StateError('offline'));
    await open(t, AiContentPlannerPage(repository: repo, onApply: openAdminAiDraft));
    await tap(t, 'Generate suggestions');
    expect(find.textContaining('could not be generated'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
