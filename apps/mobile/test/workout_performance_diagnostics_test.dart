import 'dart:convert';
import 'dart:ui' show FrameTiming;
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_audio_trace.dart';
import 'package:gainpath_mobile/features/workout/application/workout_audio_controller.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'workout_audio_controller_test.dart' show FakeAudio, flush;
import 'package:gainpath_mobile/infrastructure/pose/workout_baseline.dart';
import 'shoulder_press_session_test.dart' show PressHarness;
import 'support/shoulder_press_trajectory.dart';

void main() {
  test(
      'muted transient outcomes and native-free failures have complete terminal denominators',
      () async {
    var now = 1;
    final d = WorkoutPerformanceDiagnostics(
        exercise: WorkoutBaselineExercise.bicepsCurl, clockMicros: () => now);
    final port = FakeAudio()..failPlay = true;
    final audio = WorkoutAudioController(
        port: port,
        trace: WorkoutAudioTrace(clockMicros: () => now, onRecord: d.audio));
    const cue = CueRequest(
        id: 'curl_rep', text: '1', priority: CuePriority.encouragement);
    audio.consume([cue], nowMicros: now, trackingAvailable: true);
    var counters = d.snapshot()['counters'] as Map;
    expect(counters['outcomeEvent'], 1);
    expect(counters['audioDropped'], 1);
    now = 3000000;
    audio.setVoiceEnabled(true);
    audio.consume([cue], nowMicros: now, trackingAvailable: true);
    await flush();
    counters = d.snapshot()['counters'] as Map;
    expect(counters['outcomeEvent'], 2);
    expect(counters['audioUnavailable'], 1);
    await audio.close();
  });
  test('ordinary builds do not create a baseline recorder', () {
    expect(
        createWorkoutBaseline(WorkoutBaselineExercise.squat, () => 0), isNull);
  });

  testWidgets(
      'binding observes real session readiness without crediting held/rest frames',
      (tester) async {
    tester.view.display.refreshRate = 120;
    addTearDown(tester.view.display.resetRefreshRate);
    final h = PressHarness(sets: 2, reps: 1);
    final baseline = WorkoutPerformanceDiagnostics(
        exercise: WorkoutBaselineExercise.shoulderPress,
        clockMicros: () => h.now);
    final binding = WorkoutBaselineBinding(
        session: h.session,
        baseline: baseline,
        audio: h.session.audio,
        trace: WorkoutAudioTrace(
            clockMicros: () => h.now, onRecord: baseline.audio));
    await h.session.start(consented: true, setupConfirmed: true);
    final timing = FrameTiming(
        vsyncStart: 0,
        buildStart: 100,
        buildFinish: 2100,
        rasterStart: 2200,
        rasterFinish: 5200,
        rasterFinishWallTime: 5200);
    tester.binding.platformDispatcher.onReportTimings!([timing]);
    final engineMetrics = baseline.snapshot()['metrics'] as Map;
    expect((engineMetrics['uiBuildMicros'] as Map)['recentP95'], 2000);
    expect((engineMetrics['rasterMicros'] as Map)['recentP95'], 3000);
    expect((engineMetrics['frameSpanMicros'] as Map)['recentP95'], 5200);
    expect((engineMetrics['frameBudgetMicros'] as Map)['recentP95'], 8333);
    tester.binding.platformDispatcher.onReportTimings!([
      FrameTiming(
          vsyncStart: 0,
          buildStart: 100,
          buildFinish: 9100,
          rasterStart: 9200,
          rasterFinish: 19200,
          rasterFinishWallTime: 19200)
    ]);
    final engineCounts = baseline.snapshot()['counters'] as Map;
    expect(engineCounts['uiBuildOverBudget'], 1);
    expect(engineCounts['rasterOverBudget'], 1);
    await h.feed(tester, shoulderPressTrajectory());
    final before = baseline.snapshot()['acceptedFrames'] as int;
    expect(before, greaterThan(0));
    expect(h.session.analysis!.repetitions, 1);
    final beforeRestFrame = baseline.snapshot();
    final previousRestMicros = beforeRestFrame['restingMicros'] as int;
    final previousRestFrames =
        (beforeRestFrame['counters'] as Map)['processedDuringRest'] as int;
    final beforeTime = h.now;
    final restFrame = shoulderPressTrajectory(startMicros: h.now + 50000).first;
    await h.feed(tester, [restFrame]);
    final duringRest = baseline.snapshot();
    expect(
        duringRest['restingMicros'], previousRestMicros + h.now - beforeTime);
    expect((duringRest['counters'] as Map)['processedDuringRest'],
        previousRestFrames + 1);
    await tester.pump(const Duration(seconds: 1));
    expect(baseline.snapshot()['acceptedFrames'], before);
    binding.dispose();
    final timingCount = ((baseline.snapshot()['metrics']
        as Map)['uiBuildMicros'] as Map)['count'];
    tester.binding.platformDispatcher.onReportTimings!([timing]);
    expect(
        ((baseline.snapshot()['metrics'] as Map)['uiBuildMicros']
            as Map)['count'],
        timingCount);
    await h.session.close();
    h.dispose();
    expect((baseline.snapshot()['metrics'] as Map).keys,
        contains('hostProcessingMicros'));
  });

  test(
      'six retained exercises only; scalar samples bounded with honest recent percentiles',
      () {
    expect(WorkoutBaselineExercise.values.map((e) => e.name), [
      'squat',
      'bicepsCurl',
      'calfRaise',
      'floorPushUp',
      'lateralRaise',
      'shoulderPress'
    ]);
    final d = WorkoutPerformanceDiagnostics(
        exercise: WorkoutBaselineExercise.squat,
        clockMicros: () => 1000000,
        capacity: 3);
    for (var i = 1; i <= 1000; i++) {
      d.sample(WorkoutMetric.hostProcessingMicros, i);
    }
    d.sample(WorkoutMetric.hostProcessingMicros, -1);
    final metrics = d.snapshot()['metrics'] as Map;
    final values = metrics['hostProcessingMicros'] as Map;
    expect(values['count'], 1000);
    expect(values['retained'], 3);
    expect(values['recentP95'], 1000);
    expect(values['mean'], 500.5);
  });

  test(
      'accepted FPS excludes rest, does not count duplicate deliveries and resources balance',
      () {
    var now = 0;
    final d = WorkoutPerformanceDiagnostics(
        exercise: WorkoutBaselineExercise.bicepsCurl, clockMicros: () => now);
    d.setWorking(true);
    d.accepted(0);
    now = 100000;
    d.accepted(100000);
    d.accepted(100000);
    now = 1000000;
    d.setWorking(false);
    now = 9000000;
    d.resourceOpened(WorkoutResource.camera);
    d.resourceClosed(WorkoutResource.camera);
    expect(d.snapshot()['acceptedFrames'], 2);
    expect(d.snapshot()['acceptedFps'], 2);
    expect((d.snapshot()['resources'] as Map)['camera'], 0);
  });

  test(
      'audio correlates bounded events without mixing native and Dart clock origins',
      () {
    var now = 1100;
    final d = WorkoutPerformanceDiagnostics(
        exercise: WorkoutBaselineExercise.floorPushUp,
        clockMicros: () => now,
        capacity: 3);
    d.audio({
      'stage': 'exercise_event_generated',
      'requestId': 'private-request',
      'cueId': 'floor_good',
      'observedAtMicros': 1000,
      'dartElapsedMicros': 1100
    });
    d.audio({
      'stage': 'tts_dispatch',
      'requestId': 'private-request',
      'dartElapsedMicros': 1200
    });
    d.audio({
      'stage': 'native_tts_request',
      'requestId': 'private-request',
      'nativeElapsedMicros': 9000000,
      'dartElapsedMicros': 1250
    });
    d.audio({
      'stage': 'playback_start',
      'requestId': 'private-request',
      'nativeElapsedMicros': 9000100,
      'dartElapsedMicros': 1400
    });
    d.audio({
      'stage': 'playback_start',
      'requestId': 'private-request',
      'nativeElapsedMicros': 9000200,
      'dartElapsedMicros': 1500
    });
    final metrics = d.snapshot()['metrics'] as Map;
    expect((metrics['eventToStartCallbackMicros'] as Map)['mean'], 400);
    expect((metrics['nativeRequestToStartMicros'] as Map)['mean'], 100);
    expect((metrics['nativeRequestToStartMicros'] as Map)['count'], 1);
    final output = jsonEncode(d.snapshot());
    expect(output, isNot(contains('private-request')));
    expect(output, isNot(contains('floor_good')));
    d.audio({'stage': 'unknown-private-text', 'requestId': 'private-member'});
    expect(jsonEncode(d.snapshot()), isNot(contains('private-member')));
    now = 2000;
    d.finish();
    final frozen = jsonEncode(d.snapshot());
    d.sample(WorkoutMetric.rssBytes, 999);
    d.accepted(123);
    expect(jsonEncode(d.snapshot()), frozen);
  });

  test('pending correlation records and histogram retention remain bounded',
      () {
    final d = WorkoutPerformanceDiagnostics(
        exercise: WorkoutBaselineExercise.shoulderPress,
        clockMicros: () => 1000000,
        capacity: 3);
    for (var i = 0; i < 10000; i++) {
      d.audio({
        'stage': 'exercise_event_generated',
        'requestId': '$i',
        'observedAtMicros': 0,
        'dartElapsedMicros': 0
      });
    }
    expect(d.pendingAudioCount, lessThanOrEqualTo(64));
    d.finish();
    expect(d.pendingAudioCount, 0);
  });
}
