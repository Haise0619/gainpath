import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/app/routing/exercise_tracker_route.dart';
import 'package:gainpath_mobile/app/routing/lateral_raise_workout_route.dart';
import 'package:gainpath_mobile/features/workout/domain/exercise_tracker_dispatcher.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/lateral_raise_setup_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/widgets/workout_alignment_guide.dart';
import 'package:gainpath_mobile/navigation/workout_navigation.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';

void main() {
  testWidgets(
      'compact double-text recalibration remains scrollable without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: Center(
                child: SizedBox(
                    height: 382,
                    child: WorkoutAlignmentGuide(
                        canConfirm: false,
                        onConfirm: () {},
                        instruction:
                            'Face front with both shoulders, elbows, wrists and hips visible. Leave space on both sides for raised arms. Drag the outline or adjust its width.'))))));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Move fully into view'));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'lateral raise recalibration displays front instruction without side-on copy',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: WorkoutAlignmentGuide(
                canConfirm: false,
                onConfirm: () {},
                instruction: lateralRaiseSetupConfirmation))));
    expect(find.text(lateralRaiseSetupConfirmation), findsOneWidget);
    expect(find.textContaining('Stand side-on'), findsNothing);
  });
  testWidgets(
      'lateral raise consent requires front setup acknowledgement and offers no upload',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showWorkoutCaptureConsent(context,
                        allowUpload: false,
                        onUploadChanged: (_) {},
                        exerciseInstruction: lateralRaiseCaptureInstruction,
                        setupConfirmationLabel: lateralRaiseSetupConfirmation),
                    child: const Text('Consent'))))));
    await tester.tap(find.text('Consent'));
    await tester.pumpAndSettle();
    expect(find.text(lateralRaiseCaptureInstruction), findsOneWidget);
    expect(find.text(lateralRaiseSetupConfirmation), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
  });
  test('dispatcher matches only installed exact front-view lateral raise', () {
    final r = const ExerciseTrackerDispatcher().resolve(
        organizationId: 'gainpath',
        exerciseId: 'standing-lateral-raise-front-v1');
    expect(r.tracker, ExerciseTracker.frontViewLateralRaise);
    expect(r.capability.cameraView, 'front');
    final held = const ExerciseTrackerDispatcher(availableTrackers: {}).resolve(
        organizationId: 'gainpath',
        exerciseId: 'standing-lateral-raise-front-v1');
    expect(held.unavailable, true);
    expect(held.capability.hasPoseTracking, false);
  });
  testWidgets('route preserves exact launch and opens setup before camera',
      (tester) async {
    final e = PublishedRoutine.fromDocument('lateral-routine', {
      'schemaVersion': 1,
      'kind': 'routine',
      'status': 'published',
      'sourceBlueprintId': 'lateral-blueprint',
      'title': 'Lateral test',
      'estimatedMinutes': 10,
      'exercises': [
        {
          'exerciseId': 'standing-lateral-raise-front-v1',
          'dayNumber': 1,
          'name': 'Standing Lateral Raise',
          'category': 'Push',
          'sets': 2,
          'reps': 7,
          'restSeconds': 45,
          'cue': 'Raise together',
          'imageUrl': '',
          'muscleGroup': 'Shoulders',
          'videoUrl': ''
        }
      ]
    }).exercises.single;
    final launch = RealWorkoutLaunch(
        scope: SessionScope(userId: 'member', organizationId: 'gainpath'),
        routineId: 'lateral-routine',
        exercise: e,
        consented: true,
        setupConfirmed: true,
        requestServerUpload: false,
        sessionId: 'pinned-lateral',
        returnToRoutine: true);
    await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: (context) {
          final route = ExerciseTrackerRoute(launch: launch).build(context);
          expect(route, isA<LateralRaiseWorkoutRoute>());
          expect((route as LateralRaiseWorkoutRoute).launch, same(launch));
          return const SizedBox();
        })));
    await tester.pumpWidget(
        MaterialApp(home: LateralRaiseWorkoutRoute(launch: launch)));
    expect(find.byType(LateralRaiseSetupScreen), findsOneWidget);
  });
  testWidgets('320px double-text setup wraps and prevents duplicate starts',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var starts = 0;
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: LateralRaiseSetupScreen(
            exerciseName: 'Standing Lateral Raise',
            sets: 2,
            reps: 7,
            restSeconds: 45,
            onStart: () => starts++)));
    expect(find.text('2 sets · 7 reps per set · both arms together'),
        findsOneWidget);
    expect(find.text('45s rest between sets'), findsOneWidget);
    await tester.ensureVisible(find.text('Start camera'));
    await tester.tap(find.text('Start camera'));
    await tester.pump();
    expect(starts, 1);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('lateral-raise-start-camera')))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });
}
