import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/calf_raise_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/guided_workout_progress.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'support/calf_raise_trajectory.dart';
import 'real_squat_session_test.dart' show Camera, FailingStore;
import 'row_workout_session_test.dart' show RowDetector;
import 'squat_processing_controller_test.dart' show AudioSink;

class CalfHarness {
  CalfHarness({int reps = 3}) {
    repo = WorkoutSessionRepository(
        scope: scope,
        store: store,
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => scope);
    session = CalfRaiseWorkoutSession(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => detector,
        audioPort: AudioSink(),
        repository: repo,
        clockMicros: () => now,
        sessionId: 'calf-reliability',
        exerciseId: 'standing-calf-raise-side-v1',
        publishedRoutineId: 'routine',
        detectorId: 'synthetic-calf',
        detectorVersion: '1',
        sets: 1,
        reps: reps,
        provenance: WorkoutProvenance.recordedFixture);
  }
  static final scope =
      SessionScope(userId: 'member', organizationId: 'gainpath');
  final camera = Camera(),
      detector = RowDetector(),
      store = FailingStore(scope: scope);
  late WorkoutSessionRepository repo;
  late CalfRaiseWorkoutSession session;
  int now = 0;
  Future<void> feed(WidgetTester tester, Iterable<PoseFrame> frames,
      {bool timers = false}) async {
    for (final f in frames) {
      now = f.capturedAtMicros + (timers ? 40000 : 0);
      detector.frame = f;
      camera.receive!(PoseInput(timestampMicros: f.capturedAtMicros));
      await tester
          .pump(timers ? const Duration(milliseconds: 50) : Duration.zero);
    }
  }

  void dispose() {
    session.dispose();
    repo.dispose();
  }
}

void main() {
  testWidgets(
      'small noisy feet through fresh raw pipeline and watchdog finish target',
      (tester) async {
    final h = CalfHarness(reps: 2);
    addTearDown(h.dispose);
    h.store.fail = false;
    await h.session.start(consented: true, setupConfirmed: true);
    for (var cycle = 0; cycle < 2; cycle++) {
      await h.feed(tester,
          calfTrajectory(start: cycle * 3550000, scale: .4, jitter: true),
          timers: true);
    }
    expect(h.session.analysis!.repetitions, 2);
    expect(h.session.guidance.stage, GuidedWorkoutStage.complete);
    final saved = (await h.session.endAndSave())!;
    expect(saved.poseMetrics!.scoringVersion, CalfRaiseAnalyzer.version);
    expect(saved.isEligibleForRealUpload, false);
    expect(await h.repo.loadHistory(), hasLength(1));
    expect(h.session.decisionDiagnostics.keys, isNot(contains('landmarks')));
  });
  testWidgets('weak foot frame shows reason and cannot bridge hidden peak',
      (tester) async {
    final h = CalfHarness();
    addTearDown(h.dispose);
    await h.session.start(consented: true, setupConfirmed: true);
    await h.feed(
        tester, calfTrajectory().where((f) => f.capturedAtMicros <= 2000000));
    await h.feed(tester, [calfPose(2050000, .12, confidence: .4)]);
    expect(h.session.analysisAvailable, false);
    expect(h.session.decisionDiagnostics['decision'], 'brief_tracking_loss');
    await h.feed(tester, [calfPose(2100000, .12)]);
    expect(h.session.movementCue, contains('restart'));
    await h.feed(
        tester, calfTrajectory().where((f) => f.capturedAtMicros > 2100000));
    expect(h.session.analysis!.repetitions, 0);
    await h.feed(tester, calfTrajectory(start: 3550000));
    expect(h.session.analysis!.repetitions, 1);
    await h.session.close();
  });
  testWidgets('manual pause survives background and resumes camera explicitly',
      (tester) async {
    final h = CalfHarness();
    addTearDown(h.dispose);
    await h.session.start(consented: true, setupConfirmed: true);
    await h.session.pause();
    await h.session.setForeground(false);
    await h.session.setForeground(true);
    expect(h.camera.starts, 1);
    await h.session.resume();
    expect(h.camera.starts, 2);
    await h.feed(tester, [calfPose(50000, 0)]);
    expect(h.session.analysis!.needsCalibration, true);
    await h.session.close();
  });
  testWidgets('background-first launch can be resumed after explicit pause',
      (tester) async {
    final h = CalfHarness();
    addTearDown(h.dispose);
    await h.session
        .start(consented: true, setupConfirmed: true, foreground: false);
    await h.session.pause();
    await h.session.setForeground(true);
    expect(h.camera.starts, 0);
    await h.session.resume();
    expect(h.camera.starts, 1);
    await h.session.close();
  });
  testWidgets('manual recalibration requires straight knee and fresh joints',
      (tester) async {
    final h = CalfHarness();
    addTearDown(h.dispose);
    await h.session.start(consented: true, setupConfirmed: true);
    h.session.beginRecalibration();
    await h.feed(tester, [calfPose(50000, 0, bent: true)]);
    expect(h.session.canConfirmRecalibration, false);
    await h.feed(tester, [calfPose(100000, 0)]);
    expect(h.session.canConfirmRecalibration, true);
    h.now += 300000;
    expect(h.session.canConfirmRecalibration, false);
    await h.session.close();
  });
}
