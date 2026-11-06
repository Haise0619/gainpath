import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

class MemberRecommendationUnavailable implements Exception {
  const MemberRecommendationUnavailable();
}

class MemberRecommendationDetail {
  const MemberRecommendationDetail(
      {required this.organizationId,
      required this.recommendationId,
      required this.kind,
      required this.revision,
      required this.state,
      required this.title,
      required this.summary,
      required this.explanations,
      required this.createdAt,
      required this.expiresAt,
      this.exerciseLabel,
      this.objective,
      this.target,
      this.targetLabel,
      this.specialization,
      this.imageUrl,
      this.photoPath,
      this.deliveredAt,
      this.readAt,
      this.acknowledgedAt,
      this.dismissedAt});
  final String organizationId, recommendationId, title, summary;
  final RecommendationKind kind;
  final int revision;
  final MemberRecommendationState state;
  final String? exerciseLabel,
      objective,
      targetLabel,
      specialization,
      imageUrl,
      photoPath;
  final List<String> explanations;
  final RecommendationTarget? target;
  final DateTime createdAt, expiresAt;
  final DateTime? deliveredAt, readAt, acknowledgedAt, dismissedAt;
  bool get available =>
      state == MemberRecommendationState.available && target != null;

  static MemberRecommendationDetail parse(Object? raw, String org, String id) {
    const keys = {
      'schemaVersion',
      'mode',
      'organizationId',
      'recommendationId',
      'kind',
      'revision',
      'state',
      'title',
      'summary',
      'exerciseLabel',
      'objective',
      'explanations',
      'target',
      'targetLabel',
      'specialization',
      'imageUrl',
      'photoPath',
      'createdAtMillis',
      'deliveredAtMillis',
      'expiresAtMillis',
      'readAtMillis',
      'acknowledgedAtMillis',
      'dismissedAtMillis'
    };
    if (raw is! Map ||
        raw.length != keys.length ||
        !raw.keys.toSet().containsAll(keys) ||
        raw['schemaVersion'] != 1 ||
        raw['mode'] != 'synthetic_local' ||
        raw['organizationId'] != org ||
        raw['recommendationId'] != id ||
        raw['revision'] is! int ||
        (raw['revision'] as int) < 0) {
      throw const FormatException('Invalid recommendation response');
    }
    String text(String key, {int max = 400}) {
      final v = raw[key];
      if (v is! String ||
          v.trim().isEmpty ||
          v.length > max ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(v)) {
        throw const FormatException('Invalid recommendation text');
      }
      return v;
    }

    String? optional(String key, {int max = 400}) =>
        raw[key] == null ? null : text(key, max: max);
    DateTime? time(String key, {bool required = false}) {
      final v = raw[key];
      if (v == null && !required) return null;
      if (v is! int || v <= 0 || v > 8640000000000000) {
        throw const FormatException('Invalid recommendation time');
      }
      return DateTime.fromMillisecondsSinceEpoch(v);
    }

    final kind = recommendationKind(raw['kind']);
    final state = recommendationState(raw['state']);
    if (raw['revision'] == 0 &&
        (state != MemberRecommendationState.notDelivered ||
            [
              'deliveredAtMillis',
              'readAtMillis',
              'acknowledgedAtMillis',
              'dismissedAtMillis',
              'target',
              'targetLabel',
              'exerciseLabel',
              'objective',
              'specialization',
              'imageUrl',
              'photoPath'
            ].any((key) => raw[key] != null) ||
            raw['explanations'] is! List ||
            (raw['explanations'] as List).isNotEmpty)) {
      throw const FormatException('Invalid prepared recommendation');
    }
    final target = raw['target'] == null
        ? null
        : RecommendationTarget.parse(raw['target'], org);
    if ((target is TrainerRecommendationTarget &&
            kind != RecommendationKind.trainer) ||
        (target is ContentRecommendationTarget &&
            kind != RecommendationKind.content) ||
        (state == MemberRecommendationState.available && target == null)) {
      throw const FormatException('Invalid recommendation destination');
    }
    final reasons = raw['explanations'];
    if (reasons is! List ||
        reasons.length > 6 ||
        reasons
            .any((v) => v is! String || v.trim().isEmpty || v.length > 400)) {
      throw const FormatException('Invalid recommendation explanation');
    }
    final created = time('createdAtMillis', required: true)!;
    final expires = time('expiresAtMillis', required: true)!;
    if (!expires.isAfter(created)) {
      throw const FormatException('Invalid recommendation expiry');
    }
    return MemberRecommendationDetail(
        organizationId: org,
        recommendationId: id,
        kind: kind,
        revision: raw['revision'] as int,
        state: state,
        title: text('title'),
        summary: text('summary'),
        exerciseLabel: optional('exerciseLabel'),
        objective: optional('objective'),
        explanations: List<String>.unmodifiable(reasons),
        target: target,
        targetLabel: optional('targetLabel'),
        specialization: optional('specialization'),
        imageUrl: optional('imageUrl', max: 2048),
        photoPath: optional('photoPath', max: 1024),
        createdAt: created,
        expiresAt: expires,
        deliveredAt: time('deliveredAtMillis'),
        readAt: time('readAtMillis'),
        acknowledgedAt: time('acknowledgedAtMillis'),
        dismissedAt: time('dismissedAtMillis'));
  }
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
      required MemberRecommendationRpc invoke})
      : _current = isCurrent,
        _invoke = invoke;
  @override
  final SessionScope scope;
  final bool Function() _current;
  final MemberRecommendationRpc _invoke;
  @override
  bool get enabled => true;
  @override
  bool get fixtureOnly => true;
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
