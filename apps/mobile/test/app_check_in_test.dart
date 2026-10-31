import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/gamification/domain/app_check_in.dart';
import 'package:gainpath_mobile/features/gamification/application/app_check_in_cubit.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/app_check_in_dashboard.dart';

Map<String, dynamic> snapshotJson(SessionScope scope, {bool claimed = false}) {
  final now = DateTime.utc(2026, 10, 26, 4).millisecondsSinceEpoch,
      today = DateTime.utc(2026, 10, 26);
  return {
    'schemaVersion': 1,
    'organizationId': scope.organizationId,
    'memberId': scope.userId,
    'policyVersion': 'app-check-in-v1',
    'timezone': 'Asia/Kuala_Lumpur',
    'pointsPerClaim': 50,
    'balance': claimed ? 50 : 0,
    'today': '2026-10-26',
    'claimedToday': claimed,
    'currentStreak': claimed ? 1 : 0,
    'longestStreak': claimed ? 1 : 0,
    'totalClaims': claimed ? 1 : 0,
    'serverNowMillis': now,
    'nextResetMillis': DateTime.utc(2026, 10, 26, 16).millisecondsSinceEpoch,
    'days': [
      for (var i = 0; i < 7; i++)
        {
          'date': today
              .subtract(Duration(days: 6 - i))
              .toIso8601String()
              .substring(0, 10),
          'claimed': i == 6 && claimed
        }
    ],
    'recentClaims': claimed
        ? [
            {
              'schemaVersion': 1,
              'organizationId': scope.organizationId,
              'memberId': scope.userId,
              'date': '2026-10-26',
              'points': 50,
              'claimedAtMillis': now,
              'policyVersion': 'app-check-in-v1',
              'source': 'app_check_in'
            }
          ]
        : [],
    'badges': [
      for (var i = 0; i < 3; i++)
        {
          'id': ['first-check-in', 'check-in-streak-3', 'check-in-streak-7'][i],
          'title': [
            'First check-in',
            'Three-day streak',
            'Seven-day streak'
          ][i],
          'requiredStreak': [1, 3, 7][i],
          'unlockedAtMillis': i == 0 && claimed ? now : null
        }
    ]
  };
}

class FakeCheckIn implements AppCheckInRepository {
  FakeCheckIn(this.scope);
  @override
  final SessionScope scope;
  bool claimed = false, offline = false;
  int claims = 0;
  Completer<void>? pending, overviewDelay;
  @override
  Future<AppCheckInResult> overview() async {
    if (overviewDelay != null) await overviewDelay!.future;
    if (offline) throw StateError('offline');
    return AppCheckInResult(
        AppCheckInSnapshot.fromJson(
            snapshotJson(scope, claimed: claimed), scope),
        awarded: false);
  }

  @override
  Future<AppCheckInResult> claim() async {
    claims++;
    if (pending != null) await pending!.future;
    if (offline) throw StateError('offline');
    final awarded = !claimed;
    claimed = true;
    return AppCheckInResult(
        AppCheckInSnapshot.fromJson(snapshotJson(scope, claimed: true), scope),
        awarded: awarded);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  test(
      'duplicate taps share one request and points change only after server response',
      () async {
    final repo = FakeCheckIn(scope)..pending = Completer<void>();
    final c = AppCheckInCubit(repository: repo, activeScope: () => scope);
    await c.refresh();
    final first = c.claim();
    await c.claim();
    expect(repo.claims, 1);
    expect(c.state.snapshot!.balance, 0);
    repo.pending!.complete();
    await first;
    expect(c.state.snapshot!.balance, 50);
    expect(c.state.snapshot!.claimedToday, true);
    await c.close();
  });
  test('failed claim keeps old points and retry reconciles server response',
      () async {
    final repo = FakeCheckIn(scope);
    final c = AppCheckInCubit(repository: repo, activeScope: () => scope);
    await c.refresh();
    repo.offline = true;
    await c.claim();
    expect(c.state.status, AppCheckInStatus.error);
    expect(c.state.snapshot!.balance, 0);
    repo.offline = false;
    await c.claim();
    expect(c.state.snapshot!.balance, 50);
    await c.close();
  });
  test('account switch discards in-flight claim and captured points', () async {
    SessionScope? active = scope;
    final repo = FakeCheckIn(scope)..pending = Completer<void>();
    final c = AppCheckInCubit(repository: repo, activeScope: () => active);
    await c.refresh();
    final claim = c.claim();
    active = null;
    c.invalidate();
    repo.pending!.complete();
    await claim;
    expect(c.state.status, AppCheckInStatus.inactive);
    expect(c.state.snapshot, isNull);
    await c.close();
  });
  testWidgets(
      'live rewards claims then opens real badges on a secondary small-screen route',
      (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeCheckIn(scope),
        c = AppCheckInCubit(
            repository: FakeCheckIn(scope), activeScope: () => scope);
    await c.refresh();
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!),
        home: StreamBuilder<AppCheckInState>(
            stream: c.stream,
            initialData: c.state,
            builder: (_, value) => AppCheckInDashboard(
                state: value.data!, onClaim: c.claim, onRefresh: c.refresh))));
    await tester.scrollUntilVisible(find.text('Claim 50 points'), 180);
    await tester.tap(find.text('Claim 50 points'));
    await tester.pumpAndSettle();
    expect(find.text('Claimed today'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Badges'), 180);
    await tester.tap(find.text('Badges'));
    await tester.pumpAndSettle();
    expect(find.text('First check-in'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(repo.claims, 0);
    await tester.pumpWidget(const SizedBox());
    await c.close();
  });
  test('older refresh cannot release the lock for a newer pending claim',
      () async {
    final repo = FakeCheckIn(scope);
    final actual = AppCheckInCubit(repository: repo, activeScope: () => scope);
    await actual.refresh();
    repo.overviewDelay = Completer<void>();
    repo.pending = Completer<void>();
    final older = actual.refresh(), first = actual.claim();
    repo.overviewDelay!.complete();
    await older;
    final second = actual.claim();
    final count = repo.claims;
    repo.pending!.complete();
    await first;
    await second;
    expect(count, 1);
    await actual.close();
  });
}
