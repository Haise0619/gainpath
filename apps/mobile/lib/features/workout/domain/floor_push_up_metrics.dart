import 'dart:convert';

/// Schema-7 summary only; no video or per-frame landmarks are persisted.
class FloorPushUpMetrics {
  FloorPushUpMetrics(
      {required this.side,
      Map<String, double>? components,
      Map<String, int> issueCounts = const {},
      this.sourceVersion = 'floor-push-up-2d-crosscheck-v1'})
      : components = components == null ? null : Map.unmodifiable(components),
        issueCounts = Map.unmodifiable(issueCounts) {
    if ((side != null && !{'left', 'right'}.contains(side)) ||
        sourceVersion != 'floor-push-up-2d-crosscheck-v1' ||
        (components != null &&
            (side == null ||
                components.length != 4 ||
                !componentKeys.every(components.containsKey) ||
                components.values
                    .any((v) => !v.isFinite || v < 0 || v > 100))) ||
        issueCounts.entries.any((e) =>
            !issueKeys.contains(e.key) || e.value < 1 || e.value > 10000)) {
      throw const FormatException('Invalid floor push-up evidence.');
    }
  }
  static const componentKeys = {
    'rangeOfMotion',
    'bodyAlignment',
    'movementControl',
    'armExtension'
  };
  static const issueKeys = {
    'insufficientDescent',
    'hipSagging',
    'hipPiking',
    'incompleteExtension',
    'unstableTracking',
    'interrupted',
    'movementTooFast'
  };
  final String? side;
  final String sourceVersion;
  final Map<String, double>? components;
  final Map<String, int> issueCounts;
  double? get formScore => components == null
      ? null
      : components!['rangeOfMotion']! * .4 +
          components!['bodyAlignment']! * .35 +
          components!['movementControl']! * .15 +
          components!['armExtension']! * .1;
  Map<String, Object?> toJson() => {
        'side': side,
        'sourceVersion': sourceVersion,
        'components': components,
        'issueCounts': issueCounts
      };
  factory FloorPushUpMetrics.fromJson(Map<String, Object?> json) {
    if (json.length != 4 ||
        !{'side', 'sourceVersion', 'components', 'issueCounts'}
            .every(json.containsKey) ||
        (json['side'] != null && json['side'] is! String) ||
        json['sourceVersion'] is! String ||
        json['issueCounts'] is! Map ||
        (json['components'] != null && json['components'] is! Map)) {
      throw const FormatException('Invalid floor push-up fields.');
    }
    final rawIssues = json['issueCounts'] as Map,
        rawComponents = json['components'] as Map?;
    if (rawIssues.entries.any((e) => e.key is! String || e.value is! int) ||
        (rawComponents?.entries
                .any((e) => e.key is! String || e.value is! num) ??
            false)) {
      throw const FormatException('Invalid floor push-up aggregates.');
    }
    return FloorPushUpMetrics(
        side: json['side'] as String?,
        sourceVersion: json['sourceVersion'] as String,
        components: rawComponents
            ?.map((k, v) => MapEntry(k as String, (v as num).toDouble())),
        issueCounts: rawIssues.map((k, v) => MapEntry(k as String, v as int)));
  }
  @override
  bool operator ==(Object other) =>
      other is FloorPushUpMetrics &&
      side == other.side &&
      sourceVersion == other.sourceVersion &&
      _sameMap(components, other.components) &&
      _sameMap(issueCounts, other.issueCounts);
  static bool _sameMap(Map? a, Map? b) => a == null || b == null
      ? a == b
      : a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
  @override
  int get hashCode => Object.hash(
      side,
      sourceVersion,
      jsonEncode(components == null
          ? null
          : {for (final k in componentKeys) k: components![k]}),
      jsonEncode({
        for (final k in issueKeys)
          if (issueCounts.containsKey(k)) k: issueCounts[k]
      }));
}
