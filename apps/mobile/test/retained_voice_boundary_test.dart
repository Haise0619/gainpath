import 'package:gainpath_mobile/features/workout/domain/workout_audio_trace.dart';
import 'dart:async';
import 'package:gainpath_mobile/features/workout/domain/workout_audio_port.dart';
import 'package:gainpath_mobile/features/workout/domain/curl_arm_metrics.dart';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/guided_workout_progress.dart';
import 'package:gainpath_mobile/features/workout/application/measured_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/workout_voice_session.dart';
import 'package:gainpath_mobile/features/workout/application/real_squat_session_controller.dart';
import 'package:gainpath_mobile/features/workout/application/curl_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/calf_raise_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/lateral_raise_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/shoulder_press_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/floor_push_up_workout_session.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'support/shoulder_press_trajectory.dart';
import 'support/lateral_raise_trajectory.dart';
import 'support/floor_push_up_trajectory.dart';
import 'real_squat_session_test.dart' show Camera, FailingStore;
import 'squat_processing_controller_test.dart' as squat;
import 'calf_raise_workout_session_test.dart' show CalfDetector;
import 'row_workout_session_test.dart' show RowDetector;

PoseFrame curl(int t, double a) {
  final r = a * math.pi / 180;
  PosePoint p(double x, double y) =>
      PosePoint(x: x, y: y, z: 0, visibility: .99, presence: .99);
  return PoseFrame(
      capturedAtMicros: t,
      detectorId: 'fixture',
      modelVersion: '1',
      imageWidth: 400,
      imageHeight: 800,
      landmarks: {
        PoseLandmark.leftShoulder: p(.4, .2),
        PoseLandmark.leftElbow: p(.4, .34),
        PoseLandmark.leftWrist:
            p(.4 + .24 * math.sin(r), .34 - .12 * math.cos(r)),
        PoseLandmark.leftHip: p(.4, .58)
      });
}

Future<List<PoseFrame>> trajectory(String kind) async {
  if (kind == 'press') return shoulderPressTrajectory().toList();
  if (kind == 'lateral') return lateralRaiseTrajectory().toList();
  var t = 0;
  final frames = <PoseFrame>[];
  void add(double a, int n, PoseFrame Function(int, double) make,
      {int step = 100000}) {
    for (var i = 0; i < n; i++) {
      t += step;
      frames.add(make(t, a));
    }
  }

  if (kind == 'squat') {
    add(175, 12, squat.frame);
    for (var i = 1; i <= 20; i++) {
      add(175 - i * 5, 1, squat.frame);
    }
    add(75, 8, squat.frame);
    for (var i = 1; i <= 20; i++) {
      add(75 + i * 5, 1, squat.frame);
    }
    add(175, 12, squat.frame);
  } else if (kind == 'floor') {
    add(170, 14, floorFrame, step: 50000);
    for (final a in [
      150.0,
      130.0,
      110.0,
      90.0,
      90.0,
      90.0,
      110.0,
      130.0,
      150.0,
      170.0,
      170.0
    ]) {
      add(a, 4, floorFrame, step: 50000);
    }
  } else if (kind == 'curl') {
    add(170, 8, curl, step: 150000);
    for (final a in [
      160.0,
      130.0,
      100.0,
      70.0,
      45.0,
      45.0,
      70.0,
      100.0,
      130.0,
      160.0,
      170.0,
      170.0
    ]) {
      add(a, 1, curl, step: 150000);
    }
  } else {
    final d = CalfDetector();
    for (final v in [
      ...List<double>.filled(8, 0),
      .02,
      .04,
      .07,
      .11,
      .11,
      .11,
      .07,
      .04,
      .01,
      0,
      0,
      0
    ]) {
      t += 150000;
      d.lift = v.toDouble();
      frames.add(await d.detect(PoseInput(timestampMicros: t)));
    }
  }
  return frames;
}

class HoldingOutcomeAudio extends squat.AudioSink {
  final outcome = Completer<AudioPlaybackOutcome>();
  @override
  Future<AudioPlaybackOutcome> play(CueRequest cue) {
    played.add(cue);
    return cue.id.endsWith('_rep') || cue.id == 'floor_good'
        ? outcome.future
        : Future.value(AudioPlaybackOutcome.completed);
  }

  @override
  Future<void> stop() async {
    await super.stop();
    if (played.any((c) => c.id.endsWith('_rep') || c.id == 'floor_good') &&
        !outcome.isCompleted) {
      outcome.complete(AudioPlaybackOutcome.cancelled);
    }
  }
}

