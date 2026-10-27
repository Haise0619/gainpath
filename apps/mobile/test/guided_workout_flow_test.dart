import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, MemberPreferences;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/guided_workout_progress.dart';
import 'package:gainpath_mobile/features/workout/application/real_squat_session_controller.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_audio_port.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/live_workout_screen.dart';
import 'real_squat_session_test.dart' as support;
import 'squat_processing_controller_test.dart' as poses;

void main() {
  testWidgets(
      'guided camera flow recalibrates, rests between measured sets and saves once',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    final camera = support.Camera(), detector = support.Detector();
    final store = InMemoryWorkoutSessionStore(scope: scope);
    final voiceModes = <WorkoutVoiceMode>[];
    var now = 0;
    final c = RealSquatSessionController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => detector,
        audioPort: poses.AudioSink(),
        repository: WorkoutSessionRepository(
            scope: scope,
            store: store,
            uploadGateway: UnavailableWorkoutUploadGateway(),
            activeScope: () => scope),
        clockMicros: () => now,
        sessionId: 'guided',
        exerciseId: 'squat',
        publishedRoutineId: 'routine',
        detectorId: 'fixture',
        detectorVersion: '1',
        provenance: WorkoutProvenance.recordedFixture,
        guidance: GuidedWorkoutProgress(sets: 2, repetitions: 1),
        saveVoiceMode: (mode) async {
          voiceModes.add(mode);
        });
    await c.start(consented: true, setupConfirmed: true);
    await tester.pumpWidget(MaterialApp(
        home: LiveWorkoutScreen(
            realSession: c,
            cameraViewport: const ColoredBox(color: Colors.black),
            targetRepetitions: 1)));
    Future<void> send(double angle) async {
      now += 100000;
      detector.angle = angle;
      camera.receive!(PoseInput(timestampMicros: now));
      await tester.pump();
    }

    Future<void> squat() async {
      for (var i = 0; i < 12; i++) {
        await send(175);
      }
      for (var i = 1; i <= 20; i++) {
        await send(175.0 - i * 5);
      }
      for (var i = 0; i < 8; i++) {
        await send(75);
      }
      for (var i = 1; i <= 20; i++) {
        await send(75.0 + i * 5);
      }
      for (var i = 0; i < 12; i++) {
        await send(175);
      }
    }

    await tester.tap(find.byTooltip('Voice feedback: Muted'));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) =>
        widget is CheckedPopupMenuItem<WorkoutVoiceMode> &&
        widget.value == WorkoutVoiceMode.alertsOnly));
    await tester.pumpAndSettle();
    c.applySavedVoiceMode(WorkoutVoiceMode.fullCoaching);
    c.applyPreferences(const MemberPreferences(voiceCoaching: false));
    expect(c.voiceMode, WorkoutVoiceMode.alertsOnly);
    expect(voiceModes, [WorkoutVoiceMode.alertsOnly]);

    await tester.tap(find.byTooltip('Recalibrate camera'));
    await tester.pump();
    expect(c.isRecalibrating, true);
    await send(175);
    await tester.tap(find.text('Use this position'));
    await tester.pump();
    expect(c.isRecalibrating, false);
    await squat();
    expect(c.guidance!.stage, GuidedWorkoutStage.resting);
    expect(c.latest!.repetitions, 1);
    expect(c.processing.isPaused, true);
    expect(find.text('REST · SET 1 / 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Expand workout details'));
    await tester.pumpAndSettle();
    expect(find.text('Skip rest & start set 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Collapse workout details'));
    await tester.pumpAndSettle();
    await c.setForeground(false);
    now += 90000000;
    await tester.pump(const Duration(milliseconds: 250));
    expect(c.guidance!.remainingRestSeconds, greaterThan(0));
    await c.setForeground(true);
    await tester.pump();
    final next = find.byTooltip('Skip rest & start set 2');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pump();
    await squat();
    expect(c.guidance!.stage, GuidedWorkoutStage.complete);
    expect(c.latest!.repetitions, 2);
    expect(c.processing.isPaused, true);
    final end = find.byTooltip('End session');
    await tester.ensureVisible(end);
    await tester.tap(end);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save result'));
    await tester.pumpAndSettle();
    expect(find.text('Saved on this device'), findsOneWidget);
    expect((await store.read()).single.summary.repetitions, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await c.close();
    c.dispose();
  });
}
