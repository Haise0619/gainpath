import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/app/routing/exercise_tracker_route.dart';
import 'package:gainpath_mobile/features/workout/domain/exercise_tracker_dispatcher.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/navigation/workout_navigation.dart';
import 'package:gainpath_pose/gainpath_pose.dart' show LungeSide;
import 'package:gainpath_mobile/features/workout/presentation/member/reverse_lunge_setup_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'package:gainpath_mobile/app/routing/reverse_lunge_workout_route.dart';

PublishedRoutineExercise lungeExercise() =>
    PublishedRoutine.fromDocument('lunge-routine', {
      'schemaVersion': 1,
      'kind': 'routine',
      'status': 'published',
      'sourceBlueprintId': 'lunge-blueprint',
      'title': 'Lunge test',
      'estimatedMinutes': 10,
      'exercises': [
        {
          'exerciseId': 'bodyweight-reverse-lunge-side-v1',
          'dayNumber': 1,
          'name': 'Bodyweight Reverse Lunge',
          'category': 'Pull',
          'sets': 2,
          'reps': 7,
          'restSeconds': 45,
          'cue': 'Pull with control',
          'imageUrl': '',
          'muscleGroup': 'Back',
          'videoUrl': ''
        }
      ]
    }).exercises.single;

void main() {
  test('exact lunge identity selects a dedicated installed tracker', () {
    final result = const ExerciseTrackerDispatcher().resolve(
        organizationId: 'gainpath',
        exerciseId: 'bodyweight-reverse-lunge-side-v1');
    expect(result.capability.hasPoseTracking, true);
    expect(result.description, contains('front leg'));
  });
  test('lunge identity cannot be inferred by title or another organization',
      () {
    for (final identity in [
      ('other', 'bodyweight-reverse-lunge-side-v1'),
      ('gainpath', 'Bodyweight Reverse Lunge')
    ]) {
      expect(
          const ExerciseTrackerDispatcher()
              .resolve(organizationId: identity.$1, exerciseId: identity.$2)
              .tracker,
          isNull);
    }
  });
  testWidgets('lunge dispatch preserves launch and shows setup before camera',
      (tester) async {
    final launch = RealWorkoutLaunch(
        scope: SessionScope(userId: 'member', organizationId: 'gainpath'),
        routineId: 'lunge-routine',
        exercise: lungeExercise(),
        consented: true,
        setupConfirmed: true,
        requestServerUpload: false,
        sessionId: 'pinned-lunge',
        returnToRoutine: true);
    await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: (context) {
          final route = ExerciseTrackerRoute(launch: launch).build(context);
          expect(route.runtimeType.toString(), 'ReverseLungeWorkoutRoute');
          expect((route as ReverseLungeWorkoutRoute).launch, same(launch));
          return const SizedBox();
        })));
  });
  testWidgets(
      'lunge front-leg setup is explicit, responsive and prevents duplicate starts',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var starts = 0;
    LungeSide? chosen;
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: ReverseLungeSetupScreen(
            exerciseName: 'Bodyweight Reverse Lunge',
            sets: 2,
            reps: 7,
            restSeconds: 45,
            onStart: (side) {
              chosen = side;
              starts++;
            })));
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('reverse-lunge-start-camera')))
            .onPressed,
        isNull);
    expect(find.text('45s rest between sets'), findsOneWidget);
    expect(find.textContaining('camera on the side of the selected front leg'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Right front leg'));
    await tester.tap(find.text('Right front leg'));
    await tester.pump();
    await tester.ensureVisible(find.text('Start camera'));
    await tester.tap(find.text('Start camera'));
    await tester.pump();
    expect(starts, 1);
    expect(chosen, LungeSide.right);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('reverse-lunge-start-camera')))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'lunge consent requires stable phone and both legs acknowledgement without upload',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showWorkoutCaptureConsent(context,
                        allowUpload: false,
                        onUploadChanged: (_) {},
                        exerciseInstruction: reverseLungeCaptureInstruction,
                        setupConfirmationLabel: reverseLungeSetupConfirmation),
                    child: const Text('Consent'))))));
    await tester.tap(find.text('Consent'));
    await tester.pumpAndSettle();
    expect(find.text(reverseLungeSetupConfirmation), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Accept and start'))
            .onPressed,
        isNull);
    expect(find.text('Also allow this measured summary to be uploaded.'),
        findsNothing);
  });
}
