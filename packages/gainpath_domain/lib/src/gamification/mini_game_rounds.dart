import '../identity.dart' show SessionScope;

/// A server timing receipt. It deliberately cannot represent trusted physical
/// play or a points award; that requires a separate evidence producer/release.
class MiniGameRound {
  const MiniGameRound._(
      {required this.scope,
      required this.gameId,
      required this.attemptId,
      required this.challengeToken,
      required this.status,
      required this.sequence,
      required this.activeMillis,
      required this.startedAtMillis,
      required this.leaseUntilMillis,
      required this.expiresAtMillis});
  final SessionScope scope;
  final String gameId;
  final String attemptId, challengeToken, status;
  final int sequence,
      activeMillis,
      startedAtMillis,
      leaseUntilMillis,
      expiresAtMillis;
  factory MiniGameRound.fromJson(Map<String, dynamic> d, SessionScope scope,
      {String gameId = 'move-catch-v1'}) {
    bool integer(String key, int min, int max) =>
        d[key] is int && d[key] >= min && d[key] <= max;
    bool hex(String key) =>
        d[key] is String && RegExp(r'^[a-f0-9]{32}$').hasMatch(d[key]);
    if (d.length != 14 ||
        d['schemaVersion'] != 1 ||
        d['organizationId'] != scope.organizationId ||
        d['memberId'] != scope.userId ||
        !{'move-catch-v1', 'reach-tap-v1'}.contains(gameId) ||
        d['gameId'] != gameId ||
        !hex('attemptId') ||
        !hex('challengeToken') ||
        d['attemptId'] == d['challengeToken'] ||
        !['open', 'awaiting_verification', 'abandoned'].contains(d['status']) ||
        !integer('sequence', 0, 361) ||
        !integer('activeMillis', 0, 40000) ||
        !integer('startedAtMillis', 1, 8640000000000000 - 900000) ||
        !integer('leaseUntilMillis', 1, 8640000000000000) ||
        !integer('expiresAtMillis', 1, 8640000000000000) ||
        d['expiresAtMillis'] != d['startedAtMillis'] + 900000 ||
        d['leaseUntilMillis'] < d['startedAtMillis'] ||
        d['leaseUntilMillis'] > d['expiresAtMillis'] ||
        d['physicalVerified'] != false ||
        d['pointsAwarded'] != 0 ||
        (d['status'] == 'awaiting_verification' &&
            (d['activeMillis'] != 40000 || d['sequence'] < 9))) {
      throw const FormatException('Invalid or unowned round timing response.');
    }
    return MiniGameRound._(
        scope: scope,
        gameId: gameId,
        attemptId: d['attemptId'],
        challengeToken: d['challengeToken'],
        status: d['status'],
        sequence: d['sequence'],
        activeMillis: d['activeMillis'],
        startedAtMillis: d['startedAtMillis'],
        leaseUntilMillis: d['leaseUntilMillis'],
        expiresAtMillis: d['expiresAtMillis']);
  }
}

abstract interface class MiniGameRoundRepository {
  SessionScope get scope;
  bool get current;
  Future<MiniGameRound> begin({required String requestId});
  Future<MiniGameRound> checkpoint(
      {required MiniGameRound round,
      required int sequence,
      required int activeMillis,
      required bool playing});
  Future<MiniGameRound> finish(
      {required MiniGameRound round, required int sequence});
  Future<MiniGameRound> abandon({required MiniGameRound round});
}

class MiniGameRoundUnavailable implements Exception {
  const MiniGameRoundUnavailable();
}

class MiniGameRoundSessionChanged implements Exception {
  const MiniGameRoundSessionChanged();
}

class MiniGameRoundBusy implements Exception {
  const MiniGameRoundBusy();
}
