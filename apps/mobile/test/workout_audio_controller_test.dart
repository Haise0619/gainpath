import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/workout_audio_controller.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_audio_port.dart';

class FakeAudio implements WorkoutAudioPort {
  final played = <CueRequest>[];
  final completions = <Completer<AudioPlaybackOutcome>>[];
  int stops = 0;
  int closes = 0;
  bool failPlay = false;
  bool completeOnStop = true;
  Completer<void>? stopGate;
  @override
  Future<AudioPlaybackOutcome> play(CueRequest cue) {
    played.add(cue);
    if (failPlay) return Future.error(StateError('unavailable'));
    final completer = Completer<AudioPlaybackOutcome>();
    completions.add(completer);
    return completer.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    if (stopGate != null) await stopGate!.future;
    for (final completer
        in completeOnStop ? completions : <Completer<AudioPlaybackOutcome>>[]) {
      if (!completer.isCompleted) {
        completer.complete(AudioPlaybackOutcome.cancelled);
      }
    }
  }

  @override
  Future<void> close() async {
    closes++;
  }
}

class PreparingAudio extends FakeAudio implements PreparedWorkoutAudioPort {
  final ready = Completer<bool>();
  int prepares = 0;
  @override
  Future<bool> prepare() {
    prepares++;
    return ready.future;
  }
}

const correction = CueRequest(
    id: 'depth', text: 'Go deeper', priority: CuePriority.correction);
const warning = CueRequest(
    id: 'tracking', text: 'Return to view', priority: CuePriority.warning);
