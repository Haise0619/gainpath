import 'dart:convert';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/gamification.dart';
import 'mini_game_content_repository.dart' show MiniGameContentCall;

class _Transport {
  _Transport(this.scope, this.isCurrent, this.call);
  final SessionScope scope;
  final bool Function() isCurrent;
  final MiniGameContentCall call;
  void check() {
    if (!isCurrent()) throw const MiniGameRewardSessionChanged();
  }

  Future<Map<String, dynamic>> command(Map<String, dynamic> fields) async {
    check();
    try {
      final d = await call({
        'schemaVersion': 1,
        'organizationId': scope.organizationId,
        ...fields
      });
      check();
      if (d['schemaVersion'] != 1 ||
          d['organizationId'] != scope.organizationId) {
        throw const FormatException('Mini-game reward response scope changed.');
      }
      return d;
    } catch (_) {
      check();
      rethrow;
    }
  }
}

class RemoteMiniGameRewardStatusReader implements MiniGameRewardStatusReader {
  RemoteMiniGameRewardStatusReader(
      {required SessionScope scope,
      required bool Function() isCurrent,
      required MiniGameContentCall call})
      : _transport = _Transport(scope, isCurrent, call);
  final _Transport _transport;
  @override
  SessionScope get scope => _transport.scope;
  @override
  bool get current => _transport.isCurrent();
  @override
  Future<MiniGameRewardStatus> overview() async =>
      MiniGameRewardStatus.fromJson(
          await _transport.command({'action': 'overview'}), scope);
}

class RemoteMiniGameRewardConfigurationRepository
    implements MiniGameRewardConfigurationRepository {
  RemoteMiniGameRewardConfigurationRepository(
      {required SessionScope scope,
      required bool Function() isCurrent,
      required MiniGameContentCall call})
      : _transport = _Transport(scope, isCurrent, call);
  final _Transport _transport;
  @override
  SessionScope get scope => _transport.scope;
  @override
  bool get current => _transport.isCurrent();
  MiniGameRewardPolicy _policy(Map<String, dynamic> d) {
    if (d.length != 4 || d['issuanceActive'] != false || d['policy'] is! Map) {
      throw const FormatException('Mini-game reward policy unavailable.');
    }
    return MiniGameRewardPolicy.fromJson(
        Map<String, dynamic>.from(d['policy'] as Map));
  }

  @override
  Future<MiniGameRewardPolicy> loadPolicy() async =>
      _policy(await _transport.command({'action': 'adminOverview'}));
  @override
  Future<MiniGameRewardPolicy> savePolicy(
      {required String requestId,
      required int baseRevision,
      required MiniGameRewardPolicy policy}) async {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(requestId) ||
        baseRevision < 0 ||
        policy.revision != baseRevision) {
      throw const FormatException('Invalid mini-game reward draft reference.');
    }
    final d = await _transport.command({
      'action': 'savePolicy',
      'requestId': requestId,
      'baseRevision': baseRevision,
      ...policy.toFields()
    });
    final saved = _policy(d);
    if (saved.revision != baseRevision + 1 ||
        jsonEncode(saved.toFields()) != jsonEncode(policy.toFields())) {
      throw const MiniGameRewardConflict();
    }
    return saved;
  }
}
