import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/gamification.dart';
import 'mini_game_content_repository.dart' show MiniGameContentCall;

class RemoteMiniGameCompetitionRepository
    implements MiniGameCompetitionRepository {
  RemoteMiniGameCompetitionRepository(
      {required this.scope,
      required bool Function() isCurrent,
      required MiniGameContentCall call})
      : _isCurrent = isCurrent,
        _call = call;
  @override
  final SessionScope scope;
  final bool Function() _isCurrent;
  final MiniGameContentCall _call;
  @override
  bool get current => _isCurrent();
  void _check() {
    if (!current) throw const MiniGameCompetitionSessionChanged();
  }

  Future<Map<String, dynamic>> _command(Map<String, dynamic> fields) async {
    _check();
    try {
      final d = await _call({
        'schemaVersion': 1,
        'organizationId': scope.organizationId,
        'action': 'competition',
        'command': fields
      });
      _check();
      return d;
    } catch (_) {
      _check();
      rethrow;
    }
  }

  @override
  Future<MiniGameCompetitionPreference> preference() async =>
      MiniGameCompetitionPreference.fromJson(
          await _command({'action': 'preference'}), scope);
  @override
  Future<MiniGameCompetitionPreference> setPreference(
      {required bool enabled}) async {
    final p = MiniGameCompetitionPreference.fromJson(
        await _command({
          'action': 'setPreference',
          'enabled': enabled,
          'policyVersion': miniGameCompetitionPolicyVersion
        }),
        scope);
    if (p.enabled != enabled || p.revision == 0) {
      throw const FormatException('Preference was not confirmed.');
    }
    return p;
  }

  @override
  Future<MiniGameScoreLeaderboard> leaderboard(
      {required String gameId, required String period}) async {
    if (!competitiveGameIds.contains(gameId) ||
        !{'week', 'all-time'}.contains(period)) {
      throw const FormatException('Invalid game standings request.');
    }
    final r = MiniGameScoreLeaderboard.fromJson(
        await _command(
            {'action': 'leaderboard', 'gameId': gameId, 'period': period}),
        scope);
    if (r.gameId != gameId || r.period != period) {
      throw const FormatException('Standings response changed.');
    }
    return r;
  }

  @override
  Future<MiniGameAcceptedScore> submit(
      {required String gameId,
      required String attemptId,
      required String challengeToken,
      required List<MiniGameScoreEvent> events}) async {
    if (!competitiveGameIds.contains(gameId) ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(attemptId) ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(challengeToken) ||
        events.length > 400) {
      throw const FormatException('Invalid competitive submission.');
    }
    final r = MiniGameAcceptedScore.fromJson(
        await _command({
          'action': 'submit',
          'gameId': gameId,
          'scoringVersion': 1,
          'attemptId': attemptId,
          'challengeToken': challengeToken,
          'events': events.map((e) => e.toJson()).toList(growable: false)
        }),
        scope);
    if (r.gameId != gameId || r.attemptId != attemptId) {
      throw const FormatException('Accepted score response changed.');
    }
    return r;
  }
}
