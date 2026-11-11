import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/application/calf_raise_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/curl_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/floor_push_up_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/guided_workout_progress.dart';
import 'package:gainpath_mobile/features/workout/application/lateral_raise_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/measured_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/real_squat_session_controller.dart';
import 'package:gainpath_mobile/features/workout/application/shoulder_press_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/workout_preferences_controller.dart';
import 'package:gainpath_mobile/features/workout/application/workout_set_continuation.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/curl_arm_metrics.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

import 'real_squat_session_test.dart' show Camera, FailingStore;
import 'retained_voice_boundary_test.dart' show trajectory;
import 'row_workout_session_test.dart' show RowDetector;
import 'shoulder_press_session_test.dart' show PressHarness;
import 'squat_processing_controller_test.dart' show AudioSink;
import 'support/shoulder_press_trajectory.dart';

final _constructors = <String, Function>{
  'squat': RealSquatSessionController.new,
  'curl': CurlWorkoutSession.new,
  'calf': CalfRaiseWorkoutSession.new,
  'floor': FloorPushUpWorkoutSession.new,
  'lateral': LateralRaiseWorkoutSession.new,
  'press': ShoulderPressWorkoutSession.new,
};
const _exerciseIds = {
  'squat': 'F3b8xIr8ynBDd3gEICKX',
  'curl': 'standing-single-arm-curl-side-v1',
  'calf': 'standing-calf-raise-side-v1',
  'floor': 'standard-floor-push-up-side-v1',
  'lateral': 'standing-lateral-raise-front-v1',
  'press': 'dumbbell-shoulder-press-front-v1',
};

PoseFrame _at(PoseFrame frame, int time, {double? profileWidth}) {
  final joints = Map<PoseLandmark, PosePoint>.of(frame.landmarks);
  if (profileWidth != null) {
    for (final (near, far) in [
      (PoseLandmark.leftShoulder, PoseLandmark.rightShoulder),
      (PoseLandmark.leftHip, PoseLandmark.rightHip),
    ]) {
      final point = joints[near];
      if (point != null) {
        joints[far] = PosePoint(
            x: point.x + profileWidth,
            y: point.y,
            z: point.z,
            visibility: point.visibility,
            presence: point.presence);
      }
    }
  }
  return PoseFrame(
      capturedAtMicros: time,
      detectorId: frame.detectorId,
      modelVersion: frame.modelVersion,
      imageWidth: frame.imageWidth,
      imageHeight: frame.imageHeight,
      landmarks: joints,
      worldLandmarks: frame.worldLandmarks,
      posePresence: frame.posePresence);
}

class _Preferences implements WorkoutPreferencesStore {
  Map<String, Object?>? value;
  Completer<void>? writeGate;
  @override
  Future<Map<String, Object?>?> read() async => value;
  @override
  Future<void> write(Map<String, Object?> value) async {
    await writeGate?.future;
    this.value = value;
  }
}

