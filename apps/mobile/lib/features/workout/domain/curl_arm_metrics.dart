enum CurlArmMode {
  both('Both arms'),
  leftOnly('Left only'),
  rightOnly('Right only');

  const CurlArmMode(this.label);
  final String label;
}

/// Local aggregates only; no pose frames or inferred weight are retained.
class CurlArmResult {
  CurlArmResult(
      {required this.repetitions,
      required this.partialRepetitions,
      required this.formScorePercent}) {
    if (repetitions < 0 ||
        partialRepetitions < 0 ||
        repetitions + partialRepetitions > 10000 ||
        (formScorePercent != null &&
            (!formScorePercent!.isFinite ||
                formScorePercent! < 0 ||
                formScorePercent! > 100)) ||
        ((repetitions + partialRepetitions == 0) !=
            (formScorePercent == null))) {
      throw const FormatException('Invalid curl arm result');
    }
  }
  final int repetitions, partialRepetitions;
  final double? formScorePercent;
  int get attempts => repetitions + partialRepetitions;
  Map<String, Object?> toJson() => {
        'repetitions': repetitions,
        'partialRepetitions': partialRepetitions,
        'formScorePercent': formScorePercent
      };
  factory CurlArmResult.fromJson(Map<String, Object?> json) {
    _keys(json, {'repetitions', 'partialRepetitions', 'formScorePercent'});
    final score = json['formScorePercent'];
    if (score != null && score is! num) {
      throw const FormatException('Invalid arm score');
    }
    return CurlArmResult(
        repetitions: _int(json, 'repetitions'),
        partialRepetitions: _int(json, 'partialRepetitions'),
        formScorePercent: (score as num?)?.toDouble());
  }
  @override
  bool operator ==(Object other) =>
      other is CurlArmResult &&
      repetitions == other.repetitions &&
      partialRepetitions == other.partialRepetitions &&
      formScorePercent == other.formScorePercent;
  @override
  int get hashCode =>
      Object.hash(repetitions, partialRepetitions, formScorePercent);
}

class CurlArmMetrics {
  CurlArmMetrics(
      {required this.mode,
      required this.targetSets,
      required this.repetitionsPerArm,
      required this.completedSets,
      required this.left,
      required this.right}) {
    final selected = [
      if (mode != CurlArmMode.rightOnly) left,
      if (mode != CurlArmMode.leftOnly) right
    ];
    final unselected = mode == CurlArmMode.both
        ? null
        : mode == CurlArmMode.leftOnly
            ? right
            : left;
    if (targetSets < 1 ||
        targetSets > 50 ||
        repetitionsPerArm < 1 ||
        repetitionsPerArm > 1000 ||
        completedSets < 0 ||
        completedSets > targetSets ||
        selected.any((r) =>
            r.repetitions < completedSets * repetitionsPerArm ||
            r.repetitions > targetSets * repetitionsPerArm) ||
        (unselected != null && unselected.attempts != 0)) {
      throw const FormatException('Invalid curl arm targets');
    }
  }
  final CurlArmMode mode;
  final int targetSets, repetitionsPerArm, completedSets;
  final CurlArmResult left, right;
  int get repetitions => left.repetitions + right.repetitions;
  int get partialRepetitions =>
      left.partialRepetitions + right.partialRepetitions;
  double? get formScorePercent => left.attempts + right.attempts == 0
      ? null
      : ((left.formScorePercent ?? 0) * left.attempts +
              (right.formScorePercent ?? 0) * right.attempts) /
          (left.attempts + right.attempts);
  bool completes(int sets, int reps) =>
      completedSets >= sets && repetitionsPerArm >= reps;
  String get countLabel =>
      'Left: ${left.repetitions} · Right: ${right.repetitions}';
  Map<String, Object?> toJson() => {
        'mode': mode.name,
        'targetSets': targetSets,
        'repetitionsPerArm': repetitionsPerArm,
        'completedSets': completedSets,
        'left': left.toJson(),
        'right': right.toJson()
      };
  factory CurlArmMetrics.fromJson(Map<String, Object?> json) {
    _keys(json, {
      'mode',
      'targetSets',
      'repetitionsPerArm',
      'completedSets',
      'left',
      'right'
    });
    final mode =
        CurlArmMode.values.where((m) => m.name == json['mode']).firstOrNull;
    if (mode == null || json['left'] is! Map || json['right'] is! Map) {
      throw const FormatException('Invalid curl arm metrics');
    }
    return CurlArmMetrics(
        mode: mode,
        targetSets: _int(json, 'targetSets'),
        repetitionsPerArm: _int(json, 'repetitionsPerArm'),
        completedSets: _int(json, 'completedSets'),
        left: CurlArmResult.fromJson(
            Map<String, Object?>.from(json['left'] as Map)),
        right: CurlArmResult.fromJson(
            Map<String, Object?>.from(json['right'] as Map)));
  }
  @override
  bool operator ==(Object other) =>
      other is CurlArmMetrics &&
      mode == other.mode &&
      targetSets == other.targetSets &&
      repetitionsPerArm == other.repetitionsPerArm &&
      completedSets == other.completedSets &&
      left == other.left &&
      right == other.right;
  @override
  int get hashCode => Object.hash(
      mode, targetSets, repetitionsPerArm, completedSets, left, right);
}

void _keys(Map<String, Object?> json, Set<String> keys) {
  if (json.length != keys.length || !keys.every(json.containsKey)) {
    throw const FormatException('Invalid curl arm fields');
  }
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw const FormatException('Invalid curl arm integer');
  return value;
}
