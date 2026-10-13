import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/app/routing/member_progress_route.dart';
import 'package:gainpath_mobile/features/analytics/domain/local_member_progress_repository.dart';

class TestRepository implements LocalMemberProgressRepository {
  TestRepository(this.scope);
  @override
  final SessionScope scope;
  int reads = 0;
  Future<LocalMemberProgressSnapshot> Function() read =
      () async => LocalMemberProgressSnapshot(records: []);
  @override
  Future<LocalMemberProgressSnapshot> load() {
    reads++;
    return read();
  }
}

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

  testWidgets(
      'local dashboard uses injected scoped repository and refreshes without mock providers',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = await signIn(tester),
        repo = TestRepository((await Future.value(auth.state.session!)).scope);
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: MemberProgressRoute(
                scope: repo.scope,
                repositoryFactory: (scope, active) async => repo))));
    await tester.pumpAndSettle();
    expect(find.text('No saved camera sessions yet.'), findsOneWidget);
    expect(find.text('84%'), findsNothing);
    expect(repo.reads, 1);
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(repo.reads, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(auth.close);
  });
  testWidgets('logout during delayed read hides results and discards late data',
      (tester) async {
    final auth = await signIn(tester),
        repo = TestRepository(auth.state.session!.scope);
    final pending = Completer<LocalMemberProgressSnapshot>();
    repo.read = () => pending.future;
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: MemberProgressRoute(
                scope: repo.scope,
                repositoryFactory: (scope, active) async => repo))));
    await tester.pump();
    await tester.pump();
    await tester.runAsync(() async {
      auth.add(const LoggedOut());
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedOut);
    });
    pending.complete(LocalMemberProgressSnapshot(records: []));
    await tester.pumpAndSettle();
    expect(find.text('No saved camera sessions yet.'), findsNothing);
    expect(
        find.text('Sign in to view this account’s progress.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(auth.close);
  });
}
