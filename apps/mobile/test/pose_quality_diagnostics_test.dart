import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/infrastructure/pose/pose_quality_diagnostics.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

void main() {
  test(
      'confidence rejection and aspect suppression recover only on matching paint',
      () {
    var now = 100;
    final q = PoseQualityDiagnostics(
        clockMicros: () => now, enabled: true, blankEnabled: true);
    q.blanks.start('slow', sessionId: q.sessionId);
    PoseFrame f(int t, double v, double p) => PoseFrame(
            capturedAtMicros: t,
            detectorId: 'fixture',
            modelVersion: '1',
            landmarks: {
              PoseLandmark.leftElbow:
                  PosePoint(x: .5, y: .5, z: 0, visibility: v, presence: p)
            });
    final lowV = f(1, .1, 1), lowP = f(2, 1, .1), good = f(3, 1, 1);
    q.delivered(lowV, 0, refined: lowV);
    q.overlayPainted(lowV,
        primitivesIssued: 0, viewportIntersectingPrimitives: 0);
    now = 200;
    q.delivered(lowP, 0, refined: lowP);
    q.overlayPainted(lowP,
        primitivesIssued: 0, viewportIntersectingPrimitives: 0);
    now = 300;
    q.delivered(good, 0, refined: good);
    q.overlayPainted(null,
        reason: 'preview_aspect_mismatch',
        sourceFrame: good,
        primitivesIssued: 0,
        viewportIntersectingPrimitives: 0);
    expect(q.blanks.overlayBlank, true);
    q.overlayPainted(f(1, 1, 1),
        primitivesIssued: 1, viewportIntersectingPrimitives: 1);
    expect(q.blanks.overlayBlank, true,
        reason: 'obsolete paint cannot recover the latest delivered pose');
    q.overlayPainted(good,
        primitivesIssued: 1, viewportIntersectingPrimitives: 1);
    final report = q.blanks.finish();
    expect(report['reasonCounts'], {
      'landmark_visibility_rejection': 1,
      'landmark_joint_presence_rejection': 1,
      'preview_aspect_mismatch': 1
    });
    expect(report['recoveredEpisodes'], 1);
    final recovery = (report['events'] as List).last as Map;
    expect(recovery['kind'], 'recovery');
    expect(recovery['inputMicros'], 3);
  });

  test('expiry of an already empty frame preserves the original loss cause',
      () {
    var now = 200;
    final q = PoseQualityDiagnostics(
        clockMicros: () => now, enabled: true, blankEnabled: true);
    q.blanks.start('still', sessionId: q.sessionId);
    q.workerFrame({
      'frameTimestampMicros': 100,
      'outcome': 'low_landmark_pose_presence',
      'posePresence': .1,
      'timings': <String, int>{}
    });
    final f = PoseFrame(
        capturedAtMicros: 100,
        detectorId: 'fixture',
        modelVersion: '1',
        landmarks: {});
    q.delivered(f, 0, refined: f);
    q.overlayPainted(f, primitivesIssued: 0, viewportIntersectingPrimitives: 0);
    now = 400000;
    q.overlayCleared('freshness_expiry', f, watchdog: true);
    q.overlayPainted(null,
        primitivesIssued: 0, viewportIntersectingPrimitives: 0);
    final report = q.blanks.finish();
    expect(report['blankEpisodes'], 1);
    expect(report['reasonCounts'], {'low_landmark_pose_presence': 1});
  });

  test('blank causes join the delivered input rather than a newer worker trace',
      () {
    var now = 200;
    final q = PoseQualityDiagnostics(
        clockMicros: () => now, enabled: true, blankEnabled: true);
    q.blanks.start('slow', sessionId: q.sessionId);
    q.workerFrame({
      'frameTimestampMicros': 100,
      'outcome': 'detector_no_person',
      'detectorPersonConfidence': .2,
      'roiSource': 'detector',
      'timings': <String, int>{}
    });
    q.workerFrame({
      'frameTimestampMicros': 150,
      'outcome': 'low_landmark_pose_presence',
      'posePresence': .1,
      'roiSource': 'tracked_roi',
      'timings': <String, int>{}
    });
    q.delivered(
        PoseFrame(
            capturedAtMicros: 100,
            detectorId: 'fixture',
            modelVersion: '1',
            landmarks: {}),
        0);
    now = 210;
    q.overlayPainted(null,
        primitivesIssued: 0, viewportIntersectingPrimitives: 0);
    final events = q.blanks.finish()['events'] as List;
    final cause = events.firstWhere((e) => e['kind'] == 'blank_begin') as Map;
    expect(cause['reason'], 'detector_no_person');
    expect(cause['inputMicros'], 100);
    expect(cause['deliveryMicros'], 200);
    expect(cause['detectorPersonConfidence'], .2);
    expect(cause['roiSource'], 'detector');
    expect(events.any((e) => e['kind'] == 'blank_paint'), true);
  });

  test('a stale discard does not clear a valid pose before watchdog expiry',
      () {
    var now = 100;
    final q = PoseQualityDiagnostics(
        clockMicros: () => now, enabled: true, blankEnabled: true);
    q.blanks.start('still', sessionId: q.sessionId);
    final f = PoseFrame(
        capturedAtMicros: 1,
        detectorId: 'fixture',
        modelVersion: '1',
        landmarks: {
          PoseLandmark.leftShoulder:
              const PosePoint(x: .5, y: .5, z: 0, visibility: 1)
        });
    q.delivered(f, 0, refined: f);
    q.overlayPainted(f, primitivesIssued: 1, viewportIntersectingPrimitives: 1);
    now = 200;
    q.discard(50, 'stale_result');
    expect(q.blanks.overlayBlank, false);
    now = 300001;
    q.overlayCleared('freshness_expiry', f, watchdog: true);
    q.overlayPainted(null,
        primitivesIssued: 0, viewportIntersectingPrimitives: 0);
    final events = q.blanks.finish()['events'] as List;
    final cause = events.firstWhere((e) => e['kind'] == 'blank_begin') as Map;
    expect(cause['reason'], 'freshness_expiry');
    expect(cause['lastValidPoseAgeMicros'], 300000);
    expect(cause['watchdogClearedValidPose'], true);
    expect(cause['latestDiscardReason'], 'stale_result');
  });

  test(
      'FPS excludes empty results from drawable overlays and resets interval deltas',
      () {
    final q = PoseQualityDiagnostics(clockMicros: () => 100, enabled: true);
    PoseFrame frame(int time, bool empty) => PoseFrame(
        capturedAtMicros: time,
        detectorId: 'fixture',
        modelVersion: '1',
        landmarks: empty
            ? {}
            : {
                PoseLandmark.leftShoulder: const PosePoint(
                    x: .2, y: .3, z: 0, visibility: .9, presence: .9)
              });
    q.delivered(frame(1, false), 0);
    q.delivered(frame(2, true), 0);
    q.delivered(frame(3, false), 0);
    final first = q.snapshot(
        activeMicros: 1000000, received: 30, processed: 10, delivered: 10);
    expect(first['intervalFps'], {
      'cameraReceived': 30.0,
      'processed': 10.0,
      'deliveredOverlay': 10.0,
      'drawableOverlay': 2.0
    });
    q.delivered(frame(4, false), 0);
    final second = q.snapshot(
        activeMicros: 2000000, received: 60, processed: 19, delivered: 18);
    expect(second['intervalFps'], {
      'cameraReceived': 30.0,
      'processed': 9.0,
      'deliveredOverlay': 8.0,
      'drawableOverlay': 1.0
    });
  });
}