void main() {
  testWidgets(
      'full coaching announces set, rest, preparation and completion once',
      (tester) async {
    final h = PressHarness(sets: 2, reps: 1);
    final session = h.session;
    session.audio.setVoiceEnabled(true);
    session.setContinuation.setEnabled(true);
    await session.start(consented: true, setupConfirmed: true);
    session.setRestSeconds(6);
    Future<void> deliver(PoseFrame frame) async {
      h.now = frame.capturedAtMicros;
      h.detector.frame = frame;
      h.camera.receive!(PoseInput(timestampMicros: h.now));
      await tester.pump(const Duration(milliseconds: 50));
    }

    for (final frame in shoulderPressTrajectory()) {
      await deliver(frame);
    }
    final neutral = shoulderPressFrame(0, 0);
    for (var i = 0;
        i < 220 && session.guidance.stage == GuidedWorkoutStage.resting;
        i++) {
      await deliver(_at(neutral, h.now + 50000));
    }
    expect(session.guidance.stage, GuidedWorkoutStage.working);
    for (final frame in shoulderPressTrajectory(startMicros: h.now + 50000)) {
      await deliver(frame);
    }
    final speech = h.audio.played.map((cue) => cue.text);
    for (final text in [
      'Set complete. Rest.',
      'Rest ending. Get ready.',
      'Hold steady. Wait for ready.',
      'Workout complete.'
    ]) {
      expect(speech.where((s) => s == text), hasLength(1), reason: text);
    }
    expect(session.guidance.stage, GuidedWorkoutStage.complete);
    await session.close();
    h.dispose();
  });

  for (final kind in _constructors.keys) {
    testWidgets(
        '$kind auto start uses fresh calibrated preparation without credit',
        (tester) async {
      final frames = await trajectory(kind);
      final scope =
          SessionScope(userId: 'auto-set-fixture', organizationId: 'gainpath');
      final camera = Camera(), detector = RowDetector();
      final store = FailingStore(scope: scope)..fail = false;
      final repo = WorkoutSessionRepository(
          scope: scope,
          store: store,
          uploadGateway: UnavailableWorkoutUploadGateway(),
          activeScope: () => scope);
      var now = 0;
      final args = <Symbol, dynamic>{
        #scope: scope,
        #activeScope: () => scope,
        #camera: camera,
        #detectorFactory: () async => detector,
        #audioPort: AudioSink(),
        #repository: repo,
        #clockMicros: () => now,
        #sessionId: 'auto-set-$kind',
        #exerciseId: _exerciseIds[kind],
        #publishedRoutineId: 'routine',
        #detectorId: frames.first.detectorId,
        #detectorVersion: '1',
        #sets: 2,
        #reps: 1,
        #provenance: WorkoutProvenance.recordedFixture,
      };
      if (kind == 'squat') {
        args.remove(#sets);
        args.remove(#reps);
        args[#guidance] = GuidedWorkoutProgress(sets: 2, repetitions: 1);
      }
      if (kind == 'curl') args[#armMode] = CurlArmMode.leftOnly;
      final session = Function.apply(_constructors[kind]!, [], args)
          as MeasuredWorkoutSession;
      final auto = (session as WorkoutSetContinuationSession).setContinuation;
      auto.setEnabled(true);
      await (session as dynamic).start(consented: true, setupConfirmed: true);
      session.setRestSeconds(1);
      Future<void> deliver(PoseFrame frame) async {
        now = frame.capturedAtMicros;
        detector.frame = frame;
        camera.receive!(PoseInput(timestampMicros: now));
        await tester.pump(const Duration(milliseconds: 50));
      }

      for (final frame in frames) {
        await deliver(frame);
      }
      expect(session.guidance!.stage, GuidedWorkoutStage.resting);
      expect(session.analysis!.repetitions, 1);
      final side = ['squat', 'curl', 'calf'].contains(kind);
      if (side) {
        // A frontal view can still pass a unilateral rep analyzer's
        // geometry. It cannot arm the optional side-profile continuation.
        for (var i = 0; i < 90; i++) {
          await deliver(_at(frames.first, now + 50000, profileWidth: .5));
        }
        expect(session.guidance!.stage, GuidedWorkoutStage.resting);
        expect(auto.status, SetContinuationStatus.waiting);
      }
      var countedDown = false;
      for (var i = 0;
          i < 125 && session.guidance!.stage == GuidedWorkoutStage.resting;
          i++) {
        await deliver(
            _at(frames.first, now + 50000, profileWidth: side ? .015 : null));
        countedDown |= auto.status == SetContinuationStatus.countdown;
      }
      expect(countedDown, true);
      expect(session.guidance!.stage, GuidedWorkoutStage.working);
      expect(session.guidance!.completedSets, 1);
      expect(session.guidance!.setRepetitions, 0);
      expect(session.analysis!.repetitions, 1);
      await session.close();
      (session as dynamic).dispose();
      repo.dispose();
    });
  }

  for (final action in ['pause', 'background', 'consent']) {
    testWidgets('press countdown cancels on $action', (tester) async {
      final h = PressHarness(sets: 2, reps: 1);
      final store = _Preferences();
      final prefs = WorkoutPreferencesController(scope: h.scope, store: store);
      await prefs.grantConsent();
      final c = ShoulderPressWorkoutSession(
          scope: h.scope,
          activeScope: () => prefs.validConsent ? h.scope : null,
          camera: h.camera,
          detectorFactory: () async => h.detector,
          audioPort: h.audio,
          repository: h.repo,
          clockMicros: () => h.now,
          sessionId: 'cancel-auto-set',
          exerciseId: 'dumbbell-shoulder-press-front-v1',
          publishedRoutineId: 'routine',
          detectorId: 'synthetic-press',
          detectorVersion: '1',
          sets: 2,
          reps: 1,
          provenance: WorkoutProvenance.recordedFixture);
      await c.start(consented: true, setupConfirmed: true);
      c.setRestSeconds(0);
      c.setContinuation.setEnabled(true);
      await h.feed(tester, shoulderPressTrajectory());
      final neutral = shoulderPressFrame(0, 0);
      for (var i = 0;
          i < 20 && c.setContinuation.status != SetContinuationStatus.countdown;
          i++) {
        await h.feed(tester, [_at(neutral, h.now + 50000)]);
      }
      expect(c.setContinuation.status, SetContinuationStatus.countdown);
      switch (action) {
        case 'pause':
          await c.pause();
        case 'background':
          await c.setForeground(false);
        case 'consent':
          store.writeGate = Completer<void>();
          final pending = prefs.withdrawConsent();
          await tester.pump(const Duration(milliseconds: 100));
          expect(c.viewPhase, MeasuredWorkoutPhase.closed);
          store.writeGate!.complete();
          await pending;
      }
      expect(c.setContinuation.status, SetContinuationStatus.cancelled);
      expect(c.guidance.stage, GuidedWorkoutStage.resting);
      expect(c.guidance.completedSets, 1);
      await c.close();
      c.dispose();
      prefs.dispose();
      h.dispose();
    });
  }
}
