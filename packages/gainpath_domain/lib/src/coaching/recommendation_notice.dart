enum RecommendationKind { trainer, content }

enum MemberRecommendationState {
  available,
  notDelivered,
  expired,
  withdrawn,
  dismissed,
  unavailable
}

MemberRecommendationState recommendationState(Object? value) => switch (value) {
      'available' => MemberRecommendationState.available,
      'not_delivered' => MemberRecommendationState.notDelivered,
      'expired' => MemberRecommendationState.expired,
      'withdrawn' => MemberRecommendationState.withdrawn,
      'dismissed' => MemberRecommendationState.dismissed,
      'unavailable' => MemberRecommendationState.unavailable,
      _ => throw const FormatException('Invalid recommendation state'),
    };
RecommendationKind recommendationKind(Object? value) => switch (value) {
      'trainer' => RecommendationKind.trainer,
      'content' => RecommendationKind.content,
      _ => throw const FormatException('Invalid recommendation kind'),
    };

sealed class RecommendationTarget {
  const RecommendationTarget();
  static RecommendationTarget parse(Object? raw, String organizationId) {
    if (raw is! Map) {
      throw const FormatException('Invalid recommendation target');
    }
    final map = Map<String, Object?>.from(raw);
    if (map['kind'] == 'trainer' &&
        map.length == 5 &&
        _id(map['coachId']) &&
        _id(map['branchId']) &&
        map['observedStartAtMillis'] is int &&
        map['observedEndAtMillis'] is int) {
      final start = map['observedStartAtMillis'] as int;
      final end = map['observedEndAtMillis'] as int;
      if (start > 0 && end > start && end - start <= 3600000) {
        return TrainerRecommendationTarget(
            map['coachId'] as String, map['branchId'] as String, start, end);
      }
    }
    if (map['kind'] == 'content' &&
        map.length == 2 &&
        map['destination'] is Map) {
      final d = Map<String, Object?>.from(map['destination'] as Map);
      if (d.length == 6 &&
          d['kind'] == 'published_routine_exercise_tutorial' &&
          d['organizationId'] == organizationId &&
          _id(d['routineId']) &&
          _id(d['exerciseId']) &&
          d['exerciseIndex'] is int &&
          (d['exerciseIndex'] as int) >= 0 &&
          (d['exerciseIndex'] as int) < 50 &&
          d['dayNumber'] is int &&
          (d['dayNumber'] as int) > 0 &&
          (d['dayNumber'] as int) <= 50) {
        return ContentRecommendationTarget(
            organizationId,
            d['routineId'] as String,
            d['exerciseIndex'] as int,
            d['exerciseId'] as String,
            d['dayNumber'] as int);
      }
    }
    throw const FormatException('Invalid recommendation target');
  }

  static bool _id(Object? value) =>
      value is String &&
      value.trim().isNotEmpty &&
      value.length <= 200 &&
      !value.contains('/') &&
      value != '.' &&
      value != '..';
}

class TrainerRecommendationTarget extends RecommendationTarget {
  const TrainerRecommendationTarget(this.coachId, this.branchId,
      this.observedStartAtMillis, this.observedEndAtMillis);
  final String coachId, branchId;
  final int observedStartAtMillis, observedEndAtMillis;
}

class ContentRecommendationTarget extends RecommendationTarget {
  const ContentRecommendationTarget(this.organizationId, this.routineId,
      this.exerciseIndex, this.exerciseId, this.dayNumber);
  final String organizationId, routineId, exerciseId;
  final int exerciseIndex, dayNumber;
}

/// Minimal server-owned projection in the existing Member Notification Center.
class RecommendationNotice {
  const RecommendationNotice(
      {required this.recommendationId,
      required this.kind,
      required this.state,
      required this.expiresAt,
      required this.target});
  final String recommendationId;
  final RecommendationKind kind;
  final MemberRecommendationState state;
  final DateTime expiresAt;
  final RecommendationTarget? target;
  static RecommendationNotice parse(Object? raw, String organizationId) {
    if (raw is! Map ||
        raw.length != 6 ||
        raw['schemaVersion'] != 1 ||
        !RecommendationTarget._id(raw['recommendationId']) ||
        raw['expiresAtMillis'] is! int ||
        (raw['expiresAtMillis'] as int) <= 0 ||
        !raw.containsKey('target')) {
      throw const FormatException('Invalid recommendation notice');
    }
    final kind = recommendationKind(raw['kind']);
    final target = raw['target'] == null
        ? null
        : RecommendationTarget.parse(raw['target'], organizationId);
    if ((kind == RecommendationKind.trainer &&
            target is ContentRecommendationTarget) ||
        (kind == RecommendationKind.content &&
            target is TrainerRecommendationTarget)) {
      throw const FormatException('Mismatched recommendation target');
    }
    return RecommendationNotice(
        recommendationId: raw['recommendationId'] as String,
        kind: kind,
        state: recommendationState(raw['state']),
        expiresAt:
            DateTime.fromMillisecondsSinceEpoch(raw['expiresAtMillis'] as int),
        target: target);
  }
}
