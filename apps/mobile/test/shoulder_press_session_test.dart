import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/shoulder_press_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/guided_workout_progress.dart';
import 'package:gainpath_mobile/features/workout/application/measured_workout_session.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_result_screen.dart';
import 'support/shoulder_press_trajectory.dart';
import 'support/shoulder_press_projection.dart';
import 'real_squat_session_test.dart' show Camera, FailingStore;
import 'squat_processing_controller_test.dart' show AudioSink;
import 'row_workout_session_test.dart' show RowDetector;

class PressHarness {
  PressHarness(
      {int sets = 2,
      int reps = 1,
      String exercise = 'dumbbell-shoulder-press-front-v1'}) {
    active = scope;
    store = FailingStore(scope: scope);
    repo = WorkoutSessionRepository(
        scope: scope,
        store: store,
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => active);
    session = ShoulderPressWorkoutSession(
        scope: scope,
        activeScope: () => active,
        camera: camera,
        detectorFactory: () async => detector,
        audioPort: AudioSink(),
        repository: repo,
        clockMicros: () => now,
        sessionId: 'press-session',
        exerciseId: exercise,
        publishedRoutineId: 'press-routine',
        detectorId: 'synthetic-press',
        detectorVersion: '1',
        sets: sets,
        reps: reps,
        provenance: WorkoutProvenance.recordedFixture);
  }
  final scope =
      SessionScope(userId: 'press-member', organizationId: 'gainpath');
  late SessionScope? active;
  final camera = Camera(), detector = RowDetector();
  late FailingStore store;
  late WorkoutSessionRepository repo;
  late ShoulderPressWorkoutSession session;
  int now = 0;
  Future<void> feed(WidgetTester tester, Iterable<PoseFrame> frames) async {
    for (final f in frames) {
      now = f.capturedAtMicros;
      detector.frame = f;
      camera.receive!(PoseInput(timestampMicros: now));
      await tester.pump();
    }
  }

  void dispose() {
    session.dispose();
    repo.dispose();
  }
}

