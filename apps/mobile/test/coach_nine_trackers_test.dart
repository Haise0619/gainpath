import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/real_squat_session_controller.dart';
import 'package:gainpath_mobile/features/workout/application/curl_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/calf_raise_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/lateral_raise_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/shoulder_press_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/floor_push_up_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/row_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/wall_push_up_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/reverse_lunge_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/guided_workout_progress.dart';
import 'package:gainpath_mobile/features/workout/application/measured_workout_session.dart';
import 'package:gainpath_mobile/features/workout/domain/curl_arm_metrics.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_audio_port.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'real_squat_session_test.dart' show Camera, FailingStore;
import 'row_workout_session_test.dart' show RowDetector;
import 'wall_push_up_workout_session_test.dart' show WallDetector;
import 'squat_processing_controller_test.dart' show AudioSink;
import 'retained_voice_boundary_test.dart' show trajectory;
import 'support/row_trajectory.dart';
import 'support/reverse_lunge_trajectory.dart';

class RecordedCoachSink extends AudioSink implements CoachWorkoutAudioPort {
  final finalRep = Completer<AudioPlaybackOutcome>();
  @override
  Future<AudioPlaybackOutcome> play(CueRequest cue) {
    played.add(cue);
    return cue.id == 'number_002'
        ? finalRep.future
        : Future.value(AudioPlaybackOutcome.completed);
  }

  @override
  Future<void> stop() async {
    await super.stop();
    if (played.any((c) => c.id == 'number_002') && !finalRep.isCompleted) {
      finalRep.complete(AudioPlaybackOutcome.cancelled);
    }
  }
}

