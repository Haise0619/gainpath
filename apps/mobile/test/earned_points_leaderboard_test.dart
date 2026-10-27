import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/infrastructure/firebase/firebase_verified_rewards_repository.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_app_check_readiness.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/leaderboard_screen.dart';

Map<String, dynamic> response([String period = 'week']) => {
      'schemaVersion': 1,
      'organizationId': 'gainpath',
      'memberId': 'member',
      'period': period,
      'timezone': 'Asia/Kuala_Lumpur',
      'resolvedAtMillis':
          DateTime.parse('2026-10-27T08:00:00Z').millisecondsSinceEpoch,
      'periodStartMillis': period == 'week'
          ? DateTime.parse('2026-10-25T16:00:00Z').millisecondsSinceEpoch
          : null,
      'periodEndMillis': period == 'week'
          ? DateTime.parse('2026-11-01T16:00:00Z').millisecondsSinceEpoch
          : null,
      'totalParticipants': 2,
      'entries': [
        {'rank': 1, 'displayName': 'Sam', 'points': 100, 'isYou': false},
        {'rank': 2, 'displayName': 'Zheng', 'points': 50, 'isYou': true}
      ],
      'you': {'rank': 2, 'displayName': 'Zheng', 'points': 50, 'isYou': true}
    };

class RankRepo extends VerifiedRewardsRepository {
  @override
  bool get connected => false;
  @override
  bool current = true;
  bool fail = false;
  final requests = <String>[];
  Completer<EarnedPointsLeaderboard>? pending;
  final byPeriod = <String, Completer<EarnedPointsLeaderboard>>{};
  bool empty = false;
  bool podium = false;
  @override
  Future<EarnedPointsLeaderboard> leaderboard({String period = 'week'}) async {
    requests.add(period);
    if (fail) throw StateError('offline');
    if (byPeriod.containsKey(period)) return byPeriod[period]!.future;
    if (pending != null) return pending!.future;
    final data = response(period);
    if (podium) {
      data['totalParticipants'] = 5;
      data['entries'] = [
        {
          'rank': 1,
          'displayName': 'Farid Zainal',
          'points': 3120,
          'isYou': false
        },
        {
          'rank': 2,
          'displayName': 'Wei Ling Tan',
          'points': 2780,
          'isYou': false
        },
        {
          'rank': 3,
          'displayName': 'Daniel Wong',
          'points': 2410,
          'isYou': false
        },
        {'rank': 4, 'displayName': 'ZhengYang', 'points': 1840, 'isYou': true},
        {'rank': 5, 'displayName': 'Nurul Huda', 'points': 1655, 'isYou': false}
      ];
      data['you'] = (data['entries'] as List)[3];
    }
    if (empty) {
      data['entries'] = [];
      data['totalParticipants'] = 0;
      data['you'] = {
        'rank': null,
        'displayName': 'You',
        'points': 0,
        'isYou': true
      };
    }
    return EarnedPointsLeaderboard.fromJson(data,
        organizationId: 'gainpath', memberId: 'member', period: period);
  }

  @override
  Future<VerifiedRewardsSnapshot> overview() => throw UnimplementedError();
  @override
  Future<void> award(String id) => throw UnimplementedError();
  @override
  Future<VerifiedRewardRedemption> redeem(
          {required String itemId,
          required String requestId,
          int? expectedPointCost,
          int? expectedItemRevision}) =>
      throw UnimplementedError();
}

class LeaderboardReady extends FirebaseAppCheckReadiness {
  @override
  Future<bool> ensureReady({void Function()? check}) async {
    check?.call();
    return true;
  }
}

