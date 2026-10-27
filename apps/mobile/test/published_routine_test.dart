import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/data/published_routine.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/routine_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/app/home/member_home_screen.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final document = <String, dynamic>{
    'schemaVersion': 1,
    'kind': 'routine',
    'status': 'published',
    'sourceBlueprintId': 'blueprint-1',
    'title': 'Strength basics',
    'estimatedMinutes': 30,
    'exercises': <Map<String, dynamic>>[
      {'exerciseId': 'squat-1', 'name': 'Squat', 'sets': 3, 'reps': 8},
    ],
  };

  test('accepts published organization content and rejects invalid records',
      () {
    final routine = PublishedRoutine.fromDocument('routine-1', document);
    expect(routine.title, 'Strength basics');
    expect(routine.exercises.single.sets, 3);
    expect(routine.exercises.single.exerciseId, 'squat-1');
    expect(routine.exercises.single.dayNumber, 1);
    expect(
        () => PublishedRoutine.fromDocument(
            'draft', {...document, 'status': 'draft'}),
        throwsFormatException);
    expect(
        () => PublishedRoutine.fromDocument('broken', {
              ...document,
              'exercises': [
                {'exerciseId': 'squat-1', 'name': 'Squat', 'sets': 0, 'reps': 8}
              ]
            }),
        throwsFormatException);
  });

  test('retains distinct catalog IDs even when display names are identical',
      () {
    final routine = PublishedRoutine.fromDocument('routine-1', {
      ...document,
      'exercises': [
        {
          'exerciseId': 'first',
          'name': 'Squat',
          'sets': 3,
          'reps': 8,
          'dayNumber': 2
        },
        {
          'exerciseId': 'second',
          'name': 'Squat',
          'sets': 2,
          'reps': 5,
          'dayNumber': 3
        },
      ],
    });
    expect(routine.exercises.map((e) => e.exerciseId), ['first', 'second']);
    expect(routine.exercises.map((e) => e.dayNumber), [2, 3]);
  });

  test('maps tutorial media by published row identity with signed query intact',
      () {
    final routine = PublishedRoutine.fromDocument('routine-1', {
      ...document,
      'exercises': [
        {
          'exerciseId': 'first',
          'name': 'Squat',
          'sets': 3,
          'reps': 8,
          'videoUrl': ' https://media.example.test/first.mp4?token=fixture '
        },
        {
          'exerciseId': 'second',
          'name': 'Squat',
          'sets': 2,
          'reps': 5,
          'videoUrl': 'https://media.example.test/second.mp4'
        },
      ],
    });
    expect((routine.exercises.first as dynamic).videoUrl,
        'https://media.example.test/first.mp4?token=fixture');
    expect((routine.exercises.last as dynamic).videoUrl,
        'https://media.example.test/second.mp4');
  });

  test('legacy and unsupported media do not invalidate workout targets', () {
    for (final media in [
      null,
      '',
      42,
      'file:///x.mp4',
      'http://media.example.test/x.mp4',
      'https://youtube.com/watch?v=x',
      'https://user:secret@media.example.test/x.mp4',
      'https://media.example.test/x.mp4#t=1',
      'https://media.example.test/x.mp4#',
      'https:///media.example.test/x.mp4',
      'https:media.example.test/x.mp4',
      r'https://media.example.test\x.mp4',
      'https://media.example.test/a\nb.mp4',
      'https://media.example.test/${'a' * 2048}.mp4'
    ]) {
      final routine = PublishedRoutine.fromDocument('routine-1', {
        ...document,
        'exercises': [
          {
            'exerciseId': 'first',
            'name': 'Squat',
            'sets': 3,
            'reps': 8,
            if (media != null) 'videoUrl': media
          },
        ],
      });
      expect((routine.exercises.single as dynamic).videoUrl, isNull);
      expect(routine.exercises.single.reps, 8);
    }
  });

  testWidgets(
      'live workout shows published content while unavailable actions respond',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final routine = PublishedRoutine.fromDocument('routine-1', document);
    final repository = InMemoryAuthRepository();
    final auth = AuthBloc(repository: repository);
    addTearDown(() async {
      await auth.close();
      await repository.dispose();
    });
    await tester.pumpWidget(BlocProvider.value(
      value: auth,
      child: MaterialApp(
        home: WorkoutPrepScreen(live: true, publishedRoutine: routine),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Strength basics'), findsOneWidget);
    await tester.tap(find.text('Start guided session'));
    await tester.pump();
    expect(find.text('This feature is currently unavailable.'), findsOneWidget);
    await tester.tap(find.text('Watch tutorial'));
    await tester.pump();
    expect(find.text('This feature is currently unavailable.'), findsOneWidget);
    await tester.tap(find.text('View routine'));
    await tester.pumpAndSettle();
    expect(find.byType(RoutineScreen), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
    await tester.tap(find.text('Squat'));
    await tester.pump();
    expect(find.text('This feature is currently unavailable.'), findsOneWidget);
  });

  testWidgets('Firebase member Home displays its published routine',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final routine = PublishedRoutine.fromDocument('routine-1', document);
    final profile = FitnessProfile(
      gender: ProfileGender.unspecified,
      age: 25,
      heightCm: 170,
      weightKg: 65,
      experience: TrainingExperience.beginner,
      activity: ActivityLevel.lightlyActive,
      goals: {FitnessGoal.generalFitness},
    );
    await tester.pumpWidget(MaterialApp(
      home: MemberHomeScreen(
        liveSession: const AuthSession(
          email: 'member@example.test',
          role: AppRole.member,
        ),
        liveProfile: profile,
        publishedRoutine: routine,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Strength basics'), findsOneWidget);
    expect(find.text('1 exercises  ·  about 30 min'), findsOneWidget);
  });
}
