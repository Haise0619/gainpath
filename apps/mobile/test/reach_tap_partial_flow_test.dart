import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/gamification/domain/reach_tap.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/reach_tap_view.dart';
import 'package:gainpath_mobile/infrastructure/pose/reach_tap_pose_camera.dart'
    as adapter;
import 'package:gainpath_mobile/infrastructure/pose/blazepose_contract.dart';
import 'reach_tap_recovery_flow_test.dart' show RecoveryHarness;
import 'support/reach_tap_fixture.dart' as fixture;
import 'reach_tap_body_motion_test.dart' show moving;

PoseFrame observedFrame(ReachTapSample s,
    {bool hideLeft = false, bool elbowsHidden = false, Point<double>? right}) {
  final rows = {
    PoseLandmark.leftShoulder: s.leftShoulder,
    PoseLandmark.rightShoulder: s.rightShoulder,
    if (!elbowsHidden) PoseLandmark.leftElbow: s.leftElbow,
    if (!elbowsHidden) PoseLandmark.rightElbow: s.rightElbow,
    if (!hideLeft) PoseLandmark.leftWrist: s.leftHand,
    PoseLandmark.rightWrist: right ?? s.rightHand,
    PoseLandmark.leftHip: s.leftHip,
    PoseLandmark.rightHip: s.rightHip,
  };
  return PoseFrame(
      capturedAtMicros: s.capturedAtMicros,
      imageWidth: 400,
      imageHeight: 800,
      detectorId: 'blazepose-tflite',
      modelVersion: BlazePoseModelContract.version,
      landmarks: rows.map((id, p) => MapEntry(id,
          PosePoint(x: p!.x, y: p.y, z: 0, visibility: .99, presence: .99))));
}

void main() {
  test('real camera/controller keeps side steps and jump-to-hit in active play',
      () async {
    final h = RecoveryHarness();
    addTearDown(h.controller.dispose);
    await h.controller.startCamera(consented: true);
    void deliver(
        {double dx = 0,
        double dy = 0,
        Point<double>? hand,
        bool hidden = false}) {
      h.now += 50000;
      final raw = observedFrame(moving(h.now, dx: dx, dy: dy),
          hideLeft: hidden, right: hand);
      h.camera.receive!(adapter.reachTapSample(raw,
          boardWidth: 400,
          boardHeight: 800,
          previewWidth: 400,
          previewHeight: 800,
          mirrored: false));
      h.controller.tick();
    }

    for (var i = 0;
        i < 130 && h.controller.engine.phase != ReachTapPhase.playing;
        i++) {
      deliver();
    }
    expect(h.controller.engine.phase, ReachTapPhase.playing);
    final beforeTime = h.controller.engine.activeMicros;
    for (var i = 1; i <= 20; i++) {
      deliver(
          dx: .18 * sin(i * pi / 20),
          dy: -.16 * sin(i * pi / 20),
          hidden: i > 10);
      expect(h.controller.engine.phase, ReachTapPhase.playing,
          reason: h.controller.engine.feedback);
    }
    expect(h.controller.engine.activeMicros - beforeTime, 1000000);
    final beforeHits = h.controller.engine.hits;
    final target = h.controller.engine.target!;
    for (var i = 0; i < 20 && h.controller.engine.hits == beforeHits; i++) {
      deliver(dx: -.15, dy: -.12, hand: target, hidden: true);
    }
    expect(h.controller.engine.hits, beforeHits + 1);
    expect(h.controller.engine.leftHand, isNull);
    expect(h.camera.resumes, 0);
    final active = h.controller.engine.activeMicros;
    final score = h.controller.engine.score;
    h.now += 50000;
    h.camera.receive!(null);
    h.controller.tick();
    expect(h.controller.engine.phase, ReachTapPhase.recovering);
    expect(h.controller.engine.activeMicros, active);
    expect(h.controller.engine.score, score);
    for (var i = 0; i < 9; i++) {
      deliver(dx: -.15, dy: -.12, hidden: true);
    }
    expect(h.controller.engine.phase, ReachTapPhase.playing);
    expect(h.controller.engine.activeMicros, active);
    expect(h.controller.engine.score, score);
  });

  test(
      'real adapter observations keep a visible hand scoring during opposite occlusion',
      () async {
    final h = RecoveryHarness();
    addTearDown(h.controller.dispose);
    await h.controller.startCamera(consented: true);
    void deliver(
        {bool hidden = false, bool elbows = false, Point<double>? right}) {
      h.now += 50000;
      final input = observedFrame(fixture.reachTapSample(h.now),
          hideLeft: hidden, elbowsHidden: elbows, right: right);
      h.camera.receive!(adapter.reachTapSample(input,
          boardWidth: 400,
          boardHeight: 800,
          previewWidth: 400,
          previewHeight: 800,
          mirrored: false));
      h.controller.tick();
    }

    for (var i = 0;
        i < 130 && h.controller.engine.phase != ReachTapPhase.playing;
        i++) {
      deliver();
    }
    expect(h.controller.engine.phase, ReachTapPhase.playing);
    final target = h.controller.engine.target!,
        before = h.controller.engine.activeMicros;
    for (var i = 0; i < 16 && h.controller.engine.hits == 0; i++) {
      deliver(hidden: true, elbows: true, right: target);
    }
    expect(h.controller.engine.phase, ReachTapPhase.playing);
    expect(h.controller.engine.hits, 1);
    expect(h.controller.engine.leftHand, isNull);
    expect(h.controller.engine.rightHand, isNotNull);
    expect(h.controller.engine.activeMicros, greaterThan(before));
    expect(h.camera.resumes, 0);
    final score = h.controller.engine.score;
    await h.controller.background();
    h.controller.foreground();
    for (var i = 0; i < 12; i++) {
      deliver(hidden: true, right: target);
    }
    expect(h.controller.engine.phase, ReachTapPhase.paused);
    expect(h.controller.engine.score, score);
  });
  testWidgets('single observed hand status stays visible over compact board',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = RecoveryHarness();
    addTearDown(h.controller.dispose);
    await h.controller.startCamera(consented: true);
    for (var i = 0;
        i < 130 && h.controller.engine.phase != ReachTapPhase.playing;
        i++) {
      h.now += 50000;
      final f = observedFrame(fixture.reachTapSample(h.now));
      h.camera.receive!(adapter.reachTapSample(f,
          boardWidth: 400,
          boardHeight: 800,
          previewWidth: 400,
          previewHeight: 800,
          mirrored: false));
      h.controller.tick();
    }
    expect(h.controller.engine.phase, ReachTapPhase.playing);
    h.now += 50000;
    final f = observedFrame(fixture.reachTapSample(h.now), hideLeft: true);
    h.camera.receive!(adapter.reachTapSample(f,
        boardWidth: 400,
        boardHeight: 800,
        previewWidth: 400,
        previewHeight: 800,
        mirrored: false));
    h.controller.tick();
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: ReachTapView(
            controller: h.controller,
            viewport: const ColoredBox(color: Colors.black))));
    expect(find.text('Right hand tracking · left hand not visible'),
        findsOneWidget);
    final board = tester.getRect(find.byKey(const ValueKey('reach-tap-board'))),
        cue = tester
            .getRect(find.text('Right hand tracking · left hand not visible'));
    expect(cue.top, greaterThanOrEqualTo(board.top));
    expect(cue.bottom, lessThanOrEqualTo(board.bottom));
    expect(tester.takeException(), isNull);
  });
}
