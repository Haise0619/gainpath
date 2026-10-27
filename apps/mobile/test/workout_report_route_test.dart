import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/app/routing/member_workout_report_route.dart';
import 'package:gainpath_mobile/features/analytics/domain/local_member_progress_repository.dart';
import 'member_progress_route_test.dart' show TestRepository;
import 'workout_report_ui_test.dart' show ReportExporterFake;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<AuthBloc> signIn(WidgetTester tester) async {
    late AuthBloc auth;
    await tester.runAsync(() async {
      auth = AuthBloc(repository: InMemoryAuthRepository());
      await Future<void>.delayed(Duration.zero);
      auth.add(const LoginSubmitted(
          email: 'member@example.com', password: 'password123'));
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedIn);
    });
    return auth;
  }

  testWidgets('report opens from an explicitly injected scoped repository',
      (tester) async {
    final auth = await signIn(tester),
        repo = TestRepository(auth.state.session!.scope),
        exporter = ReportExporterFake();
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: MemberWorkoutReportRoute(
                scope: repo.scope,
                repositoryFactory: (scope, active) async => repo,
                exporter: exporter))));
    await tester.pumpAndSettle();
    expect(find.text('Workout report'), findsOneWidget);
    expect(repo.reads, 1);
    expect(find.text('No activity matches these filters.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(auth.close);
  });
  testWidgets(
      'logout during delayed history read clears route and cancels export',
      (tester) async {
    final auth = await signIn(tester),
        repo = TestRepository(auth.state.session!.scope),
        exporter = ReportExporterFake();
    final read = Completer<LocalMemberProgressSnapshot>();
    repo.read = () => read.future;
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: MemberWorkoutReportRoute(
                scope: repo.scope,
                repositoryFactory: (scope, active) async => repo,
                exporter: exporter))));
    await tester.pump();
    await tester.pump();
    await tester.runAsync(() async {
      auth.add(const LoggedOut());
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedOut);
    });
    read.complete(LocalMemberProgressSnapshot(records: []));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to view this account’s report.'), findsOneWidget);
    expect(find.text('No activity matches these filters.'), findsNothing);
    expect(exporter.cancelled, greaterThanOrEqualTo(1));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(auth.close);
  });
  testWidgets('repository initialization failure offers a working retry',
      (tester) async {
    final auth = await signIn(tester),
        repo = TestRepository(auth.state.session!.scope);
    var tries = 0;
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: MemberWorkoutReportRoute(
                scope: repo.scope,
                repositoryFactory: (scope, active) async {
                  if (tries++ == 0) throw StateError('storage');
                  return repo;
                },
                exporter: ReportExporterFake()))));
    await tester.pumpAndSettle();
    expect(find.text('Could not open saved workout history.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repo.reads, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(auth.close);
  });
}
