import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/app/routing/member_progress_route.dart';
import 'package:gainpath_mobile/features/analytics/domain/local_member_progress_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'package:gainpath_mobile/features/workout/application/routine_journey_controller.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/routine_journey_screen.dart';
import 'member_progress_route_test.dart' as progress;
import 'routine_history_ui_test.dart' as ui;
import 'routine_journey_controller_test.dart' as support;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'completion actions open progress and create next day without replacing saved attempt',
      (tester) async {
    final a = ui.attempt(),
        store = support.MemoryJourneyStore(ui.attempt().scope);
    final workouts = WorkoutSessionRepository(
        scope: a.scope,
        store: InMemoryWorkoutSessionStore(scope: a.scope),
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => a.scope);
    var id = 0, opened = false;
    final c = RoutineJourneyController(
        scope: a.scope,
        activeScope: () => a.scope,
        routine: a.routine,
        store: store,
        workouts: workouts,
        newId: () => 'action-${id++}');
    await c.openDay(1);
    final capture = await c.prepareCapture(0);
    await workouts.saveLocal(support.measured(a.scope, capture));
    await c.refresh();
    await c.markManualSet(1);
    await c.markManualSet(1);
    await c.finish();
    final first = c.checkpoint!.id;
    await tester.pumpWidget(MaterialApp(
        home: RoutineJourneyScreen(
            controller: c,
            onTrack: (_) async {},
            onTutorial: (_) async {},
            onViewProgress: () => opened = true)));
    expect(find.text('Routine completion'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('Workout rewards · Not active'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Workout rewards · Not active'), findsOneWidget);
    expect(find.textContaining('physical validation'), findsOneWidget);
    expect(find.text('Claim reward'), findsNothing);
    await tester.scrollUntilVisible(find.text('View progress'), 250);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View progress'));
    expect(opened, true);
    await tester.ensureVisible(find.text('Next routine day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next routine day'));
    await tester.pumpAndSettle();
    expect(c.day, 2);
    expect(c.checkpoint!.id, isNot(first));
    expect(store.records[first]!.attempt!.isComplete, true);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('saved routine detail is hidden after logout', (tester) async {
    late AuthBloc auth;
    await tester.runAsync(() async {
      auth = AuthBloc(repository: InMemoryAuthRepository());
      await Future<void>.delayed(Duration.zero);
      auth.add(const LoginSubmitted(
          email: 'member@example.com', password: 'password123'));
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedIn);
    });
    final scope = auth.state.session!.scope,
        repo = progress.TestRepository(auth.state.session!.scope);
    final a = RoutineAttempt.fromJson({
      ...ui.attempt().toJson(),
      'userId': scope.userId,
      'organizationId': scope.organizationId
    });
    repo.read = () async => LocalMemberProgressSnapshot(
        records: [], attempts: [a], routineHistoryAvailable: true);
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: MemberProgressRoute(
                scope: scope,
                view: MemberProgressView.routines,
                repositoryFactory: (_, __) async => repo))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strength days · Day 1'));
    await tester.pumpAndSettle();
    expect(find.text('Routine result'), findsOneWidget);
    await tester.runAsync(() async {
      auth.add(const LoggedOut());
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedOut);
    });
    await tester.pumpAndSettle();
    expect(find.text('Strength days · Day 1'), findsNothing);
    expect(
        find.text('Sign in to view this account’s routine.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(auth.close);
  });
}
