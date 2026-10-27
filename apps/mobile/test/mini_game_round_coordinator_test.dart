import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/gamification/application/mini_game_round_coordinator.dart';

class Repo implements MiniGameRoundRepository {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  @override
  bool current = true;
  final calls = <String>[];
  bool failCheckpoint = false, failFinish = false;
  Completer<MiniGameRound>? beginWait;
  MiniGameRound round(
          {int sequence = 0, int active = 0, String status = 'open'}) =>
      MiniGameRound.fromJson({
        'schemaVersion': 1,
        'organizationId': 'gainpath',
        'memberId': 'member',
        'gameId': 'move-catch-v1',
        'attemptId': 'a' * 32,
        'challengeToken': 'b' * 32,
        'status': status,
        'sequence': sequence,
        'activeMillis': active,
        'startedAtMillis': 1000000,
        'leaseUntilMillis': 1090000,
        'expiresAtMillis': 1900000,
        'physicalVerified': false,
        'pointsAwarded': 0
      }, scope);
  @override
  Future<MiniGameRound> begin({required String requestId}) async {
    calls.add('begin:$requestId');
    return beginWait == null ? round() : await beginWait!.future;
  }

  @override
  Future<MiniGameRound> checkpoint(
      {required MiniGameRound round,
      required int sequence,
      required int activeMillis,
      required bool playing}) async {
    calls.add('checkpoint:$sequence:$activeMillis:$playing');
    if (failCheckpoint) throw const MiniGameRoundUnavailable();
    return this.round(sequence: sequence, active: activeMillis);
  }

  @override
  Future<MiniGameRound> finish(
      {required MiniGameRound round, required int sequence}) async {
    calls.add('finish:$sequence');
    if (failFinish) throw const MiniGameRoundUnavailable();
    return this.round(
        sequence: sequence, active: 40000, status: 'awaiting_verification');
  }

  @override
  Future<MiniGameRound> abandon({required MiniGameRound round}) async {
    calls.add('abandon');
    return this.round(
        sequence: round.sequence,
        active: round.activeMillis,
        status: 'abandoned');
  }
}

Future<void> settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late Repo repo;
  late MiniGameRoundCoordinator c;
  var now = 0;
  setUp(() {
    repo = Repo();
    now = 0;
    c = MiniGameRoundCoordinator(
        repository: repo, clockMillis: () => now, requestId: () => 'c' * 32);
  });
  tearDown(() => c.dispose());
  test(
      'no reporting before explicit start, then throttle outside pose callbacks',
      () async {
    c.observe(activeMillis: 1000, playing: true);
    await settle();
    expect(repo.calls, isEmpty);
    c.start();
    await settle();
    for (var i = 0; i < 20; i++) {
      now = i * 50;
      c.observe(activeMillis: now, playing: true);
    }
    await settle();
    expect(repo.calls.length, 1);
    now = 2000;
    c.observe(activeMillis: 2000, playing: true);
    await settle();
    expect(repo.calls.last, 'checkpoint:1:2000:true');
  });
  test('uncertain checkpoint retry preserves exact sequence and progress',
      () async {
    c.start();
    await settle();
    repo.failCheckpoint = true;
    now = 2000;
    c.observe(activeMillis: 2000, playing: true);
    await settle();
    now = 4000;
    c.observe(activeMillis: 4000, playing: true);
    await settle();
    expect(repo.calls.length, 2);
    repo.failCheckpoint = false;
    c.retry();
    await settle();
    expect(repo.calls[1], repo.calls[2]);
  });
  test(
      'complete timing is pending physical verification with no invented award',
      () async {
    c.start();
    await settle();
    for (var seq = 1; seq <= 20; seq++) {
      now = seq * 2000;
      c.observe(activeMillis: now, playing: true);
      await settle();
    }
    c.finish();
    await settle();
    expect(c.state, MiniGameRoundSyncState.awaitingVerification);
    expect(repo.calls.last, 'finish:21');
  });
  test('failed finish can retry without creating another attempt', () async {
    c.start();
    await settle();
    for (var seq = 1; seq <= 20; seq++) {
      now = seq * 2000;
      c.observe(activeMillis: now, playing: true);
      await settle();
    }
    repo.failFinish = true;
    c.finish();
    await settle();
    expect(c.canRetry, true);
    repo.failFinish = false;
    c.retry();
    await settle();
    expect(repo.calls.where((v) => v.startsWith('begin')).length, 1);
    expect(repo.calls.where((v) => v == 'finish:21').length, 2);
  });
  test('long missing checkpoint is unavailable instead of backfilled timing',
      () async {
    c.start();
    await settle();
    now = 8000;
    c.observe(activeMillis: 8000, playing: true);
    await settle();
    expect(c.state, MiniGameRoundSyncState.unavailable);
    expect(repo.calls.length, 1);
    expect(c.canRetry, false);
  });
  test(
      'stale begin reply cannot revive disposed reporting and abandons owned lease',
      () async {
    repo.beginWait = Completer();
    c.start();
    c.reset();
    repo.beginWait!.complete(repo.round());
    await settle();
    expect(c.state, MiniGameRoundSyncState.idle);
    expect(repo.calls.last, 'abandon');
  });
  test('account invalidation never sends timing or abandonment as another user',
      () async {
    c.start();
    await settle();
    repo.current = false;
    now = 2000;
    c.observe(activeMillis: 2000, playing: true);
    c.reset();
    await settle();
    expect(repo.calls.length, 1);
  });
  test('late response after timeout and reset releases only its owned lease',
      () async {
    c.dispose();
    c = MiniGameRoundCoordinator(
        repository: repo,
        requestId: () => 'c' * 32,
        requestTimeout: const Duration(milliseconds: 5));
    repo.beginWait = Completer();
    c.start();
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(c.state, MiniGameRoundSyncState.unavailable);
    c.reset();
    repo.beginWait!.complete(repo.round());
    await settle();
    expect(c.state, MiniGameRoundSyncState.idle);
    expect(repo.calls.where((v) => v == 'abandon').length, 1);
  });
}
