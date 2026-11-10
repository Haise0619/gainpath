import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_audio_port.dart';
import 'package:gainpath_mobile/infrastructure/audio/android_workout_audio.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_audio_trace.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_performance_diagnostics.dart';

const cue = CueRequest(
    id: 'depth', text: 'Go deeper', priority: CuePriority.correction);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/workout_audio');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late AndroidWorkoutAudio port;
  late List<MethodCall> calls;
  setUp(() {
    calls = [];
    port = AndroidWorkoutAudio(channel: channel, sessionId: 'test-session');
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'create'
          ? true
          : call.method == 'clock'
              ? 1000000
              : call.method == 'play'
                  ? 'completed'
                  : null;
    });
  });
  tearDown(() async {
    await port.close();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('explicit retry retires failed engine and uses a fresh native identity',
      () async {
    var attempts = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'create' ? ++attempts > 1 : null;
    });
    expect(await port.prepare(), false);
    expect(await port.prepare(), false);
    expect(attempts, 1);
    expect(await port.retryPrepare(), true);
    final creates = calls.where((c) => c.method == 'create').toList();
    expect(creates, hasLength(2));
    expect((creates.last.arguments as Map)['sessionId'],
        isNot((creates.first.arguments as Map)['sessionId']));
    expect(calls.indexWhere((c) => c.method == 'close'),
        lessThan(calls.lastIndexOf(creates.last)));
    await port.close();
    expect(await port.retryPrepare(), false);
    expect(attempts, 2);
  });

  test(
      'diagnostic ordinary speech correlates without changing native start policy',
      () async {
    final traced = AndroidWorkoutAudio(channel: channel, sessionId: 'baseline');
    expect(await traced.playTraced(cue, requestId: 'event'),
        AudioPlaybackOutcome.completed);
    final arguments = calls.last.arguments as Map;
    expect(arguments['requestId'], 'event');
    expect(arguments.containsKey('maxStartDelayMs'), isFalse);
    expect(arguments.containsKey('startDeadlineMicros'), isFalse);
    await traced.close();
  });

  test('closing while TTS initializes cannot leave a diagnostic live engine',
      () async {
    final baseline = WorkoutPerformanceDiagnostics(
        exercise: WorkoutBaselineExercise.squat, clockMicros: () => 1);
    final ready = Completer<bool>();
    messenger.setMockMethodCallHandler(
        channel, (call) async => call.method == 'create' ? ready.future : null);
    final traced = AndroidWorkoutAudio(
        channel: channel, sessionId: 'pending', baseline: baseline);
    final preparing = traced.prepare();
    await Future<void>.delayed(Duration.zero);
    await traced.close();
    ready.complete(true);
    await preparing;
    expect((baseline.snapshot()['resources'] as Map)['tts'], 0);
  });

  test('lazy initialization; native completion and shared session payload',
      () async {
    expect(calls, isEmpty);
    expect(await port.play(cue), AudioPlaybackOutcome.completed);
    expect(await port.play(cue), AudioPlaybackOutcome.completed);
    expect(calls.where((call) => call.method == 'create').length, 1);
    final payload = calls.last.arguments as Map;
    expect(payload['sessionId'], 'test-session');
    expect(payload['text'], 'Go deeper');
    expect(payload['generation'], 0);
  });

  test('stop during initialization never speaks after late readiness',
      () async {
    final ready = Completer<bool>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'create') return ready.future;
      return null;
    });
    final playback = port.play(cue);
    await Future<void>.delayed(Duration.zero);
    await port.stop();
    ready.complete(true);
    expect(await playback, AudioPlaybackOutcome.cancelled);
    expect(calls.map((call) => call.method), ['create', 'stop']);
    expect((calls.last.arguments as Map)['generation'], 1);
  });

  test('close during initialization cannot resurrect playback; idempotent',
      () async {
    final ready = Completer<bool>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'create') return ready.future;
      return null;
    });
    final playback = port.play(cue);
    await Future<void>.delayed(Duration.zero);
    await Future.wait([port.close(), port.close()]);
    ready.complete(true);
    expect(await playback, AudioPlaybackOutcome.cancelled);
    expect(await port.play(cue), AudioPlaybackOutcome.cancelled);
    expect(calls.map((call) => call.method), ['create', 'close']);
  });

  test('unavailable voice/plugin remains unavailable without retry flood',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'create') {
        throw PlatformException(code: 'tts_unavailable');
      }
      return null;
    });
    expect(await port.play(cue), AudioPlaybackOutcome.unavailable);
    expect(await port.play(cue), AudioPlaybackOutcome.unavailable);
    expect(calls.where((call) => call.method == 'create').length, 1);
  });

  test('playback native rejection is not reported as completed', () async {
    messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'create'
            ? true
            : call.method == 'play'
                ? 'unavailable'
                : null);
    expect(await port.play(cue), AudioPlaybackOutcome.unavailable);
  });

  test('timed request carries bounded native deadline and correlated trace',
      () async {
    final trace = WorkoutAudioTrace(clockMicros: () => 42);
    final timed =
        AndroidWorkoutAudio(channel: channel, sessionId: 'timed', trace: trace);
    expect(
        await timed.playCurrent(cue,
            requestId: 'attempt-1',
            remainingStartTime: const Duration(milliseconds: 237)),
        AudioPlaybackOutcome.completed);
    final create = calls.first.arguments as Map;
    final play = calls.last.arguments as Map;
    expect(create['trace'], true);
    expect(play['requestId'], 'attempt-1');
    expect(play['maxStartDelayMs'], inInclusiveRange(1, 237));
    expect(play['startDeadlineMicros'], inInclusiveRange(1000001, 1237000));
    expect(trace.records.map((r) => r['stage']), contains('tts_request'));
    await timed.close();
  });

  test('expired timed request never reaches native TTS', () async {
    expect(
        await port.playCurrent(cue,
            requestId: 'stale', remainingStartTime: Duration.zero),
        AudioPlaybackOutcome.cancelled);
    expect(calls, isEmpty);
  });

  test(
      'native trace correlates start/completion and ignores old request epochs',
      () async {
    final trace = WorkoutAudioTrace(clockMicros: () => 42);
    final traced = AndroidWorkoutAudio(
        channel: channel, sessionId: 'trace-session', trace: trace);
    final done = Completer<String>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'create') return true;
      if (call.method == 'clock') return 1000000;
      if (call.method == 'play') return done.future;
      return null;
    });
    final playback = traced.playCurrent(cue,
        requestId: 'attempt-2',
        remainingStartTime: const Duration(milliseconds: 400));
    await Future<void>.delayed(Duration.zero);
    Future<void> native(String stage,
        {String request = 'attempt-2', int generation = 0}) async {
      final response = Completer<void>();
      await messenger.handlePlatformMessage(
          'gainpath/workout_audio/events/trace-session',
          const StandardMethodCodec().encodeMethodCall(MethodCall('trace', {
            'stage': stage,
            'requestId': request,
            'generation': generation,
            'nativeElapsedMicros': 1234,
          })),
          (_) => response.complete());
      await response.future;
    }

    await native('playback_start', request: 'old');
    await native('playback_start', generation: 99);
    await native('native_tts_request');
    await native('playback_start');
    await native('playback_completed');
    done.complete('completed');
    expect(await playback, AudioPlaybackOutcome.completed);
    expect(
        trace.records.where((r) => r['stage'] == 'playback_start').length, 1);
    expect(
        trace.records.where((r) => r['nativeElapsedMicros'] != null).length, 3);
    await traced.close();
  });

  test('timed request also expires during direct engine preparation', () async {
    final ready = Completer<bool>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'create') return ready.future;
      return null;
    });
    final playback = port.playCurrent(cue,
        requestId: 'late-ready',
        remainingStartTime: const Duration(milliseconds: 1));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    ready.complete(true);
    expect(await playback, AudioPlaybackOutcome.cancelled);
    expect(calls.map((c) => c.method), ['create']);
  });

  test('delayed platform delivery retains absolute native expiry', () async {
    Map? request;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'create') return true;
      if (call.method == 'clock') return 1000000;
      if (call.method == 'play') {
        request = call.arguments as Map;
        // Simulated native receipt 150 ms later; the 100 ms remaining budget
        // must already have expired, rather than restarting on native receipt.
        final deadline = request!['startDeadlineMicros'] as int?;
        return deadline != null && deadline <= 1150000
            ? 'cancelled'
            : 'completed';
      }
      return null;
    });
    expect(
        await port.playCurrent(cue,
            requestId: 'bridge-late',
            remainingStartTime: const Duration(milliseconds: 100)),
        AudioPlaybackOutcome.cancelled);
    expect(request!['startDeadlineMicros'], lessThanOrEqualTo(1100000));
  });
}
