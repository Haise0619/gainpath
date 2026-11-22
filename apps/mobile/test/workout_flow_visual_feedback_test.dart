import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/application/between_exercise_rest_controller.dart';
import 'package:gainpath_mobile/features/workout/application/measured_workout_session.dart';
import 'package:gainpath_mobile/features/workout/domain/curl_arm_metrics.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/between_exercise_rest_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/widgets/workout_exercise_image.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/real_workout_view.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/widgets/workout_tracking_feedback.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'support/workout_visual_feedback_fixture.dart';

const nextExercise = PublishedRoutineExercise(
    exerciseId: 'F3b8xIr8ynBDd3gEICKX',
    dayNumber: 1,
    name: 'Bodyweight squat',
    category: 'Lower body',
    sets: 3,
    reps: 8,
    cue: '',
    imageUrl: 'assets/images/workout_hub_fallback.png',
    muscleGroup: 'Legs');

void main() {
  testWidgets(
      'rest headings remain readable with the sparse GainPath text theme',
      (tester) async {
    final c = BetweenExerciseRestController(
        duration: const Duration(seconds: 30),
        monotonicNow: () => Duration.zero,
        canAdvance: () => true,
        onReady: () async {});
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData().copyWith(
            textTheme: const TextTheme(
                titleMedium: TextStyle(color: Colors.black),
                headlineMedium: TextStyle(color: Colors.black),
                labelLarge: TextStyle(color: Colors.black))),
        home: BetweenExerciseRestScreen(
            controller: c,
            previousExercise: 'Burpee',
            upcomingExercise: nextExercise,
            organizationId: 'gainpath',
            onViewRoutine: () {})));
    for (final label in ['Burpee complete', 'Take a breath', 'AI Tracked']) {
      expect(tester.widget<Text>(find.text(label)).style?.color,
          isNot(Colors.white),
          reason: label);
    }
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('rest progress decreases, freezes on pause and keeps next cover',
      (tester) async {
    var now = Duration.zero;
    final c = BetweenExerciseRestController(
        duration: const Duration(seconds: 30),
        monotonicNow: () => now,
        canAdvance: () => true,
        onReady: () async {});
    await tester.pumpWidget(MaterialApp(
        home: BetweenExerciseRestScreen(
            controller: c,
            previousExercise: 'Burpee',
            upcomingExercise: nextExercise,
            organizationId: 'gainpath',
            onViewRoutine: () {})));
    expect(find.byType(WorkoutExerciseImage), findsOneWidget);
    expect(
        tester
            .widget<WorkoutExerciseImage>(find.byType(WorkoutExerciseImage))
            .url,
        nextExercise.imageUrl);
    expect(
        tester
            .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator))
            .value,
        1);
    now = const Duration(seconds: 15);
    await c.tick();
    await tester.pumpAndSettle();
    expect(find.text('00:15'), findsOneWidget);
    expect(
        tester
            .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator))
            .value,
        .5);
    await tester.tap(find.text('Pause Workout'));
    now = const Duration(seconds: 25);
    await c.tick();
    await tester.pumpAndSettle();
    expect(find.text('00:15'), findsOneWidget);
    expect(
        tester
            .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator))
            .value,
        .5);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  Future<VisualFeedbackSession> mount(WidgetTester tester,
      {bool reduced = false}) async {
    final c = VisualFeedbackSession();
    await c.start(consented: true, setupConfirmed: true);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!),
        home: RealWorkoutView(
            session: c,
            viewport: const ColoredBox(
                key: ValueKey('stable-preview'), color: Colors.black),
            exerciseName: 'Squat',
            targetRepetitions: 8)));
    return c;
  }

  Future<void> close(WidgetTester tester, VisualFeedbackSession c) async {
    await tester.pumpWidget(const SizedBox());
    await c.close();
    c.dispose();
  }

  testWidgets(
      'Ready waits for calibration, shows once, and reps confirm only increases',
      (tester) async {
    final c = await mount(tester);
    c.update(calibrating: true);
    await tester.pump();
    expect(find.text('Ready'), findsNothing);
    c.update();
    await tester.pump();
    expect(find.text('Ready'), findsOneWidget);
    final camera = tester.element(find.byKey(const ValueKey('stable-preview')));
    await tester.pump(const Duration(milliseconds: 1000));
    c.update();
    await tester.pump();
    expect(find.text('Ready'), findsNothing);
    c.update(reps: 1);
    await tester.pump();
    expect(find.text('Rep Counted'), findsOneWidget);
    expect(tester.element(find.byKey(const ValueKey('stable-preview'))),
        same(camera));
    await tester.pump(const Duration(milliseconds: 800));
    c.update(reps: 1);
    await tester.pump();
    expect(find.text('Rep Counted'), findsNothing);
    c.update(reps: 2);
    await tester.pump();
    expect(find.text('Rep Counted'), findsOneWidget);
    c.update(reps: 2, health: TrackingStatus.lost);
    await tester.pump();
    expect(find.text('Rep Counted'), findsNothing);
    c.update(reps: 2);
    await tester.pump();
    expect(find.text('Ready'), findsNothing);
    expect(find.text('Rep Counted'), findsNothing);
    await close(tester, c);
  });

  testWidgets('pause clears feedback and reduced motion still confirms a rep',
      (tester) async {
    final c = await mount(tester, reduced: true);
    c.update();
    await tester.pump();
    expect(find.text('Ready'), findsOneWidget);
    await c.pause();
    await tester.pump();
    expect(find.text('Ready'), findsNothing);
    await c.resume();
    c.update();
    await tester.pump();
    c.update(reps: 1);
    await tester.pump();
    expect(find.text('Rep Counted'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Rep Counted'), findsNothing);
    expect(tester.takeException(), isNull);
    await close(tester, c);
  });

  testWidgets('last rep is confirmed and the next set gets its own Ready',
      (tester) async {
    final c = await mount(tester);
    c.update();
    await tester.pumpAndSettle();
    c.update(reps: 8);
    await tester.pump();
    final overlay = find.byType(WorkoutTrackingFeedback);
    expect(
        find.descendant(of: overlay, matching: find.text('8')), findsOneWidget);
    expect(find.text('Rep Counted'), findsOneWidget);
    await tester.pumpAndSettle();
    c.guidance!.startNextSet(nowMicros: 100000, skipRest: true);
    c.update(reps: 8);
    await tester.pump();
    expect(find.text('Ready'), findsOneWidget);
    c.update(reps: 9);
    await tester.pump();
    expect(
        find.descendant(of: overlay, matching: find.text('1')), findsOneWidget);
    await close(tester, c);
  });

  testWidgets(
      'accepted final rep survives automatic rest clearing live analysis',
      (tester) async {
    final c = await mount(tester);
    c.update(reps: 7);
    await tester.pumpAndSettle();
    c.update(
        reps: 8,
        available: false,
        rest: true,
        calibrating: true,
        health: TrackingStatus.degraded);
    await tester.pump();
    expect(find.text('Rep Counted'), findsOneWidget);
    c.update(
        reps: 8,
        available: false,
        rest: true,
        calibrating: true,
        health: TrackingStatus.degraded);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Rep Counted'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 550));
    expect(find.text('Rep Counted'), findsNothing);
    await close(tester, c);
  });

  testWidgets(
      'both-arm feedback uses current-arm reps including arm completion',
      (tester) async {
    final c = _BothArmSession();
    await c.start(consented: true, setupConfirmed: true);
    await tester
        .pumpWidget(MaterialApp(home: WorkoutTrackingFeedback(session: c)));
    c.update(guidedReps: 0);
    await tester.pumpAndSettle();
    c.armReps = 1;
    c.update(reps: 1, guidedReps: 0);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    c.armReps = 8;
    c.switchPending = true;
    c.update(
        reps: 8,
        guidedReps: 4,
        calibrating: true,
        health: TrackingStatus.degraded);
    await tester.pump();
    expect(find.text('8'), findsOneWidget);
    c.switchPending = false;
    c.rightArm = true;
    c.armReps = 0;
    c.update(reps: 8, guidedReps: 4);
    await tester.pump();
    expect(find.text('Ready'), findsOneWidget);
    c.armReps = 1;
    c.update(reps: 9, guidedReps: 4);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    await close(tester, c);
  });

  testWidgets('background dismisses feedback without replaying historical reps',
      (tester) async {
    final c = await mount(tester);
    c.update();
    await tester.pumpAndSettle();
    c.update(reps: 1);
    await tester.pump();
    expect(find.text('Rep Counted'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Rep Counted'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    c.update(reps: 1);
    await tester.pump();
    expect(find.text('Rep Counted'), findsNothing);
    expect(find.text('Ready'), findsNothing);
    await close(tester, c);
  });

  testWidgets(
      'new session does not animate its existing count or retain old listeners',
      (tester) async {
    final first = VisualFeedbackSession();
    await first.start(consented: true, setupConfirmed: true);
    first.update(reps: 4);
    Widget view(VisualFeedbackSession c) =>
        MaterialApp(home: Scaffold(body: WorkoutTrackingFeedback(session: c)));
    await tester.pumpWidget(view(first));
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Rep Counted'), findsNothing);
    final second = VisualFeedbackSession();
    await first.close();
    await second.start(consented: true, setupConfirmed: true);
    await tester.pumpWidget(view(second));
    expect(find.text('Ready'), findsNothing);
    first.update(reps: 5);
    await tester.pump();
    expect(find.text('Rep Counted'), findsNothing);
    second.update();
    await tester.pump();
    expect(find.text('Ready'), findsOneWidget);
    second.update(reps: 1);
    await tester.pump();
    expect(find.text('Rep Counted'), findsOneWidget);
    await close(tester, second);
    first.dispose();
  });

  testWidgets('feedback animation frames never rebuild the camera viewport',
      (tester) async {
    final c = VisualFeedbackSession();
    await c.start(consented: true, setupConfirmed: true);
    var viewportBuilds = 0;
    await tester.pumpWidget(MaterialApp(
        home: RealWorkoutView(
            session: c,
            viewport: Builder(builder: (_) {
              viewportBuilds++;
              return const ColoredBox(color: Colors.black);
            }),
            exerciseName: 'Squat',
            targetRepetitions: 8)));
    c.update();
    await tester.pump();
    final before = viewportBuilds;
    for (var i = 0; i < 55; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(viewportBuilds, before);
    c.update(reps: 1);
    await tester.pump();
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(viewportBuilds, before);
    await close(tester, c);
  });
}

class _BothArmSession extends VisualFeedbackSession
    implements UnilateralWorkoutSession {
  int armReps = 0;
  bool rightArm = false, switchPending = false;
  @override
  String get armLabel => rightArm ? 'Right arm' : 'Left arm';
  @override
  String get nextArmLabel => rightArm ? 'Left arm' : 'Right arm';
  @override
  String get armRepetitionLabel => '$armReps / 8';
  @override
  bool get awaitingArmSwitch => switchPending;
  @override
  void confirmArmSwitch() {}
  @override
  CurlArmMetrics get armMetrics => CurlArmMetrics(
      mode: CurlArmMode.both,
      targetSets: 3,
      repetitionsPerArm: 8,
      completedSets: 0,
      left: CurlArmResult(
          repetitions: 0, partialRepetitions: 0, formScorePercent: null),
      right: CurlArmResult(
          repetitions: 0, partialRepetitions: 0, formScorePercent: null));
}
