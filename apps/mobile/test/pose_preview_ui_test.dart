import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/pose_preview_controller.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/live_workout_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'package:gainpath_mobile/infrastructure/pose/pose_joint_lag_diagnostics.dart';

class Camera implements PoseCameraSource {
  int stops = 0;
  @override
  Future<void> start(void Function(PoseInput) onFrame) async {}
  @override
  void invalidate() {}
  @override
  Future<void> stop() async {
    stops++;
  }
}

class Detector implements ManagedPoseDetector {
  @override
  Future<PoseFrame> detect(PoseInput input) async => throw UnimplementedError();
  @override
  Future<void> reset() async {}
  @override
  Future<void> close() async {}
}

void main() {
  testWidgets(
      'Capture 20s starts both bounded reports through the Workout button',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var now = 100;
    final scope = SessionScope(userId: 'u', organizationId: 'gainpath');
    final c = PosePreviewController(
        scope: scope,
        activeScope: () => scope,
        camera: Camera(),
        detectorFactory: () async => Detector(),
        clockMicros: () => now);
    await c.start(consented: true);
    await tester.pumpWidget(MaterialApp(
        home: LiveWorkoutScreen(
            cameraSession: c,
            cameraViewport: const ColoredBox(color: Colors.black))));
    expect(find.text('Capture 20s'), findsOneWidget);
    await tester.tap(find.text('Capture 20s'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(c.quality.lag.phase, 'still');
    expect(c.quality.blanks.phase, 'still');
    expect(find.text('still: 20s'), findsOneWidget);
    now += 20000000;
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.quality.lag.lastReport['phase'], 'still');
    expect(c.quality.blanks.lastReport['phase'], 'still');
    expect(find.text('Capture 20s'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await c.close();
    c.dispose();
  },
      skip: !const bool.fromEnvironment('GAINPATH_POSE_QUALITY_DEBUG') ||
          !const bool.fromEnvironment('GAINPATH_POSE_JOINT_LAG_DEBUG') ||
          !const bool.fromEnvironment('GAINPATH_POSE_BLANK_DEBUG'));

  testWidgets(
      'development preview requests local consent before opening a camera route',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: WorkoutPrepScreen(live: true)));
    await tester.scrollUntilVisible(find.text('Try live camera preview'), 250);
    await tester.tap(find.text('Try live camera preview'));
    await tester.pumpAndSettle();
    expect(find.text('This preview does not save activity or count reps.'),
        findsOneWidget);
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Accept and start'));
    expect(button.onPressed, isNull);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Try live camera preview'), findsOneWidget);
  }, skip: !const bool.fromEnvironment('GAINPATH_POSE_PREVIEW'));
  testWidgets(
      'camera foundation uses Workout viewport without simulated metrics; End closes locally',
      (tester) async {
    final scope = SessionScope(userId: 'u', organizationId: 'gainpath');
    final camera = Camera();
    final controller = PosePreviewController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => Detector(),
        clockMicros: () => 100);
    await controller.start(consented: true);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => LiveWorkoutScreen(
                                cameraSession: controller,
                                cameraViewport:
                                    const ColoredBox(color: Colors.black)))),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
        find.text(poseRefinedSkeletonDebugEnabled
            ? 'Refined skeleton / filtered dots'
            : 'Local camera preview'),
        findsOneWidget);
    expect(find.text('REPS'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect(controller.phase, PosePreviewPhase.paused);
    await tester.tap(find.text('End preview'));
    await tester.pumpAndSettle();
    expect(controller.phase, PosePreviewPhase.closed);
    expect(find.text('Open'), findsOneWidget);
    controller.dispose();
  });
}
