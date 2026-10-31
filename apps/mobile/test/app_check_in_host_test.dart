import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/app/routing/app_check_in_host.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/app_check_in_card.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/app_check_in_dashboard.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/fitness_arcade_games.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/fitness_arcade_rank.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_app_check_in_repository.dart';
import 'app_check_in_test.dart' as support;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'home card and rewards share confirmed points and logout hides both',
      (tester) async {
    late AuthBloc auth;
    await tester.runAsync(() async {
      auth = AuthBloc(repository: InMemoryAuthRepository());
      await Future<void>.delayed(Duration.zero);
      auth.add(const LoginSubmitted(
          email: 'member@example.com', password: 'password123'));
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedIn);
    });
    final scope = auth.state.session!.scope,
        repo = support.FakeCheckIn(auth.state.session!.scope);
    var rewards = false;
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: StatefulBuilder(
                builder: (context, setState) => AppCheckInHost(
                    scope: scope,
                    repositoryFactory: (_, __) async => repo,
                    builder: (state, refresh, claim) => rewards
                        ? AppCheckInDashboard(
                            state: state,
                            onClaim: claim,
                            onRefresh: refresh,
                            gamesSection: FitnessArcadeGames(onReturn: refresh),
                            weeklyRankSection: FitnessArcadeRank(onTap: () {}))
                        : Scaffold(
                            body: ListView(children: [
                            AppCheckInCard(
                                state: state,
                                onClaim: claim,
                                onRefresh: refresh),
                            TextButton(
                                onPressed: () => setState(() => rewards = true),
                                child: const Text('Open Rewards'))
                          ])))))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claim 50 points'));
    await tester.pumpAndSettle();
    expect(repo.claims, 1);
    expect(find.text('Claimed today'), findsOneWidget);
    await tester.tap(find.text('Open Rewards'));
    await tester.pumpAndSettle();
    expect(find.text('50'), findsOneWidget);
    expect(find.text('Claimed today'), findsOneWidget);
    await tester.runAsync(() async {
      auth.add(const LoggedOut());
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedOut);
    });
    await tester.pumpAndSettle();
    expect(find.text('50'), findsNothing);
    expect(find.text('Claimed today'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(auth.close);
  });
  test(
      'transport rejects forged receipt owner and uses only overview/claim inputs',
      () async {
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    var forge = false;
    final repo = FirebaseAppCheckInRepository(
        scope: scope,
        activeScope: () => scope,
        invoke: (input) async {
          expect(input.keys.toSet(),
              {'schemaVersion', 'organizationId', 'action'});
          final data = support.snapshotJson(scope);
          if (forge) data['memberId'] = 'other';
          return {'awarded': false, 'snapshot': data};
        });
    expect((await repo.overview()).snapshot.balance, 0);
    forge = true;
    await expectLater(repo.overview(), throwsFormatException);
  });
}
