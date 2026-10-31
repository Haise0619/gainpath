import 'dart:convert';

const programLevels = ['Beginner', 'Intermediate', 'Advanced'];
const programCategories = [
  'Full Body',
  'Upper Body',
  'Lower Body',
  'Push',
  'Pull',
  'Legs',
  'Active Recovery',
  'Rest'
];

List<String> programMuscles(String category) => switch (category) {
      'Full Body' => const ['upperPush', 'upperPull', 'lower'],
      'Upper Body' => const ['upperPush', 'upperPull'],
      'Lower Body' || 'Legs' => const ['lower'],
      'Push' => const ['upperPush'],
      'Pull' => const ['upperPull'],
      _ => const [],
    };

Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
        value.map((k, v) => MapEntry(k as String, _freeze(v))));
  }
  if (value is List) return List<dynamic>.unmodifiable(value.map(_freeze));
  return value;
}

/// One original program slot. Its identity does not change when rescheduled.
class ProgramDay {
  ProgramDay(
      {required this.week,
      required this.weekday,
      required this.kind,
      required this.category,
      this.routineId,
      this.routineDay = 1,
      List<String>? muscleGroups,
      this.restSeconds = 60,
      Map<String, dynamic>? routineSnapshot})
      : muscleGroups =
            List.unmodifiable(muscleGroups ?? programMuscles(category)),
        routineSnapshot = routineSnapshot == null
            ? null
            : _freeze(routineSnapshot) as Map<String, dynamic>;
  final int week, weekday, routineDay, restSeconds;
  final String kind, category;
  final String? routineId;
  final List<String> muscleGroups;
  final Map<String, dynamic>? routineSnapshot;
  String get key => 'w$week-d$weekday';

  void validate({bool published = false}) {
    if (week < 1 ||
        week > 4 ||
        weekday < 1 ||
        weekday > 7 ||
        !['workout', 'activeRecovery', 'rest'].contains(kind) ||
        !programCategories.contains(category) ||
        routineDay < 1 ||
        routineDay > 14 ||
        restSeconds < 0 ||
        restSeconds > 600) {
      throw const FormatException('Invalid program day or targets.');
    }
    if ((kind == 'workout' && ['Active Recovery', 'Rest'].contains(category)) ||
        (kind == 'activeRecovery' && category != 'Active Recovery') ||
        (kind == 'rest' && category != 'Rest')) {
      throw const FormatException('Day category does not match its kind.');
    }
    final expected = programMuscles(category).toSet();
    if (muscleGroups.length != expected.length ||
        !expected.containsAll(muscleGroups)) {
      throw const FormatException(
          'Muscle groups must match the workout category.');
    }
    if (kind != 'workout' && (routineId != null || routineSnapshot != null)) {
      throw const FormatException(
          'Recovery and rest days cannot contain workouts.');
    }
    if (routineId != null &&
        (routineId!.isEmpty ||
            routineId!.contains('/') ||
            routineId!.length > 180)) {
      throw const FormatException('Invalid routine reference.');
    }
    if (published && kind == 'workout') {
      final s = routineSnapshot;
      if (routineId == null ||
          s == null ||
          s['schemaVersion'] != 1 ||
          s['kind'] != 'routine' ||
          s['status'] != 'published' ||
          s['exercises'] is! List ||
          (s['exercises'] as List).isEmpty ||
          !(s['exercises'] as List)
              .any((e) => e is Map && (e['dayNumber'] ?? 1) == routineDay)) {
        throw const FormatException(
            'A published workout needs a published routine snapshot and valid day.');
      }
      for (final row in (s['exercises'] as List).whereType<Map>()) {
        if ((row['dayNumber'] ?? 1) != routineDay) continue;
        final metadata = '${row['category'] ?? ''} ${row['muscleGroup'] ?? ''}'
            .toLowerCase();
        final lower = RegExp(
                r'lower[\s-]*body|\blegs?\b|\bquads?\b|quadriceps|glutes?|calf|calves|hamstrings?')
            .hasMatch(metadata);
        final upper = RegExp(
                r'upper[\s-]*body|chest|shoulder|triceps?|biceps?|\bback\b|\barms?\b')
            .hasMatch(metadata);
        if ((lower && ['Push', 'Pull', 'Upper Body'].contains(category)) ||
            (upper && !lower && ['Lower Body', 'Legs'].contains(category))) {
          throw const FormatException(
              'Routine muscle metadata conflicts with the scheduled category.');
        }
      }
    }
  }

