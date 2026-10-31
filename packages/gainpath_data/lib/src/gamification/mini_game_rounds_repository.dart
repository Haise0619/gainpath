import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/gamification.dart';
import 'mini_game_content_repository.dart' show MiniGameContentCall;

class RemoteMiniGameRoundRepository implements MiniGameRoundRepository {
  RemoteMiniGameRoundRepository(
      {required this.scope,
      this.gameId = 'move-catch-v1',
      required bool Function() isCurrent,
      required MiniGameContentCall call})
      : _isCurrent = isCurrent,
        _call = call;
  @override
  final SessionScope scope;
  final String gameId;
  final bool Function() _isCurrent;
  final MiniGameContentCall _call;
  @override
  bool get current => _isCurrent();
  void _check() {
    if (!current) throw const MiniGameRoundSessionChanged();
  }

  Future<MiniGameRound> _command(Map<String, dynamic> fields) async {
    _check();
    try {
      final d = await _call({
        'schemaVersion': 1,
        'organizationId': scope.organizationId,
        ...fields
      });
      _check();
      return MiniGameRound.fromJson(d, scope, gameId: gameId);
    } catch (_) {
      _check();
      rethrow;
    }
  }

  Map<String, dynamic> _bound(MiniGameRound r) {
    if (r.scope != scope || r.gameId != gameId) {
      throw const MiniGameRoundSessionChanged();
    }
    return {'attemptId': r.attemptId, 'challengeToken': r.challengeToken};
  }

  MiniGameRound _validate(
      MiniGameRound r, MiniGameRound before, int sequence, String status,
      {int? active}) {
    if (r.attemptId != before.attemptId ||
        r.challengeToken != before.challengeToken ||
        r.startedAtMillis != before.startedAtMillis ||
        r.expiresAtMillis != before.expiresAtMillis ||
        r.sequence != sequence ||
        r.status != status ||
        (active != null && r.activeMillis != active)) {
      throw const FormatException('Round response does not match command.');
    }
    return r;
  }

  @override
  Future<MiniGameRound> begin({required String requestId}) async {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(requestId)) {
      throw const FormatException('Invalid round request ID.');
    }
    final r = await _command(
        {'action': 'begin', 'requestId': requestId, 'gameId': gameId});
    if (r.status != 'open' || r.sequence != 0 || r.activeMillis != 0) {
      throw const FormatException('Round is already used.');
    }
    return r;
  }

  @override
  Future<MiniGameRound> checkpoint(
      {required MiniGameRound round,
      required int sequence,
      required int activeMillis,
      required bool playing}) async {
    if (sequence != round.sequence + 1 ||
        sequence > 360 ||
        activeMillis < round.activeMillis ||
        activeMillis > 40000 ||
        activeMillis - round.activeMillis > 5000 ||
        round.status != 'open') {
      throw const FormatException('Invalid round checkpoint.');
    }
    final r = await _command({
      'action': 'checkpoint',
      ..._bound(round),
      'sequence': sequence,
      'activeMillis': activeMillis,
      'phase': playing ? 'active' : 'paused'
    });
    return _validate(r, round, sequence, 'open', active: activeMillis);
  }

  @override
  Future<MiniGameRound> finish(
      {required MiniGameRound round, required int sequence}) async {
    if (round.status != 'open' ||
        round.activeMillis != 40000 ||
        sequence != round.sequence + 1) {
      throw const FormatException('Incomplete round timing.');
    }
    final r = await _command(
        {'action': 'finish', ..._bound(round), 'sequence': sequence});
    return _validate(r, round, sequence, 'awaiting_verification',
        active: 40000);
  }

  @override
  Future<MiniGameRound> abandon({required MiniGameRound round}) async {
    final r = await _command({'action': 'abandon', ..._bound(round)});
    return _validate(r, round, round.sequence, 'abandoned',
        active: round.activeMillis);
  }
}
