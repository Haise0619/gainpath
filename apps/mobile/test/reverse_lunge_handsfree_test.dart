import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'reverse_lunge_feedback_session_test.dart' show FeedbackHarness;
import 'support/reverse_lunge_trajectory.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_audio_port.dart';

void main() {
  for (final side in LungeSide.values) {
    testWidgets(
        '$side visible small ankle gap calibrates and starts hands-free',
        (tester) async {
      final h = FeedbackHarness(side, requireCameraCheck: true);
      addTearDown(h.dispose);
      await h.session.start(consented: true, setupConfirmed: true);
      for (var t = 0; t <= 4100000; t += 50000) {
        await h.feed(
            tester,
            reverseLungeFrame(t, 0, 0,
                side: side,
                neutralGapRatio: .24,
                width: 800,
                height: 800,
                translateX: .15));
      }
      expect(h.session.cameraCheckPending, false);
      for (final f in reverseLungeTrajectory(
          side: side,
          startMicros: 4150000,
          neutralGapRatio: .24,
          width: 800,
          height: 800,
          translateX: .15)) {
        await h.feed(tester, f);
      }
      expect(h.session.analysis!.repetitions, 1);
      await h.session.close();
    });
  }
  testWidgets('automatic countdown respects muted and enabled voice modes',
      (tester) async {
    for (final mode in [WorkoutVoiceMode.muted, WorkoutVoiceMode.alertsOnly]) {
      final h = FeedbackHarness(LungeSide.left, requireCameraCheck: true);
      h.session.setVoiceMode(mode, persist: false);
      await h.session.start(consented: true, setupConfirmed: true);
      for (var t = 0; t <= 4100000; t += 50000) {
        await h.feed(tester, reverseLungeFrame(t, 0, 0));
      }
      expect(h.session.cameraCheckPending, false);
      if (mode == WorkoutVoiceMode.muted) {
        expect(h.audioSink.played, isEmpty);
      } else {
        expect(h.audioSink.played.map((c) => c.id), contains('lunge_begin'));
      }
      await h.session.close();
      h.dispose();
    }
  });
  testWidgets(
      'fresh neutral hold starts hands-free after countdown without any touch',
      (tester) async {
    final h = FeedbackHarness(LungeSide.right, requireCameraCheck: true);
    addTearDown(h.dispose);
    await h.session.start(consented: true, setupConfirmed: true);
    for (var t = 0; t <= 1500000; t += 50000) {
      await h.feed(tester, reverseLungeFrame(t, 0, 0, side: LungeSide.right));
    }
    expect(h.session.cameraCheckPending, true);
    expect(h.session.startCountdownSeconds, isNotNull);
    expect(h.session.analysis!.repetitions, 0);
    for (var t = 1550000; t <= 4100000; t += 50000) {
      await h.feed(tester, reverseLungeFrame(t, 0, 0, side: LungeSide.right));
    }
    expect(h.session.cameraCheckPending, false);
    for (final f in reverseLungeTrajectory(
        side: LungeSide.right, startMicros: 4150000)) {
      await h.feed(tester, f);
    }
    expect(h.session.analysis!.repetitions, 1);
    final saved = (await h.session.endAndSave())!;
    expect(saved.poseMetrics!.lungeSide, 'right');
  });
  testWidgets(
      'missing rear ankle resets countdown; timer-only waiting never starts',
      (tester) async {
    final h = FeedbackHarness(LungeSide.left, requireCameraCheck: true);
    addTearDown(h.dispose);
    await h.session.start(consented: true, setupConfirmed: true);
    for (var t = 0; t <= 2500000; t += 50000) {
      await h.feed(tester, reverseLungeFrame(t, 0, 0));
    }
    expect(h.session.startCountdownSeconds, isNotNull);
    final f = reverseLungeFrame(2550000, 0, 0);
    await h.feed(
        tester,
        PoseFrame(
            capturedAtMicros: f.capturedAtMicros,
            detectorId: f.detectorId,
            modelVersion: f.modelVersion,
            imageWidth: f.imageWidth,
            imageHeight: f.imageHeight,
            landmarks: {...f.landmarks}..remove(PoseLandmark.rightAnkle)));
    expect(h.session.startCountdownSeconds, isNull);
    h.now = 9000000;
    await tester.pump(const Duration(seconds: 4));
    expect(h.session.cameraCheckPending, true);
    expect(h.session.analysis!.repetitions, 0);
    await h.session.close();
  });
  testWidgets(
      'side change and background cancel countdown and retain manual chosen side',
      (tester) async {
    final h = FeedbackHarness(LungeSide.left, requireCameraCheck: true);
    addTearDown(h.dispose);
    await h.session.start(consented: true, setupConfirmed: true);
    for (var t = 0; t <= 1500000; t += 50000) {
      await h.feed(tester, reverseLungeFrame(t, 0, 0));
    }
    h.session.selectCameraCheckSide(LungeSide.right);
    expect(h.session.startCountdownSeconds, isNull);
    for (var t = 1550000; t <= 3000000; t += 50000) {
      await h.feed(tester, reverseLungeFrame(t, 0, 0, side: LungeSide.right));
    }
    expect(h.session.startCountdownSeconds, isNotNull);
    await h.session.setForeground(false);
    expect(h.session.startCountdownSeconds, isNull);
    await h.session.setForeground(true);
    expect(h.session.cameraCheckPending, true);
    expect(h.session.side, LungeSide.right);
    await h.session.close();
  });
}
