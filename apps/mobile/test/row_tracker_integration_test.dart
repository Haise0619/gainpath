import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/app/routing/exercise_tracker_route.dart';
import 'package:gainpath_mobile/features/workout/domain/exercise_tracker_dispatcher.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/navigation/workout_navigation.dart';
import 'package:gainpath_pose/gainpath_pose.dart' show RowSide;
import 'package:gainpath_mobile/features/workout/presentation/member/row_setup_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'package:gainpath_mobile/app/routing/row_workout_route.dart';

PublishedRoutineExercise rowExercise() =>
    PublishedRoutine.fromDocument('row-routine', {
      'schemaVersion': 1,
      'kind': 'routine',
      'status': 'published',
      'sourceBlueprintId': 'row-blueprint',
      'title': 'Row test',
      'estimatedMinutes': 10,
      'exercises': [
        {
          'exerciseId': 'single-arm-dumbbell-row-side-v1',
          'dayNumber': 1,
          'name': 'Single-arm dumbbell row',
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
  test('exact row identity selects a dedicated installed tracker', () {
    final result = const ExerciseTrackerDispatcher().resolve(
        organizationId: 'gainpath',
        exerciseId: 'single-arm-dumbbell-row-side-v1');
    expect(result.capability.hasPoseTracking, true);
    expect(result.description, contains('row'));
  });
  test('row identity cannot be inferred by title or another organization', () {
    for (final identity in [
      ('other', 'single-arm-dumbbell-row-side-v1'),
      ('gainpath', 'Single-arm dumbbell row')
    ]) {
      expect(
          const ExerciseTrackerDispatcher()
              .resolve(organizationId: identity.$1, exerciseId: identity.$2)
              .tracker,
          isNull);
    }
  });
  testWidgets('row dispatch preserves launch and shows setup before camera',
      (tester) async {
    final launch = RealWorkoutLaunch(
        scope: SessionScope(userId: 'member', organizationId: 'gainpath'),
        routineId: 'row-routine',
        exercise: rowExercise(),
        consented: true,
        setupConfirmed: true,
        requestServerUpload: false,
        sessionId: 'pinned-row',
        returnToRoutine: true);
    await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: (context) {
          final route = ExerciseTrackerRoute(launch: launch).build(context);
          expect(route.runtimeType.toString(), 'RowWorkoutRoute');
          expect((route as RowWorkoutRoute).launch, same(launch));
          return const SizedBox();
        })));
  });
  testWidgets(
      'row arm setup is explicit, responsive and prevents duplicate starts',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var starts = 0;
    RowSide? chosen;
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: RowSetupScreen(
            exerciseName: 'Single-arm dumbbell row',
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
                find.byKey(const ValueKey('row-start-camera')))
            .onPressed,
        isNull);
    expect(find.text('45s rest between sets'), findsOneWidget);
    await tester.ensureVisible(find.text('Right arm'));
    await tester.tap(find.text('Right arm'));
    await tester.pump();
    await tester.ensureVisible(find.text('Start camera'));
    await tester.tap(find.text('Start camera'));
    await tester.pump();
    expect(starts, 1);
    expect(chosen, RowSide.right);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('row-start-camera')))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'row consent requires stable bench acknowledgement without upload',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showWorkoutCaptureConsent(context,
                        allowUpload: false,
                        onUploadChanged: (_) {},
                        exerciseInstruction: rowCaptureInstruction,
                        setupConfirmationLabel: rowSetupConfirmation),
                    child: const Text('Consent'))))));
    await tester.tap(find.text('Consent'));
    await tester.pumpAndSettle();
    expect(find.text(rowSetupConfirmation), findsOneWidget);
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
