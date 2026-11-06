import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/application/workout_audio_controller.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_feedback_event.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_audio_trace.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_audio_port.dart';
import 'workout_audio_controller_test.dart'
    show FakeAudio, PreparingAudio, correction, warning, encouragement, flush;

WorkoutFeedbackEvent event(String id, {int observed = 0, int generated = 0}) =>
    WorkoutFeedbackEvent(
        id: id,
        cue: correction,
        observedAtMicros: observed,
        generatedAtMicros: generated);

void main() {
  test(
      'fresh observed event survives READY and brief unavailability exactly once',
      () async {
    final port = PreparingAudio();
    final trace = WorkoutAudioTrace(clockMicros: () => 0);
    final c = WorkoutAudioController(port: port, trace: trace)
      ..setVoiceEnabled(true);
    c.consume([],
        events: [event('attempt-1')], nowMicros: 0, trackingAvailable: false);
    await flush();
    c.consume([], nowMicros: 100000, trackingAvailable: true);
    c.consume([], nowMicros: 150000, trackingAvailable: false);
    port.ready.complete(true);
    await flush();
    expect(port.played, [correction]);
    port.completions.single.complete(AudioPlaybackOutcome.completed);
    await flush();
    c.consume([],
        events: [event('attempt-1')],
        nowMicros: 200000,
        trackingAvailable: true);
    expect(port.played, [correction]);
    expect(
        trace.records.map((r) => r['stage']),
        containsAllInOrder([
          'feedback_queued',
          'arbitration_selected',
          'tts_dispatch',
          'playback_result'
        ]));
    await c.close();
  });

  testWidgets('preparation exceeds observed start budget: never speaks late',
      (tester) async {
    final port = PreparingAudio();
    final c = WorkoutAudioController(port: port)..setVoiceEnabled(true);
    c.consume([],
        events: [event('attempt-1', generated: 200000)],
        nowMicros: 200000,
        trackingAvailable: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 301));
    port.ready.complete(true);
    await tester.pump();
    expect(port.played, isEmpty);
    await c.close();
  });

  test('expired, future, invalid and duplicate capture batches cannot speak',
      () async {
    final port = FakeAudio();
    final c = WorkoutAudioController(port: port)..setVoiceEnabled(true);
    c.consume([], events: [
      event('stale'),
      event('future', observed: 700000, generated: 700000),
      event('negative', observed: -1)
    ], nowMicros: 500000, trackingAvailable: false);
    c.consume([],
        events: [event('duplicate', observed: 500000, generated: 500000)],
        nowMicros: 500000,
        trackingAvailable: true);
    await flush();
    expect(port.played, isEmpty);
    await c.close();
  });

  for (final cancellation in [
    'source',
    'geometry',
    'pause',
    'mute',
    'background',
    'close',
    'warning'
  ]) {
    test('$cancellation invalidates event during asynchronous preparation',
        () async {
      final port = PreparingAudio();
      final c = WorkoutAudioController(port: port)..setVoiceEnabled(true);
      c.consume([],
          events: [event('attempt-1')], nowMicros: 0, trackingAvailable: true);
      await flush();
      switch (cancellation) {
          case 'geometry':
            c.invalidateSource();
        case 'source':
          c.consume([],
              nowMicros: 1, trackingAvailable: false, invalidateFeedback: true);
        case 'pause':
          c.pause();
        case 'mute':
          c.setVoiceEnabled(false);
        case 'background':
          c.setForeground(false);
        case 'close':
          await c.close();
        case 'warning':
          c.consume([warning], nowMicros: 1, trackingAvailable: false);
      }
      port.ready.complete(true);
      await flush();
      expect(port.played, cancellation == 'warning' ? [warning] : isEmpty);
      await c.close();
    });
  }

  test('events respect cooldown, priority and no speech backlog', () async {
    final port = FakeAudio();
    final c = WorkoutAudioController(port: port)..setVoiceEnabled(true);
    c.consume([encouragement], nowMicros: 0, trackingAvailable: true);
    await flush();
    c.consume([],
        events: [event('attempt-1', observed: 1, generated: 1)],
        nowMicros: 1,
        trackingAvailable: false);
    await flush();
    expect(port.played, [encouragement, correction]);
    port.completions.last.complete(AudioPlaybackOutcome.completed);
    await flush();
    c.consume([],
        events: [event('attempt-2', observed: 2, generated: 2)],
        nowMicros: 2,
        trackingAvailable: false);
    await flush();
    expect(port.played, [encouragement, correction]);
    await c.close();
  });

  test('trace retains bounded local timing only', () {
    final trace = WorkoutAudioTrace(clockMicros: () => 123);
    for (var i = 0; i < 300; i++) {
      trace.record('queued', requestId: 'request-$i', cueId: 'floor_extension');
    }
    expect(trace.records.length, 256);
    expect(trace.records.first['requestId'], 'request-44');
    expect(trace.records.last['dartElapsedMicros'], 123);
    expect(trace.records.last.keys,
        unorderedEquals(['stage', 'requestId', 'cueId', 'dartElapsedMicros']));
  });

  test('newer input past event expiry invalidates pending event immediately',
      () async {
    final port = PreparingAudio();
    final c = WorkoutAudioController(port: port)..setVoiceEnabled(true);
    c.consume([],
        events: [event('attempt-1')], nowMicros: 0, trackingAvailable: true);
    await flush();
    c.consume([], nowMicros: 500000, trackingAvailable: true);
    port.ready.complete(true);
    await flush();
    expect(port.played, isEmpty);
    await c.close();
  });
}
