import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_admin_web/features/content/presentation/admin/mini_game_standings_screen.dart';

class Repo implements MiniGameCompetitionRepository {
  @override
  final scope = SessionScope(userId: 'admin', organizationId: 'gainpath');
  @override
  bool current = true;
  bool fail = false;
  final calls = <String>[];
  @override
  Future<MiniGameScoreLeaderboard> leaderboard(
      {required String gameId, required String period}) async {
    calls.add('$gameId/$period');
    if (fail) throw StateError('offline');
    return MiniGameScoreLeaderboard(
        scope: scope,
        gameId: gameId,
        period: period,
        periodKey: 'week',
        entries: const [
          MiniGameScoreRank(
              rank: 1, displayName: 'Member', score: 100, isYou: false)
        ],
        you: const MiniGameScoreRank(
            rank: null, displayName: 'You', score: null, isYou: true),
        totalParticipants: 1,
        resolvedAtMillis: 1000);
  }

  @override
  Future<MiniGameCompetitionPreference> preference() =>
      throw StateError('read only');
  @override
  Future<MiniGameCompetitionPreference> setPreference(
          {required bool enabled}) =>
      throw StateError('read only');
  @override
  Future<MiniGameAcceptedScore> submit(
          {required String gameId,
          required String attemptId,
          required String challengeToken,
          required List<MiniGameScoreEvent> events}) =>
      throw StateError('read only');
}

void main() {
  testWidgets(
      'Admin game standings show accepted best with independent game and period controls',
      (tester) async {
    final repo = Repo();
    await tester.pumpWidget(
        MaterialApp(home: MiniGameStandingsScreen(repository: repo)));
    await tester.pumpAndSettle();
    expect(repo.calls, ['move-catch-v1/week']);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text(miniGameCompetitionTrustLabel), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Move & Catch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reach & Tap').last);
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'reach-tap-v1/week');
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All-time').last);
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'reach-tap-v1/all-time');
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed standings stay unavailable until successful refresh',
      (tester) async {
    final repo = Repo()..fail = true;
    await tester.pumpWidget(
        MaterialApp(home: MiniGameStandingsScreen(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Could not load game standings. Refresh to retry.'),
        findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('100'), findsOneWidget);
  });
}