  factory ProgramDay.fromJson(Map<String, dynamic> value) {
    try {
      final d = ProgramDay(
          week: value['week'] as int,
          weekday: value['weekday'] as int,
          kind: value['kind'] as String,
          category: value['category'] as String,
          routineId: value['routineId'] as String?,
          routineDay: value['routineDay'] as int? ?? 1,
          muscleGroups: (value['muscleGroups'] as List).cast<String>(),
          restSeconds: value['restSeconds'] as int? ?? 60,
          routineSnapshot: value['routineSnapshot'] == null
              ? null
              : Map<String, dynamic>.from(value['routineSnapshot'] as Map));
      d.validate();
      return d;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid program day.');
    }
  }
  Map<String, dynamic> toJson() => {
        'week': week,
        'weekday': weekday,
        'kind': kind,
        'category': category,
        'routineDay': routineDay,
        'muscleGroups': muscleGroups.toList(),
        'restSeconds': restSeconds,
        if (routineId != null) 'routineId': routineId,
        if (routineSnapshot != null)
          'routineSnapshot': jsonDecode(jsonEncode(routineSnapshot)),
      };
}

/// Immutable publication payload, also used for incomplete Admin drafts (v0).
class WorkoutProgram {
  WorkoutProgram(
      {required this.id,
      required this.version,
      required this.title,
      required this.level,
      this.weeks = 4,
      required List<ProgramDay> days})
      : days = List.unmodifiable(days);
  final String id, title, level;
  final int version, weeks;
  final List<ProgramDay> days;

  void validate({bool published = false}) {
    if (id.isEmpty ||
        id.length > 100 ||
        !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id) ||
        version < 0 ||
        (published && version < 1) ||
        title.trim().isEmpty ||
        title.length > 120 ||
        !programLevels.contains(level) ||
        weeks != 4 ||
        days.length != 28 ||
        days.map((d) => d.key).toSet().length != 28) {
      throw const FormatException(
          'Program requires a title, level and four complete weeks.');
    }
    for (final d in days) {
      d.validate(published: published);
    }
    if (published) {
      final counts = [
        for (var w = 1; w <= weeks; w++)
          days.where((d) => d.week == w && d.kind == 'workout').length
      ];
      if (counts.first == 0 || counts.any((c) => c != counts.first)) {
        throw const FormatException(
            'Published weeks need the same nonzero number of training days.');
      }
    }
    final scheduled = [
      for (final d in days)
        ScheduledProgramDay(
            key: d.key,
            definition: d,
            date: DateTime.utc(2026, 1, 5)
                .add(Duration(days: (d.week - 1) * 7 + d.weekday - 1)))
    ];
    ProgramSchedule.validateRecovery(scheduled);
  }

  factory WorkoutProgram.fromJson(Map<String, dynamic> value) {
    try {
      if (value['schemaVersion'] != 1) {
        throw const FormatException('Unsupported program schema.');
      }
      final p = WorkoutProgram(
          id: value['id'] as String,
          version: value['version'] as int,
          title: value['title'] as String,
          level: value['level'] as String,
          weeks: value['weeks'] as int,
          days: (value['days'] as List)
              .map((d) =>
                  ProgramDay.fromJson(Map<String, dynamic>.from(d as Map)))
              .toList());
      p.validate(published: p.version > 0);
      return p;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid workout program.');
    }
  }
  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'id': id,
        'version': version,
        'title': title,
        'level': level,
        'weeks': weeks,
        'days': days.map((d) => d.toJson()).toList()
      };

  static List<WorkoutProgram> templates() {
    const splits = [
      {1: 'Full Body', 3: 'Full Body', 5: 'Full Body'},
      {1: 'Upper Body', 2: 'Lower Body', 4: 'Upper Body', 5: 'Lower Body'},
      {1: 'Push', 2: 'Pull', 3: 'Legs', 5: 'Upper Body', 6: 'Lower Body'},
    ];
    return List.generate(
        3,
        (i) => WorkoutProgram(
                id: '${programLevels[i].toLowerCase()}-four-week',
                version: 0,
                title: '${programLevels[i]} 4-week Program',
                level: programLevels[i],
                days: [
                  for (var week = 1; week <= 4; week++)
                    for (var day = 1; day <= 7; day++)
                      ProgramDay(
                          week: week,
                          weekday: day,
                          kind: splits[i].containsKey(day)
                              ? 'workout'
                              : day == 7
                                  ? 'rest'
                                  : 'activeRecovery',
                          category: splits[i][day] ??
                              (day == 7 ? 'Rest' : 'Active Recovery')),
                ]));
  }
}