void main() {
  final constructors = <String, Function>{
    'squat': RealSquatSessionController.new,
    'curl': CurlWorkoutSession.new,
    'calf': CalfRaiseWorkoutSession.new,
    'lateral': LateralRaiseWorkoutSession.new,
    'press': ShoulderPressWorkoutSession.new,
    'floor': FloorPushUpWorkoutSession.new,
    'row': RowWorkoutSession.new,
    'wall': WallPushUpWorkoutSession.new,
    'lunge': ReverseLungeWorkoutSession.new,
  };
  const ids = {
    'squat': 'F3b8xIr8ynBDd3gEICKX',
    'curl': 'standing-single-arm-curl-side-v1',
    'calf': 'standing-calf-raise-side-v1',
    'lateral': 'standing-lateral-raise-front-v1',
    'press': 'dumbbell-shoulder-press-front-v1',
    'floor': 'standard-floor-push-up-side-v1',
    'row': 'single-arm-dumbbell-row-side-v1',
    'wall': 'wall-push-up-side-v1',
    'lunge': 'bodyweight-reverse-lunge-side-v1'
  };
  for (final scenario in [
    ...constructors.keys,
    'row-failure',
    'wall-failure',
    'lunge-failure',
    'curl-both'
  ]) {
    final kind = scenario.split('-').first;
    final failSave = scenario.endsWith('-failure');
    testWidgets(
        '$scenario speaks actual accepted1,2 through the real session boundary',
        (tester) async {
      List<PoseFrame> frames;
      if (kind == 'row') {
        frames = rowTrajectory().toList();
      } else if (kind == 'lunge') {
        frames = reverseLungeTrajectory().toList();
      } else if (kind == 'wall') {
        final wall = WallDetector();
        frames = [];
        var t = 0;
        for (final angle in [
          ...List<double>.filled(12, 170),
          160.0,
          140.0,
          120.0,
          100.0,
          ...List<double>.filled(8, 85),
          100.0,
          120.0,
          140.0,
          160.0,
          ...List<double>.filled(12, 170)
        ]) {
          wall.angle = angle;
          t += 100000;
          frames.add(await wall.detect(PoseInput(timestampMicros: t)));
        }
      } else {
        frames = await trajectory(kind);
      }
      final scope =
          SessionScope(userId: 'coach-test', organizationId: 'gainpath');
      final store = FailingStore(scope: scope)..fail = failSave;
      final repo = WorkoutSessionRepository(
          scope: scope,
          store: store,
          uploadGateway: UnavailableWorkoutUploadGateway(),
          activeScope: () => scope);
      final camera = Camera(),
          detector = RowDetector(),
          sink = RecordedCoachSink();
      var now = 0;
      final args = <Symbol, dynamic>{
        #scope: scope,
        #activeScope: () => scope,
        #camera: camera,
        #detectorFactory: () async => detector,
        #audioPort: sink,
        #repository: repo,
        #clockMicros: () => now,
        #sessionId: 'coach-$kind',
        #exerciseId: ids[kind],
        #publishedRoutineId: 'routine',
        #detectorId: frames.first.detectorId,
        #detectorVersion: '1',
        #sets: 1,
        #reps: 2,
        #provenance: WorkoutProvenance.recordedFixture
      };
      if (kind == 'squat') {
        args.remove(#sets);
        args.remove(#reps);
        args[#guidance] = GuidedWorkoutProgress(sets: 1, repetitions: 2);
      }
      if (kind == 'curl') {
        args[#armMode] =
            scenario == 'curl-both' ? CurlArmMode.both : CurlArmMode.leftOnly;
      }
      if (kind == 'row') args[#side] = RowSide.left;
      if (kind == 'lunge') {
        args[#side] = LungeSide.left;
        args[#requireCameraCheck] = false;
      }
      final session = Function.apply(constructors[kind]!, [], args)
          as MeasuredWorkoutSession;
      session.setVoiceMode(WorkoutVoiceMode.fullCoaching);
      await (session as dynamic).start(consented: true, setupConfirmed: true);
      session.setVoiceMode(WorkoutVoiceMode.fullCoaching);
      for (var cycle = 0; cycle < 2; cycle++) {
        for (final original in frames) {
          final f = PoseFrame(
              capturedAtMicros: original.capturedAtMicros +
                  cycle * frames.last.capturedAtMicros,
              detectorId: original.detectorId,
              modelVersion: original.modelVersion,
              imageWidth: original.imageWidth,
              imageHeight: original.imageHeight,
              landmarks: original.landmarks,
              worldLandmarks: original.worldLandmarks,
              posePresence: original.posePresence,
              isMirrored: original.isMirrored);
          now = f.capturedAtMicros;
          detector.frame = f;
          camera.receive!(PoseInput(timestampMicros: now));
          await tester.pump();
        }
      }
      expect(session.analysis!.repetitions, 2);
      expect(
          sink.played.where((c) => c.id.startsWith('number_')).map((c) => c.id),
          ['number_001', 'number_002']);
      if (scenario == 'curl-both') {
        sink.finalRep.complete(AudioPlaybackOutcome.completed);
        await tester.pump();
        await tester.pump();
        expect(sink.played.any((c) => c.id == 'switch_right_v1'), true);
        (session as CurlWorkoutSession).confirmArmSwitch();
        for (var cycle = 2; cycle < 4; cycle++) {
          for (final original in frames) {
            final right = <PoseLandmark, PosePoint>{
              for (final entry in original.landmarks.entries)
                PoseLandmark.values.firstWhere((id) =>
                    id.name ==
                    entry.key.name.replaceFirst('left', 'right')): entry.value
            };
            final f = PoseFrame(
                capturedAtMicros: original.capturedAtMicros +
                    cycle * frames.last.capturedAtMicros,
                detectorId: original.detectorId,
                modelVersion: original.modelVersion,
                imageWidth: original.imageWidth,
                imageHeight: original.imageHeight,
                landmarks: right);
            now = f.capturedAtMicros;
            detector.frame = f;
            camera.receive!(PoseInput(timestampMicros: now));
            await tester.pump();
          }
        }
        expect(session.analysis!.repetitions, 4);
        expect(
            sink.played
                .where((c) => c.id.startsWith('number_'))
                .map((c) => c.id),
            ['number_001', 'number_002', 'number_001', 'number_002']);
        expect(await session.endAndSave(), isNotNull);
        await session.close();
        session.dispose();
        repo.dispose();
        return;
      }
      final saving = session.endAndSave();
      await tester.pump();
      expect(store.writes, 1);
      expect(sink.closes, failSave ? 1 : 0,
          reason: 'Save locally before bounded final voice settlement');
      if (!sink.finalRep.isCompleted) {
        sink.finalRep.complete(AudioPlaybackOutcome.completed);
      }
      await tester.pump();
      await tester.pump();
      expect(await saving, failSave ? isNull : isNotNull);
      await session.close();
      (session as dynamic).dispose();
      repo.dispose();
    });
  }
}
