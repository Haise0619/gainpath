import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/reverse_lunge_camera_check.dart';
import 'reverse_lunge_feedback_session_test.dart' show FeedbackHarness;
import 'support/reverse_lunge_trajectory.dart';
import 'real_squat_session_test.dart' show Camera;

class RetryCamera extends Camera {
  bool fail = true;
  @override
  Future<void> start(void Function(PoseInput) receive) async {
    if (fail) throw StateError('permission denied');
    await super.start(receive);
  }
}

void main() {
  testWidgets('camera failure is visible and retry never bypasses readiness',
      (tester) async {
    final source = RetryCamera();
    final live = FeedbackHarness(LungeSide.left,
        requireCameraCheck: true, source: source);
    addTearDown(live.dispose);
    await live.session.start(consented: true, setupConfirmed: true);
    await tester.pumpWidget(MaterialApp(
        home: ReverseLungeCameraCheck(
            session: live.session, viewport: const SizedBox())));
    expect(find.text(live.session.errorMessage!), findsOneWidget);
    expect(live.session.canConfirmCameraCheck, false);
    source.fail = false;
    await live.session.retryCameraCheck();
    await tester.pump();
    expect(live.session.errorMessage, isNull);
    expect(live.session.canConfirmCameraCheck, false);
    await tester.pumpWidget(const SizedBox());
    await live.session.close();
  });
  testWidgets(
      'background clears ready and model mismatch cannot confirm camera check',
      (tester) async {
    final h = FeedbackHarness(LungeSide.left, requireCameraCheck: true);
    addTearDown(h.dispose);
    await h.session.start(consented: true, setupConfirmed: true);
    for (var t = 0; t <= 1000000; t += 50000) {
      await h.feed(tester, reverseLungeFrame(t, 0, 0));
    }
    expect(h.session.canConfirmCameraCheck, true);
    await h.session.setForeground(false);
    expect(h.session.canConfirmCameraCheck, false);
    await h.session.setForeground(true);
    await h.feed(tester, reverseLungeFrame(1050000, 0, 0));
    expect(h.session.canConfirmCameraCheck, false);
    final f = reverseLungeFrame(1100000, 0, 0);
    await h.feed(
        tester,
        PoseFrame(
            capturedAtMicros: f.capturedAtMicros,
            detectorId: f.detectorId,
            modelVersion: 'other',
            imageWidth: f.imageWidth,
            imageHeight: f.imageHeight,
            landmarks: f.landmarks));
    expect(h.session.canConfirmCameraCheck, false);
    expect(h.session.errorMessage, contains('model changed'));
    await h.session.close();
  });
  testWidgets(
      'camera check cannot count before hands-free countdown or silently swap legs',
      (tester) async {
    final h = FeedbackHarness(LungeSide.left, requireCameraCheck: true);
    addTearDown(h.dispose);
    await h.session.start(consented: true, setupConfirmed: true);
    for (final f in reverseLungeTrajectory()) {
      await h.feed(tester, f);
    }
    expect(h.session.analysis!.repetitions, 0);
    expect(h.session.cameraCheckPending, true);
    h.session.selectCameraCheckSide(LungeSide.right);
    expect(h.session.side, LungeSide.right);
    expect(h.session.selectedLegLabel, 'Right front leg');
    expect(h.session.canConfirmCameraCheck, false);
    for (var t = 4350000; t <= 5350000; t += 50000) {
      await h.feed(tester, reverseLungeFrame(t, 0, 0, side: LungeSide.right));
    }
    expect(h.session.canConfirmCameraCheck, true);
    h.now += 300000;
    expect(h.session.canConfirmCameraCheck, false);
    await h.feed(
        tester, reverseLungeFrame(5400000, 0, 0, side: LungeSide.right));
    // Watchdog invalidates stale calibration; a fresh sample alone cannot unlock it.
    for (var t = 5450000; t <= 6450000; t += 50000) {
      await h.feed(tester, reverseLungeFrame(t, 0, 0, side: LungeSide.right));
    }
    for (var t = 6500000; t <= 10000000; t += 50000) {
      await h.feed(tester, reverseLungeFrame(t, 0, 0, side: LungeSide.right));
    }
    expect(h.session.cameraCheckPending, false);
    expect(h.session.selectedLegLabel, 'Right front leg');
    h.session.selectCameraCheckSide(LungeSide.left);
    expect(h.session.side, LungeSide.right);
    for (final f in reverseLungeTrajectory(
        side: LungeSide.right, startMicros: 10050000)) {
      await h.feed(tester, f);
    }
    expect(h.session.analysis!.repetitions, 1);
    final saved = (await h.session.endAndSave())!;
    expect(saved.poseMetrics!.lungeSide, 'right');
  });
  testWidgets(
      'compact large-text camera check shows selected leg and blocking feedback',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = FeedbackHarness(LungeSide.left, requireCameraCheck: true);
    addTearDown(h.dispose);
    await h.session.start(consented: true, setupConfirmed: true);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: ReverseLungeCameraCheck(
            session: h.session, viewport: const SizedBox(height: 160))));
    expect(find.text('Left front leg stays planted'), findsOneWidget);
    final liveStatus = find.byKey(const ValueKey('lunge-live-status'));
    expect(tester.getRect(liveStatus).top, greaterThanOrEqualTo(0));
    expect(tester.getRect(liveStatus).bottom, lessThanOrEqualTo(640));
    expect(
        tester
            .widget<AspectRatio>(
                find.byKey(const ValueKey('lunge-camera-framing')))
            .aspectRatio,
        9 / 16);
    expect(find.text('Confirm planted leg and begin'), findsNothing);
    expect(find.byKey(const ValueKey('lunge-auto-start')), findsOneWidget);
    await tester.ensureVisible(find.text('Right front leg'));
    await tester.tap(find.text('Right front leg'));
    await tester.pump();
    expect(h.session.side, LungeSide.right);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await h.session.close();
  });
}
