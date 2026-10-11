import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/squat_processing_controller.dart';
import 'package:gainpath_mobile/features/workout/application/workout_audio_controller.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_audio_port.dart';

class AudioSink implements WorkoutAudioPort {
  final played = <CueRequest>[];
  int stops = 0, closes = 0;
  @override
  Future<AudioPlaybackOutcome> play(CueRequest cue) async {
    played.add(cue);
    return AudioPlaybackOutcome.completed;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> close() async {
    closes++;
  }
}

PoseFrame frame(int t, double degrees, {bool missing = false}) {
  final angle = degrees * math.pi / 180;
  final hx = 320 + 140 * math.sin(angle), hy = 370 + 140 * math.cos(angle);
  PosePoint p(double x, double y) =>
      PosePoint(x: x / 640, y: y / 720, z: 0, visibility: .95, presence: .95);
  return PoseFrame(
      capturedAtMicros: t,
      detectorId: 'fixture',
      modelVersion: '1',
      imageWidth: 640,
      imageHeight: 720,
      landmarks: missing
          ? {}
          : {
              PoseLandmark.leftShoulder: p(hx, hy - 100),
              PoseLandmark.leftHip: p(hx, hy),
              PoseLandmark.leftKnee: p(320, 370),
              PoseLandmark.leftAnkle: p(320, 510),
            });
}

void main() {
  testWidgets('foreground return publishes resumed state without a new frame',
      (tester) async {
    final scope = SessionScope(userId: 'member', organizationId: 'org');
    final c = SquatProcessingController(
        scope: scope,
        activeScope: () => scope,
        audio: WorkoutAudioController(port: AudioSink()),
        clockMicros: () => 100000,
        sideViewConfirmed: true,
        uprightCameraConfirmed: true);
    final observed = <bool>[];
    c.addListener(() => observed.add(c.isPaused));
    c.setForeground(false);
    c.setForeground(true);
    expect(observed, [true, false]);
    await c.close();
    c.dispose();
  });
  testWidgets('closing from an update listener cannot restart the watchdog',
      (tester) async {
    final scope = SessionScope(userId: 'member', organizationId: 'org');
    final sink = AudioSink();
    final c = SquatProcessingController(
        scope: scope,
        activeScope: () => scope,
        audio: WorkoutAudioController(port: sink),
        clockMicros: () => 100000,
        sideViewConfirmed: true,
        uprightCameraConfirmed: true);
    void onUpdate() {
      c.removeListener(onUpdate);
      c.close();
    }

    c.addListener(onUpdate);
    c.consumeRefined(frame(100000, 175));
    await c.close();
    expect(c.isClosed, true);
    expect(sink.closes, 1);
    c.dispose();
    // The widget test also verifies that no periodic timer remains alive.
  });
  testWidgets('a refined-frame squat produces a real analysis update and cue',
      (tester) async {
    final sink = AudioSink();
    final audio = WorkoutAudioController(port: sink)..setVoiceEnabled(true);
    var now = 0;
    final scope = SessionScope(userId: 'member', organizationId: 'org');
    final c = SquatProcessingController(
        scope: scope,
        activeScope: () => scope,
        audio: audio,
        clockMicros: () => now,
        sideViewConfirmed: true,
        uprightCameraConfirmed: true);
    Future<void> send(double angle) async {
      now += 100000;
      c.consumeRefined(frame(now, angle));
      await tester.pump();
    }

    for (var i = 0; i < 12; i++) {
      await send(175);
    }
    for (var i = 1; i <= 20; i++) {
      await send(175.0 - 5 * i);
    }
    for (var i = 0; i < 8; i++) {
      await send(75);
    }
    for (var i = 1; i <= 20; i++) {
      await send(75.0 + 5 * i);
    }
    for (var i = 0; i < 12; i++) {
      await send(175);
    }
    expect(c.update!.repetitions, 1);
    expect(c.update!.partialRepetitions, 0);
    expect(sink.played.where((v) => v.id == 'squat_rep'), hasLength(1));
    expect(c.update!.formScorePercent, 100);
    await c.close();
    expect(sink.closes, 1);
    c.dispose();
  });
  testWidgets('watchdog loss cancels coaching and emits one positioning cue',
      (tester) async {
    final sink = AudioSink();
    final audio = WorkoutAudioController(port: sink)..setVoiceEnabled(true);
    var now = 0;
    final scope = SessionScope(userId: 'member', organizationId: 'org');
    final c = SquatProcessingController(
        scope: scope,
        activeScope: () => scope,
        audio: audio,
        clockMicros: () => now,
        sideViewConfirmed: true,
        uprightCameraConfirmed: true);
    for (var i = 0; i < 12; i++) {
      now += 100000;
      c.consumeRefined(frame(now, 175));
      await tester.pump();
    }
    now += 1000000;
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.update!.health, TrackingStatus.lost);
    expect(c.update!.needsCalibration, true);
    expect(
        sink.played.where((v) => v.id == 'squat_tracking_lost'), hasLength(1));
    now += 500000;
    await tester.pump(const Duration(milliseconds: 100));
    expect(
        sink.played.where((v) => v.id == 'squat_tracking_lost'), hasLength(1));
    await c.close();
    c.dispose();
  });
  testWidgets('account replacement closes audio and ignores late frames',
      (tester) async {
    final sink = AudioSink();
    final scope = SessionScope(userId: 'member', organizationId: 'org');
    SessionScope? active = scope;
    var now = 100000;
    final c = SquatProcessingController(
        scope: scope,
        activeScope: () => active,
        audio: WorkoutAudioController(port: sink),
        clockMicros: () => now,
        sideViewConfirmed: true,
        uprightCameraConfirmed: true);
    c.consumeRefined(frame(now, 175));
    active = SessionScope(userId: 'other', organizationId: 'org');
    now += 100000;
    expect(c.consumeRefined(frame(now, 175)), isNull);
    await tester.pump();
    expect(c.isClosed, true);
    expect(c.update, isNull);
    expect(sink.closes, 1);
    expect(c.consumeRefined(frame(now + 100000, 175)), isNull);
    c.dispose();
  });
  testWidgets('manual pause survives background and excludes paused frames',
      (tester) async {
    final scope = SessionScope(userId: 'member', organizationId: 'org');
    var now = 100000;
    final c = SquatProcessingController(
        scope: scope,
        activeScope: () => scope,
        audio: WorkoutAudioController(port: AudioSink()),
        clockMicros: () => now,
        sideViewConfirmed: true,
        uprightCameraConfirmed: true);
    c.consumeRefined(frame(now, 175));
    c.pause();
    c.setForeground(false);
    c.setForeground(true);
    now += 1000000;
    expect(c.consumeRefined(frame(now, 75)), isNull);
    expect(c.isPaused, true);
    c.resume();
    now += 100000;
    expect(c.consumeRefined(frame(now, 175))!.needsCalibration, true);
    expect(c.update!.repetitions, 0);
    await c.close();
    c.dispose();
  });
  testWidgets('duplicate and future frames do not mutate current analysis',
      (tester) async {
    final scope = SessionScope(userId: 'member', organizationId: 'org');
    var now = 100000;
    final c = SquatProcessingController(
        scope: scope,
        activeScope: () => scope,
        audio: WorkoutAudioController(port: AudioSink()),
        clockMicros: () => now,
        sideViewConfirmed: true,
        uprightCameraConfirmed: true);
    final initial = c.consumeRefined(frame(now, 175));
    expect(c.consumeRefined(frame(now, 75)), isNull);
    expect(c.consumeRefined(frame(now + 1, 75)), isNull);
    expect(identical(c.update, initial), true);
    await c.close();
    c.dispose();
  });
  test('analysis requires explicit side-view and upright camera setup', () {
    final scope = SessionScope(userId: 'member', organizationId: 'org');
    expect(
        () => SquatProcessingController(
            scope: scope,
            activeScope: () => scope,
            audio: WorkoutAudioController(port: AudioSink()),
            clockMicros: () => 0,
            sideViewConfirmed: false,
            uprightCameraConfirmed: true),
        throwsArgumentError);
  });
}
