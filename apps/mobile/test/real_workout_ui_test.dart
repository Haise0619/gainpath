import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_result_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AppRole, SessionScope;
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/app/routing/saved_squat_sessions_route.dart';
import 'package:gainpath_mobile/features/workout/application/real_squat_session_controller.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/real_workout_view.dart';
import 'real_squat_session_test.dart' as support;
import 'squat_processing_controller_test.dart' as poses;
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'package:gainpath_mobile/features/workout/data/published_routine.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'supported published squat requires both consent and camera setup confirmation',
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
    final routine = PublishedRoutine.fromDocument('published', {
      'schemaVersion': 1,
      'kind': 'routine',
      'status': 'published',
      'sourceBlueprintId': 'blueprint',
      'title': 'Squat practice',
      'estimatedMinutes': 10,
      'exercises': [
        {
          'exerciseId': 'F3b8xIr8ynBDd3gEICKX',
          'name': 'Squat',
          'sets': 3,
          'reps': 8
        }
      ]
    });
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: WorkoutPrepScreen(live: true, publishedRoutine: routine))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start guided session'));
    await tester.pumpAndSettle();
    final accept = find.widgetWithText(FilledButton, 'Accept and start');
    expect(tester.widget<FilledButton>(accept).onPressed, isNull);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(tester.widget<FilledButton>(accept).onPressed, isNull);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();
    expect(tester.widget<FilledButton>(accept).onPressed, isNotNull);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Squat practice'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => auth.close());
  });
  testWidgets(
      'save failure keeps the result visible and retry waits for durable success',
      (tester) async {
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    final camera = support.Camera(), detector = support.Detector();
    final store = support.FailingStore(scope: scope);
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
        sessionId: 'ui-id',
        exerciseId: 'squat',
        publishedRoutineId: 'routine',
        detectorId: 'fixture',
        detectorVersion: '1',
        provenance: WorkoutProvenance.recordedFixture);
    await c.start(consented: true, setupConfirmed: true);
    now = 100000;
    camera.receive!(PoseInput(timestampMicros: now));
    await tester.pump();
    camera.failStop = true;
    await tester.pumpWidget(MaterialApp(
        home: RealWorkoutView(
            session: c,
            viewport: const ColoredBox(color: Colors.black),
            exerciseName: 'Squat',
            targetRepetitions: 8)));
    await tester.tap(find.text('End session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save result'));
    await tester.pumpAndSettle();
    expect(find.text('Retry save'), findsOneWidget);
    expect(find.text('Saved on this device'), findsNothing);
    store.fail = false;
    await tester.tap(find.text('Retry save'));
    await tester.pumpAndSettle();
    expect(find.text('Saved on this device'), findsOneWidget);
    expect((await store.read()).single.summary.sessionId, 'ui-id');
    await c.close();
    c.dispose();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('saved measured history is scoped and disappears after logout',
      (tester) async {
    late AuthBloc auth;
    await tester.runAsync(() async {
      auth = AuthBloc(repository: InMemoryAuthRepository());
      await Future<void>.delayed(Duration.zero);
      auth.add(const RoleSelected(AppRole.member));
      auth.add(const LoginSubmitted(
          email: 'member@example.com', password: 'password123'));
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedIn);
    });
    final scope = auth.state.session!.scope, start = DateTime.utc(2026, 10, 12);
    final summary = WorkoutSessionSummary(
        sessionId: 'history-id',
        userId: scope.userId,
        organizationId: scope.organizationId,
        exerciseId: 'squat',
        repetitions: 0,
        accuracy: 0,
        startedAt: start,
        endedAt: start.add(const Duration(seconds: 1)),
        provenance: WorkoutProvenance.realCamera,
        poseMetrics: WorkoutPoseMetrics(
            partialRepetitions: 0,
            trackedDurationMicros: 0,
            rejectedDurationMicros: 1000000,
            formScorePercent: null,
            scoringVersion: 'bodyweight-squat-side-v1',
            detectorId: 'blazepose-tflite',
            detectorVersion: 'v1',
            cameraView: 'side',
            consentVersion: 'pose-local-summary-v1',
            consentedAt: start));
    final store = InMemoryWorkoutSessionStore(scope: scope);
    await store.write([
      WorkoutSessionRecord(summary: summary, status: WorkoutSyncStatus.pending)
    ]);
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: SavedSquatSessionsRoute(
                scope: scope, storeFactory: (_) async => store))));
    await tester.pumpAndSettle();
    expect(find.text('0 full reps · 0 partial'), findsOneWidget);
    await tester.tap(find.text('0 full reps · 0 partial'));
    await tester.pumpAndSettle();
    expect(find.text('Saved on this device'), findsOneWidget);
    await tester.runAsync(() async {
      auth.add(const LoggedOut());
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedOut);
    });
    await tester.pumpAndSettle();
    expect(find.text('Saved on this device'), findsNothing);
    expect(find.text('Sign in to view this account’s result.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => auth.close());
  });
  testWidgets(
      'measured result shows local status, nullable form and no invented rewards',
      (tester) async {
    final start = DateTime.utc(2026, 10, 8);
    final result = WorkoutSessionSummary(
        sessionId: 'one',
        userId: 'member',
        organizationId: 'gainpath',
        exerciseId: 'F3b8xIr8ynBDd3gEICKX',
        repetitions: 0,
        accuracy: 0,
        startedAt: start,
        endedAt: start.add(const Duration(seconds: 5)),
        provenance: WorkoutProvenance.realCamera,
        poseMetrics: WorkoutPoseMetrics(
            partialRepetitions: 0,
            trackedDurationMicros: 2000000,
            rejectedDurationMicros: 3000000,
            formScorePercent: null,
            scoringVersion: 'bodyweight-squat-side-v1',
            detectorId: 'blazepose-tflite',
            detectorVersion: 'v1',
            cameraView: 'side',
            consentVersion: 'pose-local-summary-v1',
            consentedAt: start));
    await tester.pumpWidget(
        MaterialApp(home: WorkoutResultScreen.measured(summary: result)));
    await tester.pumpAndSettle();
    expect(find.text('Saved on this device'), findsOneWidget);
    expect(find.text('Not enough evidence'), findsOneWidget);
    expect(find.textContaining('120'), findsNothing);
    expect(find.text('Depth improved'), findsNothing);
    expect(find.textContaining('server-accepted'), findsOneWidget);
  });
}
