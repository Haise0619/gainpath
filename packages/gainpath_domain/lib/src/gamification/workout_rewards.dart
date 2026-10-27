class WorkoutRewardDraft {
  const WorkoutRewardDraft(
      {this.revision = 0,
      this.version = 'draft-unconfigured',
      this.points = 100,
      this.dailyClaimLimit = 1,
      this.minimumCompletionPercent = 100,
      this.minimumVerifiedReps = 1,
      this.minimumTrackedSeconds = 1,
      this.eligibleRoutineIds = const [],
      this.difficultyPoints = const {
        'Beginner': 100,
        'Intermediate': 100,
        'Advanced': 100
      }});
  final int revision,
      points,
      dailyClaimLimit,
      minimumCompletionPercent,
      minimumVerifiedReps,
      minimumTrackedSeconds;
  final String version;
  final List<String> eligibleRoutineIds;
  final Map<String, int> difficultyPoints;
  Map<String, dynamic> toFields() => {
        'points': points,
        'dailyClaimLimit': dailyClaimLimit,
        'minimumCompletionPercent': minimumCompletionPercent,
        'minimumVerifiedReps': minimumVerifiedReps,
        'minimumTrackedSeconds': minimumTrackedSeconds,
        'eligibleRoutineIds': eligibleRoutineIds,
        'difficultyPoints': difficultyPoints
      };
  factory WorkoutRewardDraft.fromJson(Map<String, dynamic> d) {
    int number(String key, int min, int max) {
      final v = d[key];
      if (v is! int || v < min || v > max) {
        throw const FormatException('Invalid workout reward draft.');
      }
      return v;
    }

    final ids = d['eligibleRoutineIds'], difficulty = d['difficultyPoints'];
    if (d['schemaVersion'] != 1 ||
        d['enabled'] != false ||
        d['difficultyMultipliersEnabled'] != false ||
        d['eligibilityMode'] != 'verified_ai_only' ||
        d['timezone'] != 'Asia/Kuala_Lumpur' ||
        d['version'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(d['version'] as String) ||
        ids is! List ||
        ids.length > 100 ||
        ids.toSet().length != ids.length ||
        ids.any((i) =>
            i is! String || !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(i)) ||
        difficulty is! Map ||
        difficulty.length != 3 ||
        !['Beginner', 'Intermediate', 'Advanced'].every((k) =>
            difficulty[k] is int &&
            difficulty[k] >= 1 &&
            difficulty[k] <= 100000)) {
      throw const FormatException('Invalid disabled workout policy.');
    }
    return WorkoutRewardDraft(
        revision: number('revision', 0, 100000000),
        version: d['version'] as String,
        points: number('points', 1, 100000),
        dailyClaimLimit: number('dailyClaimLimit', 1, 10),
        minimumCompletionPercent: number('minimumCompletionPercent', 1, 100),
        minimumVerifiedReps: number('minimumVerifiedReps', 1, 10000),
        minimumTrackedSeconds: number('minimumTrackedSeconds', 1, 86400),
        eligibleRoutineIds: List.unmodifiable(ids.cast<String>()),
        difficultyPoints: Map.unmodifiable(Map<String, int>.from(difficulty)));
  }
}

class WorkoutRewardStatus {
  const WorkoutRewardStatus(
      {required this.status,
      required this.reason,
      this.policyVersion = 'draft-unconfigured',
      this.draftPoints = 100});
  final String status, reason, policyVersion;
  final int draftPoints;
  factory WorkoutRewardStatus.fromJson(Map<String, dynamic> d) {
    if (!['disabled', 'not_eligible', 'already_awarded', 'awarded']
            .contains(d['status']) ||
        d['reason'] is! String ||
        d['policyVersion'] is! String ||
        d['draftPoints'] is! int ||
        d['draftPoints'] < 1) {
      throw const FormatException('Invalid workout reward status.');
    }
    return WorkoutRewardStatus(
        status: d['status'] as String,
        reason: d['reason'] as String,
        policyVersion: d['policyVersion'] as String,
        draftPoints: d['draftPoints'] as int);
  }
}

abstract interface class WorkoutRewardConfigurationRepository {
  bool get current;
  Future<WorkoutRewardDraft> loadWorkoutRewardDraft();
  Future<void> saveWorkoutRewardDraft(
      {required String requestId,
      required int baseRevision,
      required WorkoutRewardDraft draft});
}
