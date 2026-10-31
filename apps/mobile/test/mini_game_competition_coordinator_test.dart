import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/gamification/application/mini_game_competition_coordinator.dart';
import 'package:gainpath_mobile/features/gamification/application/mini_game_round_coordinator.dart';

final scope = SessionScope(userId: 'member', organizationId: 'gym');

class CompetitionRepo implements MiniGameCompetitionRepository {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'gym');
  @override
  bool current = true;
  bool enabled = true, fail = false;
  int submissions = 0;
  List<MiniGameScoreEvent>? submitted;
  @override
  Future<MiniGameCompetitionPreference> preference() async =>
      MiniGameCompetitionPreference(
          scope: scope, enabled: enabled, revision: 1, changedAtMillis: 1);
  @override
  Future<MiniGameCompetitionPreference> setPreference(
      {required bool enabled}) async {
    this.enabled = enabled;
    return preference();
  }

  @override
  Future<MiniGameAcceptedScore> submit(
      {required String gameId,
      required String attemptId,
      required String challengeToken,
      required List<MiniGameScoreEvent> events}) async {
    submissions++;
    if (fail) throw StateError('offline');
    submitted = events;
    return MiniGameAcceptedScore(
        scope: scope,
        gameId: gameId,
        attemptId: attemptId,
        score: 10,
        acceptedAtMillis: 100);
  }

  @override
  Future<MiniGameScoreLeaderboard> leaderboard(
          {required String gameId, required String period}) async =>
      throw UnimplementedError();
}

class TimingRepo extends Fake implements MiniGameRoundRepository {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'gym');
  @override
  bool current = true;
}

class Timing extends MiniGameRoundCoordinator {
  Timing() : super(repository: TimingRepo());
  int starts = 0, finishes = 0, resets = 0;
  MiniGameRound? result;
  @override
  MiniGameRound? get completedRound => result;
  @override
  void start() {
    starts++;
  }

  @override
  void observe({required int activeMillis, required bool playing}) {}
  @override
  void finish() {
    finishes++;
  }

  @override
  void reset() {
    resets++;
    result = null;
  }

  void complete() {
    result = MiniGameRound.fromJson({
      'schemaVersion': 1,
      'organizationId': 'gym',
      'memberId': 'member',
      'gameId': 'move-catch-v1',
      'attemptId': 'a' * 32,
      'challengeToken': 'b' * 32,
      'status': 'awaiting_verification',
      'sequence': 10,
      'activeMillis': 40000,
      'startedAtMillis': 100,
      'leaseUntilMillis': 50000,
      'expiresAtMillis': 900100,
      'physicalVerified': false,
      'pointsAwarded': 0
    }, scope);
    notifyListeners();
  }
}

void main() {
  test('unknown or declined competition never starts timing or submits',
      () async {
    final repo = CompetitionRepo(), timing = Timing();
    final c = MiniGameCompetitionCoordinator(
        repository: repo, timing: timing, gameId: 'move-catch-v1');
    addTearDown(c.dispose);
    c.start();
    c.event('catch', 1000);
    c.finish();
    timing.complete();
    await Future<void>.delayed(Duration.zero);
    expect(timing.starts, 0);
    expect(repo.submissions, 0);
    repo.enabled = false;
    await c.loadPreference();
    c.reset();
    c.start();
    c.event('catch', 1000);
    c.finish();
    expect(timing.starts, 0);
  });
  test(
      'opted round submits ordered observed events once and retry keeps identity',
      () async {
    final repo = CompetitionRepo()..fail = true, timing = Timing();
    final c = MiniGameCompetitionCoordinator(
        repository: repo, timing: timing, gameId: 'move-catch-v1');
    addTearDown(c.dispose);
    await c.loadPreference();
    c.start();
    c.event('catch', 1000);
    c.event('obstacle', 2000);
    c.finish();
    timing.complete();
    await Future<void>.delayed(Duration.zero);
    expect(c.submissionFailed, true);
    expect(repo.submissions, 1);
    repo.fail = false;
    await c.retry();
    expect(c.receipt?.score, 10);
    expect(repo.submissions, 2);
    expect(repo.submitted!.map((e) => e.sequence), [1, 2]);
    expect(repo.submitted!.map((e) => e.type), ['catch', 'obstacle']);
    timing.complete();
    await Future<void>.delayed(Duration.zero);
    expect(repo.submissions, 2);
    c.reset();
    expect(c.receipt, isNull);
    expect(c.submissionFailed, false);
  });
  test(
      'out of order or unsupported events fail closed without affecting local play',
      () async {
    final repo = CompetitionRepo(), timing = Timing();
    final c = MiniGameCompetitionCoordinator(
        repository: repo, timing: timing, gameId: 'reach-tap-v1');
    addTearDown(c.dispose);
    await c.loadPreference();
    c.start();
    c.event('hit', 1000);
    c.event('catch', 2000);
    c.finish();
    timing.complete();
    await Future<void>.delayed(Duration.zero);
    expect(repo.submissions, 0);
    expect(c.submissionFailed, true);
  });
  test('account invalidation rejects late preference and submission', () async {
    final repo = CompetitionRepo(), timing = Timing();
    final c = MiniGameCompetitionCoordinator(
        repository: repo, timing: timing, gameId: 'move-catch-v1');
    addTearDown(c.dispose);
    await c.loadPreference();
    c.start();
    c.event('catch', 1000);
    c.finish();
    repo.current = false;
    timing.complete();
    await Future<void>.delayed(Duration.zero);
    expect(repo.submissions, 0);
    expect(c.current, false);
  });
  test('round for the other game is never submitted', () async {
    final repo = CompetitionRepo(), timing = Timing();
    final c = MiniGameCompetitionCoordinator(
        repository: repo, timing: timing, gameId: 'reach-tap-v1');
    addTearDown(c.dispose);
    await c.loadPreference();
    c.start();
    c.event('hit', 1000);
    c.finish();
    timing.complete();
    await Future<void>.delayed(Duration.zero);
    expect(repo.submissions, 0);
    expect(c.submissionFailed, true);
    expect(c.canRetry, false);
  });
  test('withdrawal prevents publication of a completed in-flight round',
      () async {
    final repo = CompetitionRepo(), timing = Timing();
    final c = MiniGameCompetitionCoordinator(
        repository: repo, timing: timing, gameId: 'move-catch-v1');
    addTearDown(c.dispose);
    await c.loadPreference();
    c.start();
    c.event('catch', 1000);
    c.finish();
    c.acceptPreference(MiniGameCompetitionPreference(
        scope: scope, enabled: false, revision: 2, changedAtMillis: 40001));
    timing.complete();
    await Future<void>.delayed(Duration.zero);
    expect(repo.submissions, 0);
    expect(c.roundParticipating, false);
    expect(c.receipt, isNull);
  });
}