class ScheduledProgramDay {
  ScheduledProgramDay(
      {required this.key, required this.definition, required DateTime date})
      : date = DateTime.utc(date.year, date.month, date.day);
  final String key;
  final ProgramDay definition;
  final DateTime date;
  Map<String, dynamic> toJson() => {
        'key': key,
        'definition': definition.toJson(),
        'date': date.toIso8601String()
      };
  factory ScheduledProgramDay.fromJson(Map<String, dynamic> json) {
    try {
      final d = ProgramDay.fromJson(
          Map<String, dynamic>.from(json['definition'] as Map));
      final date = DateTime.parse(json['date'] as String);
      if (json['key'] != d.key ||
          !date.isUtc ||
          date.hour != 0 ||
          date.minute != 0 ||
          date.second != 0 ||
          date.millisecond != 0) {
        throw const FormatException('Invalid scheduled day.');
      }
      return ScheduledProgramDay(key: d.key, definition: d, date: date);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid scheduled day.');
    }
  }
}

/// Calendar operations are date-only. Callers supply the Member's Malaysia date.
class ProgramSchedule {
  static List<ScheduledProgramDay> create(
      WorkoutProgram program, DateTime startDate, Set<int> trainingWeekdays) {
    program.validate();
    if (trainingWeekdays.any((d) => d < 1 || d > 7)) {
      throw const FormatException('Invalid training weekdays.');
    }
    final start = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final result = <ScheduledProgramDay>[];
    for (var week = 1; week <= program.weeks; week++) {
      final defs = program.days.where((d) => d.week == week).toList()
        ..sort((a, b) => a.weekday.compareTo(b.weekday));
      final workouts = defs.where((d) => d.kind == 'workout').toList();
      final recovery = defs.where((d) => d.kind != 'workout').toList();
      if (workouts.length != trainingWeekdays.length) {
        throw FormatException(
            'Choose exactly ${workouts.length} training days for week $week.');
      }
      var w = 0, r = 0;
      for (var offset = 0; offset < 7; offset++) {
        final date = start.add(Duration(days: (week - 1) * 7 + offset));
        final def = trainingWeekdays.contains(date.weekday)
            ? workouts[w++]
            : recovery[r++];
        result.add(
            ScheduledProgramDay(key: def.key, definition: def, date: date));
      }
    }
    validateRecovery(result);
    return List.unmodifiable(result);
  }

  static void validateRecovery(List<ScheduledProgramDay> entries) {
    if (entries.map((e) => e.date).toSet().length != entries.length ||
        entries.map((e) => e.key).toSet().length != entries.length) {
      throw const FormatException(
          'Schedule days must have unique identities and dates.');
    }
    final workouts = entries
        .where((d) => d.definition.kind == 'workout')
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    for (var i = 1; i < workouts.length; i++) {
      Set<String> exerciseIds(ScheduledProgramDay d) => {
            for (final row
                in (d.definition.routineSnapshot?['exercises'] as List? ??
                        const [])
                    .whereType<Map>())
              if ((row['dayNumber'] ?? 1) == d.definition.routineDay &&
                  row['exerciseId'] is String)
                row['exerciseId'] as String,
          };
      final repeatedExercises = exerciseIds(workouts[i])
          .intersection(exerciseIds(workouts[i - 1]))
          .isNotEmpty;
      if (workouts[i].date.difference(workouts[i - 1].date).inDays <= 1 &&
          (repeatedExercises ||
              workouts[i]
                  .definition
                  .muscleGroups
                  .any(workouts[i - 1].definition.muscleGroups.contains))) {
        throw const FormatException(
            'Leave a recovery day between workouts using the same muscle groups.');
      }
    }
  }

  static List<ScheduledProgramDay> reschedule(
      List<ScheduledProgramDay> entries, String key, DateTime date) {
    final source = entries.where((e) => e.key == key).firstOrNull;
    if (source == null || source.definition.kind != 'workout') {
      throw const FormatException('Choose a workout day.');
    }
    final target = DateTime.utc(date.year, date.month, date.day);
    final destination =
        entries.where((e) => e.date == target && e.key != key).firstOrNull;
    if (destination?.definition.kind == 'workout') {
      throw const FormatException(
          'Another workout is already scheduled that day.');
    }
    final result = [
      for (final e in entries)
        ScheduledProgramDay(
            key: e.key,
            definition: e.definition,
            date: e.key == key
                ? target
                : e.key == destination?.key
                    ? source.date
                    : e.date)
    ]..sort((a, b) => a.date.compareTo(b.date));
    validateRecovery(result);
    return List.unmodifiable(result);
  }
}