void main() {
  final constructors = <String, Function>{
    'squat': RealSquatSessionController.new,
    'curl': CurlWorkoutSession.new,
    'calf': CalfRaiseWorkoutSession.new,
    'floor': FloorPushUpWorkoutSession.new,
    'lateral': LateralRaiseWorkoutSession.new,
    'press': ShoulderPressWorkoutSession.new
  };
  final exercises = {
    'squat': 'F3b8xIr8ynBDd3gEICKX',
    'curl': 'standing-single-arm-curl-side-v1',
    'calf': 'standing-calf-raise-side-v1',
    'floor': 'standard-floor-push-up-side-v1',
    'lateral': 'standing-lateral-raise-front-v1',
    'press': 'dumbbell-shoulder-press-front-v1'
  };
  for (final kind in constructors.keys) {
    for (final sets in [1, 2]) {
      for (final target in [1, 2]) {
        testWidgets(
            '$kind $target-rep target speaks once at $sets-set boundary',
            (tester) async {
          final frames = await trajectory(kind),
              camera = Camera(),
              d = RowDetector(),
              audio = sets == 1 && target == 1
                  ? HoldingOutcomeAudio()
                  : squat.AudioSink();
          var now = 0;
          final scope = SessionScope(
                  userId: 'voice-member', organizationId: 'gainpath'),
              store = FailingStore(
                  scope: SessionScope(
                      userId: 'voice-member', organizationId: 'gainpath'))
                ..fail = false;
          final repo = WorkoutSessionRepository(
              scope: scope,
              store: store,
              uploadGateway: UnavailableWorkoutUploadGateway(),
              activeScope: () => scope);
          final args = <Symbol, dynamic>{
            #scope: scope,
            #activeScope: () => scope,
            #camera: camera,
            #detectorFactory: () async => d,
            #audioPort: audio,
            #repository: repo,
            #clockMicros: () => now,
            #sessionId: 'voice-$kind',
            #exerciseId: exercises[kind],
            #publishedRoutineId: 'routine',
            #detectorId: frames.first.detectorId,
            #detectorVersion: '1',
            #sets: sets,
            #reps: target,
            #provenance: WorkoutProvenance.recordedFixture
          };
          if (kind == 'squat') {
            args.remove(#sets);
            args.remove(#reps);
            args[#guidance] =
                GuidedWorkoutProgress(sets: sets, repetitions: target);
          }
          if (kind == 'curl') args[#armMode] = CurlArmMode.leftOnly;
          final session = Function.apply(constructors[kind]!, [], args)
              as MeasuredWorkoutSession;
          final voice = (session as WorkoutVoiceSession).voiceFeedback;
          expect(voice.boundedStarts, true);
          final trace = WorkoutAudioTrace(clockMicros: () => now);
          voice.trace = trace;
          voice.setVoiceEnabled(true);
          await (session as dynamic)
              .start(consented: true, setupConfirmed: true);
          int? boundaryAt;
          for (var cycle = 0; cycle < target; cycle++) {
            final offset = cycle * frames.last.capturedAtMicros;
            for (final original in frames) {
              final f = PoseFrame(
                  capturedAtMicros: original.capturedAtMicros + offset,
                  detectorId: original.detectorId,
                  modelVersion: original.modelVersion,
                  imageWidth: original.imageWidth,
                  imageHeight: original.imageHeight,
                  posePresence: original.posePresence,
                  isMirrored: original.isMirrored,
                  landmarks: original.landmarks,
                  worldLandmarks: original.worldLandmarks);
              now = f.capturedAtMicros;
              d.frame = f;
              camera.receive!(PoseInput(timestampMicros: now));
              await tester.pump();
              if (session.guidance!.stage != GuidedWorkoutStage.working) {
                boundaryAt ??= now;
              }
            }
          }
          expect(session.analysis!.repetitions, target);
          expect(
              trace.records.lastWhere(
                  (r) => r["stage"] == "tts_dispatch")["dartElapsedMicros"],
              boundaryAt);
          expect(
              session.guidance!.stage,
              sets == 1
                  ? GuidedWorkoutStage.complete
                  : GuidedWorkoutStage.resting);
          if (target == 1) {
            expect(
                audio.played.where(
                    (c) => c.id.endsWith('_rep') || c.id == 'floor_good'),
                hasLength(1));
          }
          if (sets == 1) {
            final saving = session.endAndSave();
            await tester.pump();
            expect(store.writes, 1);
            if (target == 1) {
              expect(audio.closes, 0);
              expect(voice.activeCue, isNotNull);
              // A real source change during durable save must still cancel speech.
              if (kind == 'squat') {
                session.preview.onGeometryInvalidated!();
                await tester.pump();
                expect(voice.activeCue, isNull);
              } else if (kind == 'floor') {
                await (session as dynamic).setForeground(false);
                await tester.pump();
                expect(voice.activeCue, isNull);
              } else {
                await tester.pump(const Duration(milliseconds: 1600));
              }
            }
            expect(await saving, isNotNull);
            expect(await repo.loadHistory(), hasLength(1));
          }
          await session.close();
          (session as dynamic).dispose();
          repo.dispose();
        });
      }
    }
  }
}
