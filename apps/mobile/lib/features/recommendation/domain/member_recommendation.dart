import 'package:gainpath_domain/coaching.dart';

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
      this.difficulty,
      this.durationMinutes,
      this.exerciseCount,
      this.priceMinor,
      this.currency,
      this.branchLabel,
      this.aiMethod,
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
  final String? difficulty, currency, branchLabel, aiMethod;
  final int? durationMinutes, exerciseCount, priceMinor;
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
    const extraKeys = {
      'difficulty',
      'durationMinutes',
      'exerciseCount',
      'priceMinor',
      'currency',
      'branchLabel',
      'aiMethod'
    };
    if (raw is! Map ||
        raw.keys
            .any((key) => !keys.contains(key) && !extraKeys.contains(key)) ||
        !raw.keys.toSet().containsAll(keys) ||
        raw['schemaVersion'] != 1 ||
        !const ['synthetic_local', 'accepted_workout', 'workout_backup']
            .contains(raw['mode']) ||
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
    int? number(String key, int max) {
      final value = raw[key];
      if (value == null) return null;
      if (value is! int || value < 0 || value > max) {
        throw const FormatException('Invalid recommendation metadata');
      }
      return value;
    }

    DateTime? time(String key, {bool required = false}) {
      final v = raw[key];
      if (v == null && !required) return null;
      if (v is! int || v <= 0 || v > 8640000000000000) {
        throw const FormatException('Invalid recommendation time');
      }
      return DateTime.fromMillisecondsSinceEpoch(v);
    }

    final kind = recommendationKind(raw['kind']);
    if (raw['aiMethod'] != null &&
        !{'gemini', 'rule_fallback'}.contains(raw['aiMethod'])) {
      throw const FormatException('Invalid recommendation method');
    }
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
            ].followedBy(extraKeys).any((key) => raw[key] != null) ||
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
        (target is RoutineRecommendationTarget &&
            kind != RecommendationKind.routine) ||
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
        difficulty: optional('difficulty', max: 80),
        durationMinutes: number('durationMinutes', 1440),
        exerciseCount: number('exerciseCount', 50),
        priceMinor: number('priceMinor', 1000000),
        currency: optional('currency', max: 8),
        branchLabel: optional('branchLabel', max: 200),
        aiMethod: optional('aiMethod', max: 30),
        createdAt: created,
        expiresAt: expires,
        deliveredAt: time('deliveredAtMillis'),
        readAt: time('readAtMillis'),
        acknowledgedAt: time('acknowledgedAtMillis'),
        dismissedAt: time('dismissedAtMillis'));
  }
}

/// Delivered projections only. Loading never marks a recommendation as read.
class MemberRecommendationPage {
  const MemberRecommendationPage(
      {required this.records, this.nextAfterId, this.enabled = true});
  final List<MemberRecommendationDetail> records;
  final String? nextAfterId;
  final bool enabled;
}

typedef MemberRecommendationPageLoader = Future<MemberRecommendationPage>
    Function({required bool history, String? afterId});
