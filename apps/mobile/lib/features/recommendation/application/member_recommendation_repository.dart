import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../domain/member_recommendation.dart';

export '../domain/member_recommendation.dart';

class MemberRecommendationUnavailable implements Exception {
  const MemberRecommendationUnavailable();
}

typedef MemberRecommendationRpc = Future<Map<String, Object?>> Function(
    Map<String, Object?> request);

abstract interface class MemberRecommendationRepository {
  SessionScope get scope;
  bool get enabled;
  bool get fixtureOnly;
  bool get isCurrent;
  Future<MemberRecommendationDetail> get(String id);
  Future<MemberRecommendationDetail> resolve(String id);
  Future<MemberRecommendationDetail> act(
      MemberRecommendationDetail detail, String action, String commandId);
}

/// No Firebase export or synthetic fallback is enabled by normal composition.
class UnavailableMemberRecommendationRepository
    implements MemberRecommendationRepository {
  const UnavailableMemberRecommendationRepository(this.scope);
  @override
  final SessionScope scope;
  @override
  bool get enabled => false;
  @override
  bool get fixtureOnly => false;
  @override
  bool get isCurrent => false;
  @override
  Future<MemberRecommendationDetail> get(String id) async =>
      throw const MemberRecommendationUnavailable();
  @override
  Future<MemberRecommendationDetail> resolve(String id) async =>
      throw const MemberRecommendationUnavailable();
  @override
  Future<MemberRecommendationDetail> act(MemberRecommendationDetail detail,
          String action, String commandId) async =>
      throw const MemberRecommendationUnavailable();
}

/// Explicit synthetic/emulator transport. Its trusted server boundary owns identity,
/// consent, target checks and durable transactions; no recipient ID is submitted.
class RpcMemberRecommendationRepository
    implements MemberRecommendationRepository {
  RpcMemberRecommendationRepository(
      {required this.scope,
      required bool Function() isCurrent,
      required MemberRecommendationRpc invoke,
      this.fixtureOnly = true})
      : _current = isCurrent,
        _invoke = invoke;
  @override
  final SessionScope scope;
  final bool Function() _current;
  final MemberRecommendationRpc _invoke;
  @override
  bool get enabled => true;
  @override
  final bool fixtureOnly;
  @override
  bool get isCurrent => _current();
  void _check() {
    if (!isCurrent) throw const MemberRecommendationUnavailable();
  }

  Future<MemberRecommendationDetail> _call(String id, String action,
      {String? commandId, int? revision}) async {
    _check();
    if (id.isEmpty || id.length > 200 || id.contains('/')) {
      throw const MemberRecommendationUnavailable();
    }
    final raw = await _invoke({
      'schemaVersion': 1,
      'organizationId': scope.organizationId,
      'recommendationId': id,
      'action': action,
      'commandId': commandId,
      'expectedRevision': revision
    });
    _check();
    return MemberRecommendationDetail.parse(raw, scope.organizationId, id);
  }

  @override
  Future<MemberRecommendationDetail> get(String id) => _call(id, 'get');
  @override
  Future<MemberRecommendationDetail> resolve(String id) => _call(id, 'resolve');
  @override
  Future<MemberRecommendationDetail> act(
      MemberRecommendationDetail detail, String action, String commandId) {
    _check();
    if (detail.organizationId != scope.organizationId ||
        !{'read', 'acknowledge', 'dismiss'}.contains(action) ||
        commandId.trim().isEmpty ||
        commandId.length > 150) {
      throw const MemberRecommendationUnavailable();
    }
    return _call(detail.recommendationId, action,
        commandId: commandId, revision: detail.revision);
  }
}

/// Consumer-only grouping; each delivery retains its own response identity.
String? memberRecommendationTargetKey(MemberRecommendationDetail d) {
  final id = switch (d.target) {
    TrainerRecommendationTarget t => t.coachId,
    ContentRecommendationTarget t => t.exerciseId,
    RoutineRecommendationTarget t => t.routineId,
    _ => null,
  };
  return id == null ? null : '${d.organizationId}/${d.kind.name}/$id';
}

List<List<MemberRecommendationDetail>> mergeAvailableMemberRecommendations(
    Iterable<MemberRecommendationDetail> records, DateTime now) {
  final groups = <String, List<MemberRecommendationDetail>>{};
  for (final r in records) {
    final key = memberRecommendationTargetKey(r);
    if (key == null ||
        !r.available ||
        r.deliveredAt == null ||
        r.revision < 1 ||
        !r.expiresAt.isAfter(now)) {
      continue;
    }
    final group = groups.putIfAbsent(key, () => []);
    group.removeWhere((d) => d.recommendationId == r.recommendationId);
    group.add(r);
  }
  int newest(MemberRecommendationDetail a, MemberRecommendationDetail b) {
    final created = b.createdAt.compareTo(a.createdAt);
    if (created != 0) return created;
    final delivered = b.deliveredAt!.compareTo(a.deliveredAt!);
    return delivered != 0
        ? delivered
        : b.recommendationId.compareTo(a.recommendationId);
  }

  final result = groups.values.toList();
  for (final group in result) {
    group.sort(newest);
  }
  result.sort((a, b) => newest(a.first, b.first));
  return result;
}

Future<void> dismissMemberRecommendationGroup(
    MemberRecommendationRepository repo,
    List<MemberRecommendationDetail> records,
    bool Function() isCurrent) async {
  for (final previous in records) {
    if (!isCurrent() || !repo.isCurrent) {
      throw const MemberRecommendationUnavailable();
    }
    final current = await repo.get(previous.recommendationId);
    if (!isCurrent() || !repo.isCurrent) {
      throw const MemberRecommendationUnavailable();
    }
    if (!current.available || !current.expiresAt.isAfter(DateTime.now())) {
      continue;
    }
    if (memberRecommendationTargetKey(current) !=
        memberRecommendationTargetKey(previous)) {
      throw const MemberRecommendationUnavailable();
    }
    await repo.act(current, 'dismiss',
        'dismiss-${current.recommendationId}-${current.revision}');
  }
}
