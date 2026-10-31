import 'package:gainpath_mobile/features/analytics/presentation/member/goal_comparison_report.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show NumericFitnessGoal, NumericFitnessGoalRepository;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/main.dart';
import 'package:gainpath_mobile/app/home/member_home_screen.dart';
import 'package:gainpath_mobile/features/analytics/data/local_member_progress_repository.dart';
import 'package:gainpath_mobile/features/analytics/presentation/shared/progress_dashboard_screen.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/activity_timeline_screen.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/real_workout_sync.dart';
import 'support/fitness_profile_fake.dart';

class EmptyTargets implements NumericFitnessGoalRepository {
  EmptyTargets(this.scope);
  @override
  final SessionScope scope;
  @override
  Future<List<NumericFitnessGoal>> loadActive() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WorkoutSessionRecord record(SessionScope scope, String id) {
  final start = DateTime.now().toUtc().subtract(const Duration(seconds: 30));
  return WorkoutSessionRecord(
      status: WorkoutSyncStatus.pending,
      summary: WorkoutSessionSummary(
          sessionId: id,
          userId: scope.userId,
          organizationId: scope.organizationId,
          exerciseId: 'squat',
          repetitions: 4,
          accuracy: 99,
          startedAt: start,
          endedAt: start.add(const Duration(seconds: 10)),
          provenance: WorkoutProvenance.realCamera,
          poseMetrics: WorkoutPoseMetrics(
              partialRepetitions: 1,
              trackedDurationMicros: 6000000,
              rejectedDurationMicros: 2000000,
              formScorePercent: null,
              scoringVersion: 'bodyweight-squat-side-v1',
              detectorId: 'blazepose-tflite',
              detectorVersion: 'v1',
              cameraView: 'side',
              consentVersion: 'pose-local-summary-v1',
              consentedAt: start)));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'Firebase Home and Profile share measured local history; refresh and account switch remain truthful',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = InMemoryAuthRepository(), profiles = FakeProfileGateway();
    final first =
        await auth.signIn(email: 'one@example.com', password: 'password123');
    await profiles.repository(first.scope).save(sampleProfile());
    final stores = <SessionScope, InMemoryWorkoutSessionStore>{};
    InMemoryWorkoutSessionStore store(SessionScope scope) => stores.putIfAbsent(
        scope, () => InMemoryWorkoutSessionStore(scope: scope));
    await store(first.scope).write([record(first.scope, 'first-camera')]);
    await tester.pumpWidget(GainPathMobileApp.injected(
        authRepository: auth,
        progressGoalSummaryBuilder: (scope, progress, routines, onView) =>
            Builder(
                builder: (context) => GoalComparisonReport(
                    repository: EmptyTargets(scope),
                    progress: progress,
                    routineProgress: routines,
                    isCurrent: () =>
                        context.read<AuthBloc>().state.session?.scope == scope,
                    compact: true,
                    onView: onView)),
        memberRewardsBuilder: (_) => const SizedBox(),
        profileRepositoryFactory: profiles.repository,
        routineLoaderFactory: (_) async => null,
        progressRepositoryFactory: (scope, active) async =>
            StoredLocalMemberProgressRepository(
                scope: scope,
                activeScope: active,
                workoutStore: store(scope),
                syncStore: MemoryRealWorkoutSyncStore(scope: scope))));
    await tester.pumpAndSettle();
    final home = tester.widget<MemberHomeScreen>(find.byType(MemberHomeScreen));
    expect(home.localProgress!.weeklySessions, 1);
    expect(home.localProgress!.weeklyRepetitions, 4);
    await tester.ensureVisible(find.text('Progress'));
    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgressDashboardScreen), findsOneWidget);
    expect(
        tester
            .widget<ProgressDashboardScreen>(
                find.byType(ProgressDashboardScreen))
            .localProgress!
            .weeklySessions,
        1);
    expect(find.text('Training days'), findsOneWidget);
    // Open the account-owned history page, then add a durable result and refresh
    // it while still open. No mock repositories or upload worker are installed.
    tester
        .widget<ProgressDashboardScreen>(find.byType(ProgressDashboardScreen))
        .onOpenHistory!();
    await tester.pumpAndSettle();
    expect(find.byType(ActivityTimelineScreen), findsOneWidget);
    await store(first.scope).write([
      record(first.scope, 'first-camera'),
      record(first.scope, 'second-camera')
    ]);
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ActivityTimelineScreen>(find.byType(ActivityTimelineScreen))
            .localProgress!
            .allTimeSessions,
        2);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<MemberHomeScreen>(find.byType(MemberHomeScreen))
            .localProgress!
            .allTimeSessions,
        2);
    // A workout can be saved through the Workout tab without revisiting Home.
    await store(first.scope).write([
      record(first.scope, 'first-camera'),
      record(first.scope, 'second-camera'),
      record(first.scope, 'third-camera')
    ]);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Progress and reports'));
    await tester.tap(find.text('Progress and reports'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgressDashboardScreen), findsOneWidget);
    expect(
        tester
            .widget<ProgressDashboardScreen>(
                find.byType(ProgressDashboardScreen))
            .localProgress!
            .weeklySessions,
        3);
    expect(find.text('Training days'), findsOneWidget);
    await auth.signOut();
    await tester.pumpAndSettle();
    final second =
        await auth.signIn(email: 'two@example.com', password: 'password123');
    await profiles.repository(second.scope).save(sampleProfile());
    await tester.pumpAndSettle();
    expect(find.byType(ProgressDashboardScreen), findsNothing);
    final nextHome =
        tester.widget<MemberHomeScreen>(find.byType(MemberHomeScreen));
    expect(nextHome.localProgress!.allTimeSessions, 0);
    expect(find.text('first-camera'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await auth.dispose();
  });
}
