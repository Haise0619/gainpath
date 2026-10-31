import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/guided_workout_progress.dart';
import 'calf_raise_reliability_session_test.dart' show CalfHarness;
import 'support/calf_raise_foot_arc.dart';
import 'support/calf_raise_trajectory.dart';

void main() {
  for (final side in CalfSide.values) {
    for (final facingLeft in [false, true]) {
      testWidgets(
          '$side facingLeft=$facingLeft foot arc completes via fresh camera pipeline',
          (tester) async {
        final h = CalfHarness(reps: 1);
        addTearDown(h.dispose);
        h.store.fail = false;
        await h.session.start(consented: true, setupConfirmed: true);
        await h.feed(
            tester, calfArcTrajectory(side: side, facingLeft: facingLeft),
            timers: true);
        expect(h.session.analysis!.repetitions, 1);
        expect(h.session.guidance.stage, GuidedWorkoutStage.complete);
        final saved = (await h.session.endAndSave())!;
        expect(saved.repetitions, 1);
        expect(saved.poseMetrics!.scoringVersion, CalfRaiseAnalyzer.version);
        expect(saved.isEligibleForRealUpload, false);
        expect(await h.repo.loadHistory(), hasLength(1));
      });
    }
  }
  testWidgets(
      'neutral jitter accepted by setup also completes held return in session',
      (tester) async {
    final h = CalfHarness(reps: 1);
    addTearDown(h.dispose);
    await h.session.start(consented: true, setupConfirmed: true);
    await h.feed(
        tester,
        calfArcTrajectory(
            toeArc: false, shinProjection: false, heelNoise: .008),
        timers: true);
    expect(h.session.analysis!.repetitions, 1);
    expect(h.session.guidance.stage, GuidedWorkoutStage.complete);
    await h.session.close();
  });
  testWidgets('a real step stays uncounted and exposes persistent reset reason',
      (tester) async {
    final h = CalfHarness();
    addTearDown(h.dispose);
    await h.session.start(consented: true, setupConfirmed: true);
    await h.feed(
        tester, calfTrajectory().where((f) => f.capturedAtMicros <= 1000000));
    await h.feed(
        tester, [calfPose(1050000, .12, toeJitter: .05), calfPose(1100000, 0)]);
    expect(h.session.analysis!.repetitions, 0);
    expect(h.session.calibrationCue, contains('Foot position changed'));
    expect(
        h.session.decisionDiagnostics['resetReason'], 'Foot position changed');
    expect(h.session.decisionDiagnostics.keys, isNot(contains('landmarks')));
    await h.session.close();
  });
}
