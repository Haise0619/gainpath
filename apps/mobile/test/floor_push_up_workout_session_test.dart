import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/navigation/workout_navigation.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/floor_push_up_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/guided_workout_progress.dart';
import 'package:gainpath_mobile/features/workout/application/measured_workout_session.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/exercise_tracker_dispatcher.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_result_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/real_workout_view.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_audio_port.dart';
import 'support/floor_push_up_trajectory.dart';
import 'real_squat_session_test.dart' show Camera, FailingStore;
import 'squat_processing_controller_test.dart' show AudioSink;

class FloorDetector implements ManagedPoseDetector {
  FloorDetector({this.right = false});
  final bool right;
  double angle = 170;
  double visibility = .99;
  @override
  Future<PoseFrame> detect(PoseInput input) async =>
      floorFrame(input.timestampMicros, angle,
          right: right, visibility: visibility);
  @override
  Future<void> reset() async {}
  @override
  Future<void> close() async {}
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  testWidgets(
      'accepted plank clears warning, brief loss stays stable, and measured rep reaches UI',
      (tester) async {
    var now = 0;
    final camera = Camera(), detector = FloorDetector(), audio = AudioSink();
    final store = FailingStore(scope: scope)..fail = false;
    final repo = WorkoutSessionRepository(
        scope: scope,
        store: store,
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => scope);
    Map<String, Object?>? latestDiagnostics;
    final session = FloorPushUpWorkoutSession(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => detector,
        audioPort: audio,
        repository: repo,
        clockMicros: () => now,
        sessionId: 'floor-recovery',
        exerciseId: 'standard-floor-push-up-side-v1',
        detectorId: 'fixture',
        detectorVersion: '1',
        sets: 1,
        reps: 8,
        provenance: WorkoutProvenance.recordedFixture,
        onLocalDiagnostics: (value) => latestDiagnostics = value);
    await session.start(consented: true, setupConfirmed: true);
    session.setVoiceMode(WorkoutVoiceMode.fullCoaching, persist: false);
    await tester.pumpWidget(MaterialApp(
        home: RealWorkoutView(
            session: session,
            viewport: const SizedBox(),
            exerciseName: 'Standard Floor Push-Up',
            targetRepetitions: 8)));
    Future<void> hold(double angle, int n, {double visibility = .99}) async {
      for (var i = 0; i < n; i++) {
        now += 50000;
        detector.angle = angle;
        detector.visibility = visibility;
        camera.receive!(PoseInput(timestampMicros: now));
        await tester.pump();
      }
    }

    await hold(170, 14);
    expect(find.text('Ready — start your push-ups.'), findsOneWidget);
    await hold(170, 1, visibility: .60);
    expect(find.text('Ready — start your push-ups.'), findsOneWidget);
    await hold(170, 2);
    for (final a in [
      150.0,
      130.0,
      110.0,
      90.0,
      90.0,
      90.0,
      110.0,
      130.0,
      150.0,
      170.0,
      170.0
    ]) {
      await hold(a, 4);
    }
    expect(find.text('1 / 8'), findsOneWidget);
    expect((latestDiagnostics!['analyzer'] as Map)['repetitions'], 1);
    expect(find.textContaining('Adjust your camera position'), findsNothing);
    await hold(170, 64, visibility: .1);
    expect(audio.played.where((c) => c.id == 'floor_tracking').length,
        lessThanOrEqualTo(1));
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    repo.dispose();
  });
  testWidgets(
      'workout tools exclude the obsolete local floor testing shortcut',
      (tester) async {
    late AuthBloc auth;
    await tester.runAsync(() async {
      auth = AuthBloc(
          repository: InMemoryAuthRepository(organizationId: 'gainpath'));
      await Future<void>.delayed(Duration.zero);
      auth.add(const LoginSubmitted(
          email: 'member@example.com', password: 'password123'));
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedIn);
    });
    RealWorkoutLaunch? launch;
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: WorkoutPrepScreen(
                live: true,
                organizationId: 'gainpath',
                routes: WorkoutPrepRoutes(realSessionBuilder: (_, value) {
                  launch = value;
                  return const Scaffold(body: Text('Floor camera'));
                })))));
    await tester.pumpAndSettle();
    expect(find.text('Standard Floor Push-Up'), findsNothing);
    expect(find.textContaining('Local practice'), findsNothing);
    expect(launch, isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => auth.close());
  });
  test(
      'floor and wall identities dispatch independently and fail closed by org',
      () {
    const d = ExerciseTrackerDispatcher();
    final floor = d.resolve(
        organizationId: 'gainpath',
        exerciseId: 'standard-floor-push-up-side-v1');
    expect(floor.tracker, ExerciseTracker.sideViewFloorPushUp);
    expect(
        d
            .resolve(
                organizationId: 'gainpath', exerciseId: 'wall-push-up-side-v1')
            .tracker,
        ExerciseTracker.sideViewWallPushUp);
    expect(
        ExerciseTrackingRegistry.resolve(
                organizationId: 'other',
                exerciseId: 'standard-floor-push-up-side-v1')
            .hasPoseTracking,
        false);
  });
  for (final right in [false, true]) {
    testWidgets(
        'floor side=$right completes sets and retries one durable result',
        (tester) async {
      var now = 0;
      final camera = Camera(),
          detector = FloorDetector(right: right),
          store = FailingStore(scope: scope);
      final repo = WorkoutSessionRepository(
          scope: scope,
          store: store,
          uploadGateway: UnavailableWorkoutUploadGateway(),
          activeScope: () => scope);
      final session = FloorPushUpWorkoutSession(
          scope: scope,
          activeScope: () => scope,
          camera: camera,
          detectorFactory: () async => detector,
          audioPort: AudioSink(),
          repository: repo,
          clockMicros: () => now,
          sessionId: 'floor-${right ? 'right' : 'left'}',
          exerciseId: 'standard-floor-push-up-side-v1',
          publishedRoutineId: 'routine',
          detectorId: 'fixture',
          detectorVersion: '1',
          sets: 2,
          reps: 1,
          provenance: WorkoutProvenance.recordedFixture);
      await session.start(consented: false, setupConfirmed: true);
      expect(camera.starts, 0);
      await session.start(consented: true, setupConfirmed: true);
      Future<void> hold(double angle, int n) async {
        for (var i = 0; i < n; i++) {
          now += 50000;
          detector.angle = angle;
          camera.receive!(PoseInput(timestampMicros: now));
          await tester.pump();
        }
      }

      Future<void> cycle() async {
        await hold(170, 14);
        for (final a in [
          150.0,
          130.0,
          110.0,
          90.0,
          90.0,
          90.0,
          110.0,
          130.0,
          150.0,
          170.0,
          170.0
        ]) {
          await hold(a, 4);
        }
      }

      await cycle();
      expect(session.guidance.stage, GuidedWorkoutStage.resting);
      session.startNextSet(skipRest: true);
      await cycle();
      expect(session.guidance.stage, GuidedWorkoutStage.complete);
      expect(await session.endAndSave(), isNull);
      expect(session.viewPhase, MeasuredWorkoutPhase.saveFailed);
      store.fail = false;
      final saved = (await session.endAndSave())!;
      expect(saved.repetitions, 2);
      expect(saved.poseMetrics!.toJson()['schemaVersion'], 7);
      expect(saved.poseMetrics!.floorPushUp!.side, right ? 'right' : 'left');
      expect(saved.poseMetrics!.floorPushUp!.sourceVersion,
          'floor-push-up-2d-crosscheck-v1');
      expect(saved.formScorePercent, greaterThan(85));
      expect(WorkoutSessionSummary.fromJson(saved.toJson()), saved);
      expect((await repo.loadHistory()).length, 1);
      expect(saved.isEligibleForRealUpload, false);
      await tester.pumpWidget(
          MaterialApp(home: WorkoutResultScreen.measured(summary: saved)));
      await tester.pumpAndSettle();
      expect(find.text('MEASURED FLOOR PUSH-UP RESULT'), findsOneWidget);
      expect(find.textContaining('Range of motion:'), findsOneWidget);
      final forged = saved.toJson()..['exerciseId'] = 'wall-push-up-side-v1';
      expect(
          () => WorkoutSessionSummary.fromJson(forged), throwsFormatException);
      final raw = Map<String, Object?>.from(saved.poseMetrics!.toJson())
        ..['schemaVersion'] = 1;
      expect(() => WorkoutPoseMetrics.fromJson(raw), throwsFormatException);
      session.dispose();
      repo.dispose();
    });
  }
  testWidgets(
      'floor setup requires acknowledgement and has no accepted-upload control',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showWorkoutCaptureConsent(context,
                        onUploadChanged: (_) {},
                        allowUpload: false,
                        exerciseInstruction: floorPushUpCaptureInstruction,
                        setupConfirmationLabel: floorPushUpSetupConfirmation),
                    child: const Text('Start'))))));
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text(floorPushUpSetupConfirmation), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Accept and start'))
            .onPressed,
        isNull);
    expect(find.text('Also allow this measured summary to be uploaded.'),
        findsNothing);
  });
}
