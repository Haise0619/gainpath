import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/reverse_lunge_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/guided_workout_progress.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'support/reverse_lunge_trajectory.dart';
import 'real_squat_session_test.dart' show Camera, FailingStore;
import 'reverse_lunge_session_test.dart' show LungeDetector;
import 'squat_processing_controller_test.dart' show AudioSink;

class FeedbackHarness {
  FeedbackHarness(LungeSide side,
      {bool requireCameraCheck = false, Camera? source})
      : camera = source ?? Camera() {
    repo = WorkoutSessionRepository(
        scope: scope,
        store: store,
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => scope);
    session = ReverseLungeWorkoutSession(
        scope: scope,
        side: side,
        requireCameraCheck: requireCameraCheck,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => detector,
        audioPort: audioSink,
        repository: repo,
        clockMicros: () => now,
        sessionId: 'feedback',
        exerciseId: 'bodyweight-reverse-lunge-side-v1',
        publishedRoutineId: 'routine',
        detectorId: 'synthetic-reverse-lunge',
        detectorVersion: '1',
        sets: 1,
        reps: 1,
        provenance: WorkoutProvenance.recordedFixture);
  }
  static final scope =
      SessionScope(userId: 'member', organizationId: 'gainpath');
  final Camera camera;
  final audioSink = AudioSink();
  final detector = LungeDetector(),
      store = FailingStore(scope: scope)..fail = false;
  late WorkoutSessionRepository repo;
  late ReverseLungeWorkoutSession session;
  int now = 0;
  Future<void> feed(WidgetTester tester, PoseFrame f) async {
    now = f.capturedAtMicros + 40000;
    detector.frame = f;
    camera.receive!(PoseInput(timestampMicros: f.capturedAtMicros));
    await tester.pump(const Duration(milliseconds: 50));
  }

  void dispose() {
    session.dispose();
    repo.dispose();
  }
}

PoseFrame hideRear(PoseFrame f, LungeSide side) => PoseFrame(
        capturedAtMicros: f.capturedAtMicros,
        detectorId: f.detectorId,
        modelVersion: f.modelVersion,
        imageWidth: f.imageWidth,
        imageHeight: f.imageHeight,
        landmarks: {
          for (final e in f.landmarks.entries)
            if (!(side == LungeSide.left
                    ? {
                        PoseLandmark.rightHeel,
                        PoseLandmark.rightKnee,
                        PoseLandmark.rightFootIndex,
                        PoseLandmark.rightShoulder
                      }
                    : {
                        PoseLandmark.leftHeel,
                        PoseLandmark.leftKnee,
                        PoseLandmark.leftFootIndex,
                        PoseLandmark.leftShoulder
                      })
                .contains(e.key))
              e.key: e.value
        });
void main() {
  testWidgets(
      'overlapping step and descent completes through fresh camera pipeline',
      (tester) async {
    final h = FeedbackHarness(LungeSide.left);
    addTearDown(h.dispose);
    await h.session.start(consented: true, setupConfirmed: true);
    for (var t = 0; t <= 4700000; t += 50000) {
      final v = t < 1200000
          ? 0.0
          : t < 2400000
              ? (t - 1200000) / 1200000
              : t < 2800000
                  ? 1.0
                  : t < 4000000
                      ? 1 - (t - 2800000) / 1200000
                      : 0.0;
      await h.feed(tester, reverseLungeFrame(t, v, v));
    }
    expect(h.session.analysis!.repetitions, 1);
    expect(h.session.guidance.stage, GuidedWorkoutStage.complete);
    await h.session.close();
  });
  testWidgets(
      'one weak setup frame pauses fresh evidence then recovers without a rep',
      (tester) async {
    final h = FeedbackHarness(LungeSide.left);
    addTearDown(h.dispose);
    await h.session.start(consented: true, setupConfirmed: true);
    for (var t = 0; t <= 500000; t += 50000) {
      await h.feed(tester, reverseLungeFrame(t, 0, 0));
    }
    final before = h.session.calibrationCue;
    final f = reverseLungeFrame(550000, 0, 0);
    await h.feed(
        tester,
        PoseFrame(
            capturedAtMicros: f.capturedAtMicros,
            detectorId: f.detectorId,
            modelVersion: f.modelVersion,
            imageWidth: f.imageWidth,
            imageHeight: f.imageHeight,
            landmarks: {...f.landmarks}..remove(PoseLandmark.leftHeel)));
    expect(h.session.analysis!.needsCalibration, true);
    expect(h.session.analysis!.repetitions, 0);
    expect(before, contains('%'));
    for (var t = 600000; t <= 1300000; t += 50000) {
      await h.feed(tester, reverseLungeFrame(t, 0, 0));
    }
    expect(h.session.analysis!.needsCalibration, false);
    expect(h.session.analysis!.repetitions, 0);
    await h.session.close();
  });
  for (final side in LungeSide.values) {
    testWidgets(
        '$side optional hidden rear foot does not block raw camera setup/count/save',
        (tester) async {
      final h = FeedbackHarness(side);
      addTearDown(h.dispose);
      await h.session.start(consented: true, setupConfirmed: true);
      for (final f in reverseLungeTrajectory(side: side)) {
        await h.feed(tester, hideRear(f, side));
      }
      expect(h.session.analysis!.repetitions, 1);
      expect(h.session.guidance.stage, GuidedWorkoutStage.complete);
      final saved = (await h.session.endAndSave())!;
      expect(saved.poseMetrics!.lungeSide, side.name);
      expect(saved.isEligibleForRealUpload, false);
      expect(await h.repo.loadHistory(), hasLength(1));
    });
  }
  testWidgets('missing required selected heel names heel and remains uncounted',
      (tester) async {
    final h = FeedbackHarness(LungeSide.left);
    addTearDown(h.dispose);
    await h.session.start(consented: true, setupConfirmed: true);
    final f = reverseLungeFrame(50000, 0, 0);
    await h.feed(
        tester,
        PoseFrame(
            capturedAtMicros: f.capturedAtMicros,
            detectorId: f.detectorId,
            modelVersion: f.modelVersion,
            imageWidth: f.imageWidth,
            imageHeight: f.imageHeight,
            landmarks: {...f.landmarks}..remove(PoseLandmark.leftHeel)));
    expect(h.session.calibrationCue.toLowerCase(), contains('heel'));
    expect(h.session.analysis!.repetitions, 0);
    expect(h.session.decisionDiagnostics['reason'], isNotNull);
    await h.session.close();
  });
}