const encouragement = CueRequest(
    id: 'rep', text: 'Good rep', priority: CuePriority.encouragement);
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeAudio port;
  late WorkoutAudioController controller;
  setUp(() {
    port = FakeAudio();
    controller = WorkoutAudioController(port: port);
  });
  tearDown(() async {
    port.stopGate?.complete();
    await controller.close();
  });
  void consume(List<CueRequest> cues, int timestamp, {bool tracking = true}) =>
      controller.consume(cues,
          nowMicros: timestamp, trackingAvailable: tracking);

  test('default silent; existing voice preference enables playback', () async {
    consume([correction], 0);
    await flush();
    expect(port.played, isEmpty);
    controller.applyPreferences(const MemberPreferences(voiceCoaching: true));
    consume([correction], 1);
    await flush();
    expect(port.played, [correction]);
  });

  test('priority interrupts without building a corrective backlog', () async {
    controller.setVoiceEnabled(true);
    consume([correction], 0);
    await flush();
    consume([encouragement], 1);
    consume([warning, correction], 2);
    await flush();
    expect(port.played, [correction, warning]);
    expect(port.stops, 1);
    port.completions.last.complete(AudioPlaybackOutcome.completed);
    await flush();
    expect(port.played.length, 2);
    expect(controller.activeCue, isNull);
  });

  test('duplicate cooldown and out-of-order frames cannot replay speech',
      () async {
    controller.setVoiceEnabled(true);
    consume([correction], 100);
    await flush();
    port.completions.single.complete(AudioPlaybackOutcome.completed);
    await flush();
    consume([correction], 101);
    consume([warning], 99);
    await flush();
    expect(port.played, [correction]);
    consume([correction], 2000100);
    await flush();
    expect(port.played, [correction, correction]);
  });

  test('tracking loss cancels corrections; recovery cancels loss warning',
      () async {
    controller.setVoiceEnabled(true);
    consume([correction], 0);
    await flush();
    consume([correction, warning], 1, tracking: false);
    await flush();
    expect(port.played, [correction, warning]);
    consume([encouragement], 2);
    await flush();
    expect(port.played.last, encouragement);
    expect(port.stops, 2);
  });

  test('pause and voice disable invalidate playback waiting on cancellation',
      () async {
    controller.setVoiceEnabled(true);
    consume([correction], 0);
    await flush();
    port.stopGate = Completer<void>();
    consume([warning], 1);
    await flush();
    controller.pause();
    controller.setVoiceEnabled(false);
    port.stopGate!.complete();
    port.stopGate = null;
    await flush();
    expect(port.played, [correction]);
  });

  test('foreground resume preserves manual pause and requires fresh cues',
      () async {
    controller.setVoiceEnabled(true);
    controller.pause();
    controller.setForeground(false);
    controller.setForeground(true);
    consume([warning], 0);
    await flush();
    expect(port.played, isEmpty);
    controller.resume();
    await flush();
    expect(port.played, isEmpty);
    consume([warning], 1);
    await flush();
    expect(port.played, [warning]);
  });

  test('background stops playback; no replay upon returning', () async {
    controller.setVoiceEnabled(true);
    consume([correction], 0);
    await flush();
    controller.setForeground(false);
    consume([warning], 1);
    controller.setForeground(true);
    await flush();
    expect(port.played, [correction]);
    expect(port.stops, 1);
  });

  test('rapid lifecycle transitions coalesce while native stop is pending',
      () async {
    controller.setVoiceEnabled(true);
    consume([correction], 0);
    await flush();
    port.stopGate = Completer<void>();
    controller.setForeground(false);
    await flush();
    for (var i = 0; i < 100; i++) {
      controller.setForeground(true);
      controller.setForeground(false);
    }
    port.stopGate!.complete();
    port.stopGate = null;
    await flush();
    expect(port.stops, 1);
    expect(port.played, [correction]);
  });

  test('late old utterance completion cannot clear the active warning',
      () async {
    controller.setVoiceEnabled(true);
    port.completeOnStop = false;
    consume([correction], 0);
    await flush();
    consume([warning], 1);
    await flush();
    port.completions.first.complete(AudioPlaybackOutcome.completed);
    await flush();
    expect(controller.activeCue, warning);
    port.completions.last.complete(AudioPlaybackOutcome.completed);
    await flush();
    expect(controller.activeCue, isNull);
  });

  test('new empty frame cancels a warning waiting behind a native stop',
      () async {
    controller.setVoiceEnabled(true);
    consume([correction], 0);
    await flush();
    port.stopGate = Completer<void>();
    consume([warning], 1);
    await flush();
    consume([], 2);
    port.stopGate!.complete();
    port.stopGate = null;
    await flush();
    expect(port.played, [correction]);
  });

  test('late engine readiness cannot speak a cue absent from newer frames',
      () async {
    final preparing = PreparingAudio();
    final c = WorkoutAudioController(port: preparing)..setVoiceEnabled(true);
    c.consume([correction], nowMicros: 0, trackingAvailable: true);
    await flush();
    c.consume([], nowMicros: 1, trackingAvailable: true);
    preparing.ready.complete(true);
    await flush();
    expect(preparing.played, isEmpty);
    await c.close();
  });

  test('already speaking cue completes when next frame has no event cue',
      () async {
    controller.setVoiceEnabled(true);
    consume([correction], 0);
    await flush();
    consume([], 1);
    await flush();
    expect(controller.activeCue, correction);
    expect(port.stops, 0);
    port.completions.single.complete(AudioPlaybackOutcome.completed);
    await flush();
    expect(controller.lastOutcome, AudioPlaybackOutcome.completed);
  });

  testWidgets('waiting cue expires even when no newer frame arrives',
      (tester) async {
    final preparing = PreparingAudio();
    final c = WorkoutAudioController(
        port: preparing, pendingStartTimeout: const Duration(milliseconds: 500))
      ..setVoiceEnabled(true);
    c.consume([warning], nowMicros: 0, trackingAvailable: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 501));
    preparing.ready.complete(true);
    await tester.pump();
    expect(preparing.played, isEmpty);
    expect(c.activeCue, isNull);
    await c.close();
  });

  test('preference load in background defers engine warmup until foreground',
      () async {
    final preparing = PreparingAudio();
    final c = WorkoutAudioController(port: preparing);
    c.setForeground(false);
    c.applyPreferences(const MemberPreferences(voiceCoaching: true));
    await flush();
    expect(preparing.prepares, 0);
    c.setForeground(true);
    await flush();
    expect(preparing.prepares, 1);
    preparing.ready.complete(true);
    await c.close();
  });

  test('playback errors are contained and reported as unavailable', () async {
    controller.setVoiceEnabled(true);
    port.failPlay = true;
    consume([correction], 0);
    await flush();
    expect(controller.lastOutcome, AudioPlaybackOutcome.unavailable);
    expect(controller.lastError, isA<StateError>());
    expect(controller.activeCue, isNull);
  });

  test('close is idempotent and late preferences/cues cannot resurrect audio',
      () async {
    controller.setVoiceEnabled(true);
    consume([correction], 0);
    await flush();
    await Future.wait([controller.close(), controller.close()]);
    controller.applyPreferences(const MemberPreferences(voiceCoaching: true));
    controller.resume();
    consume([warning], 1);
    await flush();
    expect(port.closes, 1);
    expect(port.played, [correction]);
  });
}