void main() {
  testWidgets(
      'fresh raw frames with latency watchdog ticks and moving projections complete authored sets',
      (tester) async {
    final h = PressHarness(sets: 1, reps: 2);
    addTearDown(h.dispose);
    h.store.fail = false;
    await h.session.start(consented: true, setupConfirmed: true);
    for (var cycle = 0; cycle < 2; cycle++) {
      final start = cycle * 3450000;
      for (final original in shoulderPressTrajectory(startMicros: start)) {
        final t = original.capturedAtMicros - start;
        final v = t < 900000
            ? 0.0
            : t < 1700000
                ? (t - 900000) / 800000
                : t < 2100000
                    ? 1.0
                    : t < 2900000
                        ? 1 - (t - 2100000) / 800000
                        : 0.0;
        final frame = pressProjection(original,
            elevation: .045 * v,
            spanScale: 1 - .27 * v,
            upperScale: 1 - .30 * v,
            forearmScale: 1 - .30 * v);
        h.now = frame.capturedAtMicros + 40000;
        h.detector.frame = frame;
        h.camera.receive!(PoseInput(timestampMicros: frame.capturedAtMicros));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
    expect(h.session.guidance.stage, GuidedWorkoutStage.complete);
    expect(h.session.analysis!.repetitions, 2);
    final saved = (await h.session.endAndSave())!;
    expect(saved.poseMetrics!.formScorePercent, isNull);
    expect(saved.isEligibleForRealUpload, false);
    expect(await h.repo.loadHistory(), hasLength(1));
    expect(h.session.decisionDiagnostics.keys, isNot(contains('landmarks')));
  });
  testWidgets(
      'brief confidence loss retains setup but never completes the interrupted rep',
      (tester) async {
    final h = PressHarness(sets: 1, reps: 1);
    addTearDown(h.dispose);
    await h.session.start(consented: true, setupConfirmed: true);
    await h.feed(tester,
        shoulderPressTrajectory().where((f) => f.capturedAtMicros <= 2000000));
    await h.feed(tester,
        [pressProjection(shoulderPressFrame(2050000, 1), confidence: .4)]);
    expect(h.session.decisionDiagnostics['decision'], 'brief_tracking_loss');
    expect(h.session.analysisAvailable, false);
    await h.feed(tester, [shoulderPressFrame(2100000, 1)]);
    expect(h.session.movementCue, contains('restart'));
    await h.feed(tester,
        shoulderPressTrajectory().where((f) => f.capturedAtMicros > 2100000));
    expect(h.session.analysis!.repetitions, 0);
    expect(h.session.guidance.stage, GuidedWorkoutStage.working);
    await h.feed(tester, shoulderPressTrajectory(startMicros: 3450000));
    expect(h.session.analysis!.repetitions, 1);
    expect(h.session.guidance.stage, GuidedWorkoutStage.complete);
    await h.session.close();
  });
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'authored targets/rest and one unscored local result survive save retry',
      (tester) async {
    final h = PressHarness();
    addTearDown(h.dispose);
    h.session.setRestSeconds(45);
    await h.session.start(consented: false, setupConfirmed: true);
    expect(h.camera.starts, 0);
    await h.session.start(consented: true, setupConfirmed: true);
    expect(h.session.preview.responsivePreview, true);
    expect(await h.session.endAndSave(), isNull);
    await h.feed(tester, shoulderPressTrajectory());
    expect(h.session.analysis!.repetitions, 1);
    expect(h.session.guidance.stage, GuidedWorkoutStage.resting);
    h.session.startNextSet(skipRest: true);
    await h.feed(tester, shoulderPressTrajectory(startMicros: h.now + 50000));
    expect(h.session.guidance.stage, GuidedWorkoutStage.complete);
    expect(await h.session.endAndSave(), isNull);
    expect(h.session.viewPhase, MeasuredWorkoutPhase.saveFailed);
    h.store.fail = false;
    final result = (await h.session.endAndSave())!;
    expect(result.repetitions, 2);
    expect(result.accuracy, 0);
    expect(result.poseMetrics!.cameraView, 'front');
    expect(result.poseMetrics!.toJson()['schemaVersion'], 4);
    expect(result.poseMetrics!.formScorePercent, isNull);
    expect(result.isEligibleForRealUpload, false);
    expect(await h.session.endAndSave(), same(result));
    expect(await h.repo.loadHistory(), hasLength(1));
    await tester.pumpWidget(
        MaterialApp(home: WorkoutResultScreen.measured(summary: result)));
    await tester.pumpAndSettle();
    expect(find.text('MEASURED SHOULDER PRESS RESULT'), findsOneWidget);
    expect(find.text('Form score is not assessed for shoulder presses'),
        findsOneWidget);
    expect(find.textContaining('front view'), findsWidgets);
    expect(find.text('MEASURED SQUAT RESULT'), findsNothing);
  });
  testWidgets(
      'pause/background resets partial cycle and account loss closes without save',
      (tester) async {
    final h = PressHarness();
    addTearDown(h.dispose);
    h.store.fail = false;
    await h.session.start(consented: true, setupConfirmed: true);
    await h.feed(tester,
        shoulderPressTrajectory().where((f) => f.capturedAtMicros <= 2100000));
    await h.session.pause();
    await h.session.setForeground(false);
    await h.session.setForeground(true);
    expect(h.session.isManuallyPaused, true);
    expect(h.camera.starts, 1);
    await h.session.resume();
    expect(h.camera.starts, 2);
    await h.feed(tester, [shoulderPressFrame(h.now + 50000, 0)]);
    expect(h.session.analysis!.repetitions, 0);
    expect(h.session.analysis!.needsCalibration, true);
    h.active = null;
    h.session.accountChanged();
    await tester.pump();
    expect(h.session.viewPhase, MeasuredWorkoutPhase.closed);
    expect(await h.session.endAndSave(), isNull);
    expect(await h.store.read(), isEmpty);
  });
  testWidgets('background-first launch needs foreground and explicit resume',
      (tester) async {
    final h = PressHarness();
    addTearDown(h.dispose);
    await h.session
        .start(consented: true, setupConfirmed: true, foreground: false);
    expect(h.camera.starts, 0);
    await h.session.pause();
    await h.session.setForeground(true);
    expect(h.camera.starts, 0);
    await h.session.resume();
    expect(h.camera.starts, 1);
    await h.session.close();
  });
  testWidgets('changed detector cannot count or silently resume',
      (tester) async {
    final h = PressHarness();
    addTearDown(h.dispose);
    await h.session.start(consented: true, setupConfirmed: true);
    final f = shoulderPressFrame(50000, 0);
    await h.feed(tester, [
      PoseFrame(
          capturedAtMicros: 50000,
          detectorId: f.detectorId,
          modelVersion: 'changed',
          landmarks: f.landmarks,
          imageWidth: f.imageWidth,
          imageHeight: f.imageHeight)
    ]);
    expect(h.session.isPaused, true);
    expect(h.session.errorMessage, contains('model changed'));
    await h.session.resume();
    expect(h.session.isPaused, true);
    expect(await h.session.endAndSave(), isNull);
    await h.session.close();
  });
  test('unregistered exercise cannot open this measured session', () {
    expect(() => PressHarness(exercise: 'Dumbbell Shoulder Press'),
        throwsArgumentError);
  });
}