void main() {
  testWidgets(
      'reference layout uses real podium, rank gap and highlighted own row',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: LeaderboardScreen(repository: RankRepo()..podium = true)));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('leaderboard-podium')), findsOneWidget);
    expect(find.text('You are rank #4 — just 570 points from #3.'),
        findsOneWidget);
    expect(find.text('3,120'), findsOneWidget);
    expect(find.text('1,840'), findsOneWidget);
    expect(t.getCenter(find.text('Wei Ling Tan')).dx,
        lessThan(t.getCenter(find.text('Farid Zainal')).dx));
    expect(find.byKey(const Key('leaderboard-own-row')), findsOneWidget);
    expect(find.bySemanticsLabel('ZhengYang, You, rank 4, 1,840 points'),
        findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
  });
  test('Firebase leaderboard sends only the current scope and selected period',
      () async {
    final repo = FirebaseVerifiedRewardsRepository(
        scope: SessionScope(userId: 'member', organizationId: 'gainpath'),
        isCurrent: () => true,
        currentUid: () => 'member',
        readiness: LeaderboardReady(),
        call: (name, input) async {
          expect(name, 'verifiedRewardsCommand');
          expect(input, {
            'schemaVersion': 1,
            'organizationId': 'gainpath',
            'action': 'leaderboard',
            'period': 'all_time'
          });
          return response('all_time');
        });
    expect((await repo.leaderboard(period: 'all_time')).you.points, 50);
  });
  test('Firebase leaderboard hides replies after the captured session changes',
      () async {
    var current = true;
    final repo = FirebaseVerifiedRewardsRepository(
        scope: SessionScope(userId: 'member', organizationId: 'gainpath'),
        isCurrent: () => current,
        currentUid: () => 'member',
        readiness: LeaderboardReady(),
        call: (name, input) async {
          current = false;
          return response();
        });
    await expectLater(repo.leaderboard(), throwsA(isA<Exception>()));
  });
  testWidgets('empty earnings stay unranked without sample standings',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: LeaderboardScreen(repository: RankRepo()..empty = true)));
    await t.pumpAndSettle();
    expect(find.text('No rankings yet. Be the first to earn points.'),
        findsOneWidget);
    expect(find.text('#1'), findsNothing);
  });
  testWidgets(
      'a late weekly response cannot replace selected all-time rankings',
      (t) async {
    final repo = RankRepo(), pending = Completer<EarnedPointsLeaderboard>();
    repo.byPeriod['week'] = pending;
    await t.pumpWidget(MaterialApp(home: LeaderboardScreen(repository: repo)));
    await t.pump();
    await t.tap(find.text('All time'));
    await t.pumpAndSettle();
    final old = response();
    (old['entries'] as List).first['displayName'] = 'Week only';
    pending.complete(EarnedPointsLeaderboard.fromJson(old,
        organizationId: 'gainpath', memberId: 'member', period: 'week'));
    await t.pump();
    expect(find.text('Week only'), findsNothing);
    expect(find.text('Sam'), findsOneWidget);
  });
  testWidgets('weekly rankings show live earned points and switch to all time',
      (t) async {
    final repo = RankRepo();
    await t.pumpWidget(MaterialApp(home: LeaderboardScreen(repository: repo)));
    await t.pumpAndSettle();
    expect(find.text('Sam'), findsOneWidget);
    expect(
        find.text('You are rank #2 — just 50 points from #1.'), findsOneWidget);
    expect(
        find.bySemanticsLabel('Zheng, You, rank 2, 50 points'), findsOneWidget);
    await t.tap(find.text('All time'));
    await t.pumpAndSettle();
    expect(repo.requests, ['week', 'all_time']);
  });
  testWidgets('error retries and a changed session hides private ranks',
      (t) async {
    final repo = RankRepo()..fail = true;
    await t.pumpWidget(MaterialApp(home: LeaderboardScreen(repository: repo)));
    await t.pumpAndSettle();
    await t.tap(find.text('Retry'));
    repo.fail = false;
    await t.pumpAndSettle();
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    expect(find.text('Sam'), findsOneWidget);
    repo.current = false;
    await t.pumpWidget(MaterialApp(home: LeaderboardScreen(repository: repo)));
    await t.pump();
    expect(find.text('Sam'), findsNothing);
  });
  testWidgets('leaderboard fits320px with double text', (t) async {
    t.view.physicalSize = const Size(320, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: child!),
        home: LeaderboardScreen(repository: RankRepo()..podium = true)));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  test('contract rejects foreign ownership and wrong ranks or Malaysia window',
      () {
    final data = response();
    expect(
        EarnedPointsLeaderboard.fromJson(data,
                organizationId: 'gainpath', memberId: 'member', period: 'week')
            .you
            .points,
        50);
    for (final fields in [
      {'memberId': 'other'},
      {'periodStartMillis': 0},
      {'totalParticipants': 1}
    ]) {
      expect(
          () => EarnedPointsLeaderboard.fromJson({...data, ...fields},
              organizationId: 'gainpath', memberId: 'member', period: 'week'),
          throwsFormatException);
    }
  });
}
