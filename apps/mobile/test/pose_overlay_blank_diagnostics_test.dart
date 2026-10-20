import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/infrastructure/pose/pose_overlay_blank_diagnostics.dart';

void main() {
  test('records logical cause and CPU paint separately and recovers at paint',
      () {
    var now = 100;
    final recorder =
        PoseOverlayBlankDiagnostics(enabled: true, clockMicros: () => now);
    recorder.start('slow', sessionId: 'session-1');
    now = 200;
    recorder.reportState(visible: false, reason: 'freshness_expiry', context: {
      'inputMicros': 20,
      'deliveryMicros': 40,
      'lastValidPoseAgeMicros': 260000,
      'refinedCount': 33,
      'watchdogClearedValidPose': true,
    });
    now = 220;
    recorder.painted(visible: false, reason: 'freshness_expiry');
    now = 250;
    recorder.reportState(
        visible: true, reason: 'valid_pose', context: {'inputMicros': 30});
    expect(recorder.overlayBlank, true);
    now = 270;
    recorder.painted(
        visible: true, reason: 'valid_pose', context: {'inputMicros': 30});
    expect(recorder.overlayBlank, false);
    expect(recorder.latestEpisodeId, 1);
    expect(recorder.latestReason, 'freshness_expiry');
    final report = recorder.finish();
    final events = report['events'] as List;
    expect(events.map((e) => (e as Map)['kind']),
        ['blank_begin', 'blank_paint', 'recovery']);
    expect(events.map((e) => (e as Map)['observedMicros']), [200, 220, 270]);
    expect((events.first as Map)['watchdogClearedValidPose'], true);
    expect((events.last as Map)['firstBlankPaintMicros'], 220);
    expect((events.last as Map)['blankDurationMicros'], 70);
    expect(report['confirmedBlankEpisodes'], 1);
  });

  test('same reason is coalesced but a new reason keeps its own input context',
      () {
    var now = 0;
    final recorder =
        PoseOverlayBlankDiagnostics(enabled: true, clockMicros: () => now);
    recorder.start('still', sessionId: 'session-1');
    for (final input in [1, 2, 3]) {
      now++;
      recorder.reportState(
          visible: false,
          reason: 'detector_no_person',
          context: {'inputMicros': input, 'detectorPersonConfidence': .1});
      recorder.painted(
          visible: false,
          reason: 'detector_no_person',
          context: {'inputMicros': input});
    }
    now++;
    recorder.reportState(
        visible: false,
        reason: 'low_landmark_pose_presence',
        context: {'inputMicros': 4, 'posePresence': .2});
    final events = recorder.finish()['events'] as List;
    expect(events.map((e) => (e as Map)['kind']),
        ['blank_begin', 'blank_paint', 'cause_change']);
    expect((events.first as Map)['inputMicros'], 1);
    expect((events.last as Map)['inputMicros'], 4);
    expect((events.last as Map)['posePresence'], .2);
  });

  test('discard observations cannot cause a blank or recover one', () {
    final recorder =
        PoseOverlayBlankDiagnostics(enabled: true, clockMicros: () => 100);
    recorder.start('fast', sessionId: 'session-1');
    recorder.recordDiscard('stale_result', context: {'inputMicros': 1});
    expect(recorder.overlayBlank, false);
    recorder.reportState(visible: false, reason: 'freshness_expiry');
    recorder
        .recordDiscard('generation_invalidation', context: {'inputMicros': 2});
    expect(recorder.overlayBlank, true);
    final report = recorder.finish();
    expect(report['blankEpisodes'], 1);
    expect(report['discards'], 2);
    final discards = (report['events'] as List)
        .where((e) => (e as Map)['kind'] == 'discard');
    expect(
        discards.every((e) => (e as Map)['causalOverlayClear'] == false), true);
  });

  test('an obsolete or logically invalid visible paint cannot recover a blank',
      () {
    final recorder =
        PoseOverlayBlankDiagnostics(enabled: true, clockMicros: () => 100);
    recorder.start('slow', sessionId: 'session-1');
    recorder.reportState(
        visible: false,
        reason: 'freshness_expiry',
        context: {'inputMicros': 1});
    recorder.painted(
        visible: true, reason: 'valid_pose', context: {'inputMicros': 1});
    recorder.reportState(
        visible: true, reason: 'valid_pose', context: {'inputMicros': 3});
    recorder.painted(
        visible: true, reason: 'valid_pose', context: {'inputMicros': 2});
    expect(recorder.overlayBlank, true);
    recorder.painted(
        visible: true, reason: 'valid_pose', context: {'inputMicros': 3});
    expect(recorder.overlayBlank, false);
    expect(recorder.finish()['ignoredVisiblePaints'], 2);
  });

  test(
      'capacity truncates events while totals and episode badge keep advancing',
      () {
    final recorder = PoseOverlayBlankDiagnostics(
        enabled: true, clockMicros: () => 100, maxEvents: 2);
    recorder.start('slow', sessionId: 'session-1');
    for (var i = 1; i <= 6; i++) {
      recorder.reportState(visible: false, reason: 'freshness_expiry');
      recorder.painted(visible: false, reason: 'freshness_expiry');
      recorder.reportState(
          visible: true, reason: 'valid_pose', context: {'inputMicros': i});
      recorder.painted(
          visible: true, reason: 'valid_pose', context: {'inputMicros': i});
    }
    expect(recorder.latestEpisodeId, 6);
    expect(recorder.retainedEvents, 2);
    final report = recorder.finish();
    expect(report['capacityReached'], true);
    expect(report['blankEpisodes'], 6);
    expect(report['confirmedBlankEpisodes'], 6);
    expect(report['recoveredEpisodes'], 6);
    expect(report['droppedEvents'], 16);
  });

  test('deadline ends a stalled phase once and reset removes retained evidence',
      () {
    var now = 100;
    final reports = <Map<String, Object?>>[];
    final recorder = PoseOverlayBlankDiagnostics(
        enabled: true, clockMicros: () => now, onReport: reports.add);
    recorder.start('still', sessionId: 'session-1');
    final firstToken = recorder.captureToken;
    recorder.reportState(visible: false, reason: 'detector_no_person');
    now += 20000000;
    expect(recorder.finishIfExpired(), true);
    expect(recorder.finishIfExpired(), false);
    expect(reports, hasLength(1));
    expect(recorder.phase, isNull);
    expect(recorder.lastReport['openEpisodeAtCaptureEnd'], 1);
    recorder.start('slow', sessionId: 'session-1');
    expect(recorder.captureToken, isNot(firstToken));
    expect(recorder.retainedEvents, 0);
    recorder.clear();
    expect(recorder.phase, isNull);
    expect(recorder.captureToken, isNull);
    expect(recorder.lastReport, isEmpty);
    expect(recorder.latestEpisodeId, isNull);
  });

  test('retains finite metadata only and snapshots cannot leak coordinates',
      () {
    final recorder =
        PoseOverlayBlankDiagnostics(enabled: true, clockMicros: () => 100);
    recorder.start('still', sessionId: 'session-1');
    final context = <String, Object?>{
      'inputMicros': 1,
      'posePresence': double.nan,
      'detectorPersonConfidence': double.infinity,
      'roiSource': 'detector',
      'rawFrame': [1, 2, 3],
      'landmarks': {
        'elbow': [.2, .3]
      },
      'refinedCount': [1, 2],
    };
    recorder.reportState(
        visible: false, reason: 'nonfinite_landmarks', context: context);
    context['inputMicros'] = 99;
    final report = recorder.finish();
    final event = (report['events'] as List).single as Map;
    expect(event['inputMicros'], 1);
    expect(event['posePresence'], isNull);
    expect(event['detectorPersonConfidence'], isNull);
    expect(event.containsKey('rawFrame'), false);
    expect(event.containsKey('landmarks'), false);
    expect(event.containsKey('refinedCount'), false);
    expect(() => jsonEncode(report), returnsNormally);
  });

  test('disabled diagnostics observe nothing and never invoke report callbacks',
      () {
    final reports = <Map<String, Object?>>[];
    final recorder = PoseOverlayBlankDiagnostics(
        enabled: false, clockMicros: () => 100, onReport: reports.add);
    recorder.start('still', sessionId: 'session-1');
    recorder.reportState(visible: false, reason: 'freshness_expiry');
    recorder.painted(visible: false, reason: 'freshness_expiry');
    recorder.recordDiscard('stale_result');
    expect(recorder.finishIfExpired(), false);
    expect(recorder.finish(), isEmpty);
    expect(recorder.retainedEvents, 0);
    expect(recorder.latestEpisodeId, isNull);
    expect(recorder.captureToken, isNull);
    expect(reports, isEmpty);
  });
}
