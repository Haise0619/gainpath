import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_audio_port.dart';
import 'package:gainpath_mobile/infrastructure/audio/android_workout_audio.dart';

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
          : call.method == 'play'
              ? 'completed'
              : null;
    });
  });
  tearDown(() async {
    await port.close();
    messenger.setMockMethodCallHandler(channel, null);
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
}
