import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/application/real_squat_session_controller.dart';
import 'package:gainpath_mobile/features/workout/application/squat_processing_controller.dart';
import 'package:gainpath_mobile/features/workout/application/workout_audio_controller.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'real_squat_session_test.dart' show Camera, Detector;
import 'squat_processing_controller_test.dart' show frame, AudioSink;
import 'workout_audio_controller_test.dart' show PreparingAudio;

void main() {
  testWidgets('squat starts with smooth display independently of raw analysis',
      (tester) async {
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    final repo = WorkoutSessionRepository(
        scope: scope,
        store: InMemoryWorkoutSessionStore(scope: scope),
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => scope);
    final c = RealSquatSessionController(
        scope: scope,
        activeScope: () => scope,
        camera: Camera(),
        detectorFactory: () async => Detector(),
        audioPort: AudioSink(),
        repository: repo,
        clockMicros: () => 0,
        sessionId: 'preview',
        exerciseId: 'squat',
        publishedRoutineId: 'routine',
        detectorId: 'fixture',
        detectorVersion: '1');
    expect(c.preview.responsivePreview, false);
    await c.close();
    c.dispose();
    repo.dispose();
  });
  test(
      'display filter reduces stationary jitter without hiding movement or confidence',
      () {
    final filter = PoseFrameFilter(minCutoff: 3, beta: .3);
    final base = frame(0, 175), hip = base.landmarks[PoseLandmark.leftHip]!;
    PoseFrame input(int t, double dx) => PoseFrame(
            capturedAtMicros: t,
            detectorId: base.detectorId,
            modelVersion: base.modelVersion,
            imageWidth: base.imageWidth,
            imageHeight: base.imageHeight,
            landmarks: {
              ...base.landmarks,
              PoseLandmark.leftHip: PosePoint(
                  x: hip.x + dx,
                  y: hip.y,
                  z: hip.z,
                  visibility: hip.visibility,
                  presence: hip.presence)
            });
    var rawError = 0.0, filteredError = 0.0;
    for (var i = 0; i < 40; i++) {
      final dx = i.isEven ? .01 : -.01;
      final result = filter.filter(input((i + 1) * 100000, dx));
      if (i >= 5) {
        rawError += dx.abs();
        filteredError +=
            (result.landmarks[PoseLandmark.leftHip]!.x - hip.x).abs();
      }
    }
    final moving = filter.filter(input(4100000, .1));
    final response = (moving.landmarks[PoseLandmark.leftHip]!.x - hip.x) / .1;
    expect(filteredError / rawError, lessThan(.7));
    expect(response, greaterThan(.6));
    expect(moving.capturedAtMicros, 4100000);
    expect(moving.landmarks[PoseLandmark.leftHip]!.visibility, hip.visibility);
    debugPrint(
        'SQUAT_ANALYTIC_DISPLAY jitterRatio=${filteredError / rawError} first100msStepFraction=$response; synthetic only');
  });
  for (final shallow in [false, true]) {
    testWidgets(
        'squat outcome shallow=$shallow survives subsequent cue-free accepted frames during warmup',
        (tester) async {
      final port = PreparingAudio(),
          scope = SessionScope(userId: 'member', organizationId: 'gainpath');
      var now = 0;
      final audio = WorkoutAudioController(port: port)..setVoiceEnabled(true);
      final c = SquatProcessingController(
          scope: scope,
          activeScope: () => scope,
          audio: audio,
          clockMicros: () => now,
          sideViewConfirmed: true,
          uprightCameraConfirmed: true);
      final bottom = shallow ? 120.0 : 75.0;
      final angles = [
        ...List<double>.filled(12, 175),
        for (var i = 1; i <= 20; i++) 175 + (bottom - 175) * i / 20,
        ...List<double>.filled(8, bottom),
        for (var i = 1; i <= 20; i++) bottom + (175 - bottom) * i / 20,
        ...List<double>.filled(12, 175)
      ];
      var completed = false;
      for (final angle in angles) {
        now += 100000;
        final u = c.consumeRefined(frame(now, angle));
        await tester.pump();
        if (u?.completedAttempt != null) {
          completed = true;
          break;
        }
      }
      expect(completed, true);
      for (var i = 0; i < 2; i++) {
        now += 100000;
        c.consumeRefined(frame(now, 175));
        await tester.pump();
      }
      port.ready.complete(true);
      await tester.pump();
      expect(
          port.played.map((x) => x.text),
          contains(shallow
              ? 'Lower a little more on the next squat.'
              : 'Good repetition.'));
      expect(
          port.played
              .where((x) => x.id == (shallow ? 'squat_depth' : 'squat_rep'))
              .length,
          1);
      await c.close();
      c.dispose();
    });
  }
}
