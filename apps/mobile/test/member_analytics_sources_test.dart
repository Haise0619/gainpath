import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/body_metrics_screen.dart';
import 'app_check_in_test.dart' as check;
import 'reward_journey_test.dart' as rewards;
import 'support/fitness_profile_fake.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_mobile/app/routing/member_points_progress_route.dart';

class ReceiptRepository extends rewards.JourneyRewards {
  final result = Completer<PointsHistorySnapshot>();
  @override
  Future<PointsHistorySnapshot> pointsHistory() => result.future;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'profile metrics load real scoped values and hide when session invalidates',
      (tester) async {
    final profiles = FakeProfileGateway();
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    await profiles.repository(scope).save(sampleProfile());
    var current = true;
    Widget page() => MaterialApp(
        home: ProfileBodyMetricsScreen(
            repository: profiles.repository(scope), current: () => current));
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(find.text('65.0 kg'), findsOneWidget);
    expect(find.textContaining('measurement date unknown'), findsOneWidget);
    current = false;
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(find.text('65.0 kg'), findsNothing);
  });
  testWidgets(
      'points load confirmed receipts and asynchronously loaded check-in streak',
      (tester) async {
    late AuthBloc auth;
    await tester.runAsync(() async {
      auth = AuthBloc(repository: InMemoryAuthRepository());
      await Future<void>.delayed(Duration.zero);
      auth.add(const LoginSubmitted(
          email: 'member@example.com', password: 'password123'));
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedIn);
    });
    final repo = ReceiptRepository();
    final checkIn = check.FakeCheckIn(auth.state.session!.scope);
    checkIn.claimed = true;
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: LivePointsProgress(
                repository: repo, checkInFactory: (_, __) async => checkIn))));
    await tester.pump();
    repo.result.complete(const PointsHistorySnapshot(
        balance: 123, entries: [], reconciled: false));
    await tester.pumpAndSettle();
    expect(find.text('Spendable balance: 123 points'), findsOneWidget);
    expect(find.textContaining('Check-in streak: 1 days'), findsOneWidget);
    expect(find.textContaining('history is incomplete'), findsOneWidget);
    repo.active = false;
    await tester.runAsync(() async {
      auth.add(const LoggedOut());
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedOut);
    });
    await tester.pumpAndSettle();
    expect(find.text('Spendable balance: 123 points'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(auth.close);
  });
  testWidgets('logout discards delayed points receipt result', (tester) async {
    late AuthBloc auth;
    await tester.runAsync(() async {
      auth = AuthBloc(repository: InMemoryAuthRepository());
      await Future<void>.delayed(Duration.zero);
      auth.add(const LoginSubmitted(
          email: 'member@example.com', password: 'password123'));
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedIn);
    });
    final repo = ReceiptRepository();
    final checkIn = check.FakeCheckIn(auth.state.session!.scope);
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: LivePointsProgress(
                repository: repo, checkInFactory: (_, __) async => checkIn))));
    await tester.pump();
    await tester.runAsync(() async {
      auth.add(const LoggedOut());
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedOut);
    });
    repo.result.complete(const PointsHistorySnapshot(
        balance: 999, entries: [], reconciled: false));
    await tester.pumpAndSettle();
    expect(find.text('Spendable balance: 999 points'), findsNothing);
    expect(find.text('Sign in to view points.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(auth.close);
  });
  test(
      'weekly earned receipts use Malaysia Monday and exclude spending and demo wallet',
      () {
    final now = DateTime.utc(2026, 10, 26, 0);
    PointsHistoryEntry row(String id, int points, DateTime at,
            {String wallet = 'spendable'}) =>
        PointsHistoryEntry(
            id: id,
            source: 'app_check_in',
            title: id,
            points: points,
            occurredAtMillis: at.millisecondsSinceEpoch,
            wallet: wallet);
    final totals = weeklyEarnedReceipts([
      row('sun', 10, DateTime.utc(2026, 10, 25, 15, 59)),
      row('mon', 20, DateTime.utc(2026, 10, 25, 16)),
      row('spend', -5, now),
      row('demo', 99, now, wallet: 'demo')
    ], now);
    expect(totals.last, 20);
    expect(totals[totals.length - 2], 10);
  });
}
