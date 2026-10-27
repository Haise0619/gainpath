import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/gamification.dart';
import 'mini_game_content_repository.dart' show MiniGameContentCall;

class RemoteMiniGameParticipationRepository
    implements MiniGameParticipationRepository {
  RemoteMiniGameParticipationRepository(
      {required this.scope,
      required bool Function() isCurrent,
      required MiniGameContentCall call})
      : _current = isCurrent,
        _call = call;
  @override
  final SessionScope scope;
  final bool Function() _current;
  final MiniGameContentCall _call;
  @override
  bool get current => _current();
  void _check() {
    if (!current) throw const MiniGameParticipationSessionChanged();
  }

  Future<MiniGameParticipation> _command(String action,
      {String? attemptId}) async {
    _check();
    try {
      final d = await _call({
        'schemaVersion': 2,
        'organizationId': scope.organizationId,
        'action': action,
        if (attemptId != null) 'attemptId': attemptId
      });
      _check();
      final result = MiniGameParticipation.fromJson(d, scope);
      if (result.attemptId != attemptId) {
        throw const FormatException('Participation attempt changed.');
      }
      return result;
    } catch (_) {
      _check();
      rethrow;
    }
  }

  @override
  Future<MiniGameParticipation> overview() => _command('participationOverview');
  @override
  Future<MiniGameParticipation> claim(String attemptId) {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(attemptId)) {
      throw const FormatException('Invalid participation attempt.');
    }
    return _command('claimParticipation', attemptId: attemptId);
  }
}
