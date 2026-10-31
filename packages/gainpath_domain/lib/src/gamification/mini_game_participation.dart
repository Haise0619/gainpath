import '../identity.dart' show SessionScope;
import 'mini_game_rewards.dart';

class MiniGameParticipation {
  const MiniGameParticipation._(
      {required this.scope,
      required this.gameId,
      required this.policy,
      required this.today,
      required this.active,
      required this.balance,
      required this.earnedToday,
      required this.remainingToday,
      required this.claimsToday,
      required this.status,
      this.attemptId,
      this.award});
  final SessionScope scope;
  final MiniGameRewardPolicy policy;
  final String today, status, gameId;
  final bool active;
  final int balance, earnedToday, remainingToday, claimsToday;
  final String? attemptId;
  final MiniGameParticipationAward? award;
  factory MiniGameParticipation.fromJson(
      Map<String, dynamic> d, SessionScope scope) {
    bool n(dynamic v) => v is int && v >= 0 && v <= 9007199254740991;
    final negotiated = d['schemaVersion'] == 3;
    final gameId = negotiated ? d['gameId'] : 'move-catch-v1';
    if (d.length != (negotiated ? 10 : 9) ||
        ![2, 3].contains(d['schemaVersion']) ||
        !['move-catch-v1', 'reach-tap-v1'].contains(gameId) ||
        d['organizationId'] != scope.organizationId ||
        d['memberId'] != scope.userId ||
        d['mode'] != 'participation' ||
        d['redeemable'] != true ||
        d['physicalVerified'] != false ||
        d['overview'] is! Map ||
        d['result'] is! Map) {
      throw const FormatException('Invalid participation response.');
    }
    final o = Map<String, dynamic>.from(d['overview']),
        r = Map<String, dynamic>.from(d['result']);
    final policy = MiniGameRewardPolicy.fromJson(
        Map<String, dynamic>.from(o['policy'] as Map));
    if (policy.games.single.gameId != gameId ||
        o.length != 8 ||
        !_date(o['today']) ||
        o['timezone'] != 'Asia/Kuala_Lumpur' ||
        o['issuanceActive'] is! bool ||
        !n(o['balance']) ||
        !n(o['earnedToday']) ||
        !n(o['remainingToday']) ||
        !n(o['claimsToday']) ||
        o['remainingToday'] !=
            (policy.dailyPointsCap - o['earnedToday'])
                .clamp(0, 9007199254740991) ||
        r.length != 2 ||
        ![
          'overview',
          'not-active',
          'awarded',
          'already-awarded',
          'previously-recorded',
          'not-completed',
          'game-disabled',
          'game-limit',
          'daily-limit'
        ].contains(r['status']) ||
        (r['status'] == 'overview'
            ? r['attemptId'] != null
            : !_hex(r['attemptId']))) {
      throw const FormatException('Invalid participation counters or status.');
    }
    final award = d['award'] == null
        ? null
        : MiniGameParticipationAward.fromJson(
            Map<String, dynamic>.from(d['award'] as Map), scope);
    final awarded = ['awarded', 'already-awarded'].contains(r['status']);
    if (awarded != (award != null) ||
        (award != null &&
            (award.attemptId != r['attemptId'] || award.gameId != gameId)) ||
        (r['status'] == 'not-active' && o['issuanceActive'] != false)) {
      throw const FormatException('Inconsistent participation receipt.');
    }
    return MiniGameParticipation._(
        scope: scope,
        gameId: gameId,
        policy: policy,
        today: o['today'],
        active: o['issuanceActive'],
        balance: o['balance'],
        earnedToday: o['earnedToday'],
        remainingToday: o['remainingToday'],
        claimsToday: o['claimsToday'],
        status: r['status'],
        attemptId: r['attemptId'],
        award: award);
  }
}

class MiniGameParticipationAward {
  const MiniGameParticipationAward._(
      {required this.attemptId,
      required this.gameId,
      required this.awardId,
      required this.points,
      required this.policyVersion,
      required this.awardedAtMillis});
  final String attemptId, awardId, policyVersion, gameId;
  final int points, awardedAtMillis;
  factory MiniGameParticipationAward.fromJson(
      Map<String, dynamic> d, SessionScope scope) {
    if (d.length != 16 ||
        d['schemaVersion'] != 2 ||
        d['organizationId'] != scope.organizationId ||
        d['memberId'] != scope.userId ||
        !['move-catch-v1', 'reach-tap-v1'].contains(d['gameId']) ||
        !_hex(d['attemptId']) ||
        d['awardId'] is! String ||
        !RegExp(r'^participation_[a-f0-9]{64}$').hasMatch(d['awardId']) ||
        d['verification'] != 'participation' ||
        d['redeemable'] != true ||
        d['physicalVerified'] != false ||
        d['premiumBonus'] != false ||
        d['points'] is! int ||
        d['points'] < 1 ||
        d['points'] > 1000 ||
        d['awardedAtMillis'] is! int ||
        d['awardedAtMillis'] < 1 ||
        d['completedAtMillis'] is! int ||
        d['completedAtMillis'] < 1 ||
        d['completedAtMillis'] > d['awardedAtMillis'] ||
        !_date(d['date']) ||
        d['policySnapshot'] is! Map) {
      throw const FormatException('Invalid participation award.');
    }
    final policy = MiniGameRewardPolicy.fromJson(
        Map<String, dynamic>.from(d['policySnapshot']));
    if (policy.games.single.gameId != d['gameId'] ||
        d['policyVersion'] != policy.version ||
        policy.games.single.points != d['points'] ||
        DateTime.fromMillisecondsSinceEpoch(d['awardedAtMillis'], isUtc: true)
                .add(const Duration(hours: 8))
                .toIso8601String()
                .substring(0, 10) !=
            d['date']) {
      throw const FormatException('Invalid historical participation policy.');
    }
    return MiniGameParticipationAward._(
        attemptId: d['attemptId'],
        gameId: d['gameId'],
        awardId: d['awardId'],
        points: d['points'],
        policyVersion: d['policyVersion'],
        awardedAtMillis: d['awardedAtMillis']);
  }
}

bool _hex(dynamic v) => v is String && RegExp(r'^[a-f0-9]{32}$').hasMatch(v);
bool _date(dynamic v) {
  if (v is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) return false;
  final date = DateTime.tryParse(v);
  return date != null && date.toIso8601String().substring(0, 10) == v;
}

abstract interface class MiniGameParticipationRepository {
  SessionScope get scope;
  bool get current;
  Future<MiniGameParticipation> overview();
  Future<MiniGameParticipation> claim(String attemptId);
}

class MiniGameParticipationUnavailable implements Exception {
  const MiniGameParticipationUnavailable();
}

class MiniGameParticipationSessionChanged implements Exception {
  const MiniGameParticipationSessionChanged();
}
