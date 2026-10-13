import 'dart:convert';

import '../identity.dart';

/// Durable upload metadata, independent of the locally measured counts.
enum LocalWorkoutRecordStatus {
  localOnly,
  pending,
  retryable,
  rejected,
  accepted,
  unknown,
}

/// A saved, measured capture. Form is an estimated rule metric, not accuracy.
class LocalWorkoutProgressRecord {
  LocalWorkoutProgressRecord({
    required this.scope,
    required this.sessionId,
    required this.exerciseId,
    required DateTime startedAt,
    required DateTime endedAt,
    required this.repetitions,
    required this.partialRepetitions,
    required this.trackedDurationMicros,
    required this.rejectedDurationMicros,
    required double? formScorePercent,
    required this.scoringVersion,
    required this.detectorId,
    required this.detectorVersion,
    required this.cameraView,
    required this.status,
    this.failureCode,
    DateTime? acceptedAt,
  })  : startedAt = startedAt.toUtc(),
        endedAt = endedAt.toUtc(),
        acceptedAt = acceptedAt?.toUtc(),
        formScorePercent =
            repetitions + partialRepetitions == 0 ? null : formScorePercent {
    for (final label in [
      sessionId,
      exerciseId,
      scoringVersion,
      detectorId,
      detectorVersion,
      cameraView
    ]) {
      if (label.trim().isEmpty) {
        throw ArgumentError(
            'Session, exercise and metric versions are required.');
      }
    }
    if (!this.endedAt.isAfter(this.startedAt)) {
      throw ArgumentError('A saved capture must have positive elapsed time.');
    }
    if (repetitions < 0 ||
        partialRepetitions < 0 ||
        trackedDurationMicros < 0 ||
        rejectedDurationMicros < 0) {
      throw ArgumentError('Counts and measured durations cannot be negative.');
    }
    if (trackedDurationMicros + rejectedDurationMicros >
        this.endedAt.difference(this.startedAt).inMicroseconds) {
      throw ArgumentError(
          'Measured durations cannot exceed elapsed capture time.');
    }
    if (trackedDurationMicros == 0 &&
        (repetitions > 0 ||
            partialRepetitions > 0 ||
            formScorePercent != null)) {
      throw ArgumentError(
          'Attempts and estimated form require tracked duration.');
    }
    if (formScorePercent != null &&
        (!formScorePercent.isFinite ||
            formScorePercent < 0 ||
            formScorePercent > 100)) {
      throw ArgumentError('Estimated form must be a finite percentage.');
    }
  }

  final SessionScope scope;
  final String sessionId;
  final String exerciseId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int repetitions;
  final int partialRepetitions;
  final int trackedDurationMicros;
  final int rejectedDurationMicros;
  final double? formScorePercent;
  final String scoringVersion;
  final String detectorId;
  final String detectorVersion;
  final String cameraView;
  final LocalWorkoutRecordStatus status;
  final String? failureCode;
  final DateTime? acceptedAt;

  int get attempts => repetitions + partialRepetitions;

  /// Measured tracked/(tracked+rejected) fraction; excludes unmeasured time.
  double? get coverage =>
      _coverage(trackedDurationMicros, rejectedDurationMicros);

  /// JSON encoding prevents collisions in labels containing separators.
  String get versionKey => jsonEncode([
        exerciseId,
        scoringVersion,
        detectorId,
        detectorVersion,
        cameraView,
      ]);
}

class WeeklyWorkoutProgress {
  const WeeklyWorkoutProgress._({
    required this.start,
    required this.end,
    required this.sessions,
    required this.repetitions,
    required this.partialRepetitions,
    required this.trackedDurationMicros,
    required this.rejectedDurationMicros,
  });

  /// UTC instants delimiting a local calendar week; [end] is exclusive.
  final DateTime start;
  final DateTime end;
  final int sessions;
  final int repetitions;
  final int partialRepetitions;
  final int trackedDurationMicros;
  final int rejectedDurationMicros;
  double? get coverage =>
      _coverage(trackedDurationMicros, rejectedDurationMicros);
}

/// Only compatible exercise/rule/detector/model/view measurements are combined.
class FormProgressSeries {
  FormProgressSeries._(List<LocalWorkoutProgressRecord> values)
      : records = List.unmodifiable(values) {
    var totalScore = 0.0;
    var scored = 0;
    var unassessed = 0;
    for (final record in records) {
      if (record.formScorePercent == null) {
        unassessed += record.attempts;
      } else {
        scored += record.attempts;
        totalScore += record.formScorePercent! * record.attempts;
      }
    }
    scoredAttempts = scored;
    unassessedAttempts = unassessed;
    meanScore = scored == 0 ? null : totalScore / scored;
  }

  final List<LocalWorkoutProgressRecord> records;
  late final double? meanScore;
  late final int scoredAttempts;
  late final int unassessedAttempts;
  String get versionKey => records.first.versionKey;
  String get exerciseId => records.first.exerciseId;
  String get scoringVersion => records.first.scoringVersion;
  String get detectorId => records.first.detectorId;
  String get detectorVersion => records.first.detectorVersion;
  String get cameraView => records.first.cameraView;
}

class MemberLocalProgress {
  MemberLocalProgress._({
    required this.scope,
    required this.asOf,
    required this.utcOffset,
    required List<LocalWorkoutProgressRecord> records,
    required List<WeeklyWorkoutProgress> weeks,
    required List<FormProgressSeries> formSeries,
  })  : records = List.unmodifiable(records),
        weeks = List.unmodifiable(weeks),
        formSeries = List.unmodifiable(formSeries);

  final SessionScope scope;
  final DateTime asOf;
  final Duration utcOffset;

  /// All eligible captures, ordered newest completion first.
  final List<LocalWorkoutProgressRecord> records;

  /// Calendar weeks ordered oldest first, including empty gaps.
  final List<WeeklyWorkoutProgress> weeks;
  final List<FormProgressSeries> formSeries;
  DateTime get weekStart => weeks.last.start;
  DateTime get weekEnd => weeks.last.end;
  int get weeklySessions => weeks.last.sessions;
  int get weeklyRepetitions => weeks.last.repetitions;
  int get weeklyPartialRepetitions => weeks.last.partialRepetitions;
  double? get weeklyCoverage => weeks.last.coverage;
  int get allTimeSessions => records.length;
  int get allTimeRepetitions =>
      records.fold(0, (sum, r) => sum + r.repetitions);
  int get allTimePartialRepetitions =>
      records.fold(0, (sum, r) => sum + r.partialRepetitions);
}

MemberLocalProgress calculateLocalMemberProgress({
  required SessionScope scope,
  required Iterable<LocalWorkoutProgressRecord> records,
  required DateTime asOf,
  Duration utcOffset = const Duration(hours: 8),
  int weekCount = 7,
}) {
  if (weekCount < 1 || utcOffset.abs() >= const Duration(days: 1)) {
    throw ArgumentError(
        'A positive week count and offset within one day are required.');
  }
  final now = asOf.toUtc();
  final bySession = <String, LocalWorkoutProgressRecord>{};
  for (final record in records) {
    if (record.scope != scope) {
      throw ArgumentError('A progress capture belongs to another account.');
    }
    final previous = bySession[record.sessionId];
    if (previous != null && !_sameRecord(previous, record)) {
      throw ArgumentError('Conflicting facts for session ${record.sessionId}.');
    }
    bySession[record.sessionId] = record;
  }
  final eligible =
      bySession.values.where((record) => !record.endedAt.isAfter(now)).toList()
        ..sort((a, b) {
          final completionOrder = b.endedAt.compareTo(a.endedAt);
          return completionOrder != 0
              ? completionOrder
              : a.sessionId.compareTo(b.sessionId);
        });

  // The shifted value is used only for calendar arithmetic. Public week bounds
  // are actual UTC instants, so membership tests never depend on host timezone.
  final calendarNow = now.add(utcOffset);
  final localMidnight = DateTime.utc(
    calendarNow.year,
    calendarNow.month,
    calendarNow.day,
  );
  final weekStart = localMidnight
      .subtract(Duration(days: calendarNow.weekday - DateTime.monday))
      .subtract(utcOffset);
  final weeks = <WeeklyWorkoutProgress>[];
  for (var index = weekCount - 1; index >= 0; index--) {
    final start = weekStart.subtract(Duration(days: index * 7));
    final end = start.add(const Duration(days: 7));
    var sessions = 0;
    var repetitions = 0;
    var partialRepetitions = 0;
    var tracked = 0;
    var rejected = 0;
    for (final record in eligible) {
      if (record.endedAt.isBefore(start) || !record.endedAt.isBefore(end)) {
        continue;
      }
      sessions++;
      repetitions += record.repetitions;
      partialRepetitions += record.partialRepetitions;
      tracked += record.trackedDurationMicros;
      rejected += record.rejectedDurationMicros;
    }
    weeks.add(WeeklyWorkoutProgress._(
      start: start,
      end: end,
      sessions: sessions,
      repetitions: repetitions,
      partialRepetitions: partialRepetitions,
      trackedDurationMicros: tracked,
      rejectedDurationMicros: rejected,
    ));
  }
  final groups = <String, List<LocalWorkoutProgressRecord>>{};
  final chronological = eligible.toList()
    ..sort((a, b) {
      final completionOrder = a.endedAt.compareTo(b.endedAt);
      return completionOrder != 0
          ? completionOrder
          : a.sessionId.compareTo(b.sessionId);
    });
  for (final record in chronological) {
    groups.putIfAbsent(record.versionKey, () => []).add(record);
  }
  return MemberLocalProgress._(
    scope: scope,
    asOf: now,
    utcOffset: utcOffset,
    records: eligible,
    weeks: weeks,
    formSeries: groups.values.map(FormProgressSeries._).toList(),
  );
}

double? _coverage(int tracked, int rejected) {
  final assessed = tracked + rejected;
  return assessed == 0 ? null : tracked / assessed;
}

bool _sameRecord(LocalWorkoutProgressRecord a, LocalWorkoutProgressRecord b) =>
    a.scope == b.scope &&
    a.sessionId == b.sessionId &&
    a.exerciseId == b.exerciseId &&
    a.startedAt == b.startedAt &&
    a.endedAt == b.endedAt &&
    a.repetitions == b.repetitions &&
    a.partialRepetitions == b.partialRepetitions &&
    a.trackedDurationMicros == b.trackedDurationMicros &&
    a.rejectedDurationMicros == b.rejectedDurationMicros &&
    a.formScorePercent == b.formScorePercent &&
    a.scoringVersion == b.scoringVersion &&
    a.detectorId == b.detectorId &&
    a.detectorVersion == b.detectorVersion &&
    a.cameraView == b.cameraView &&
    a.status == b.status &&
    a.failureCode == b.failureCode &&
    a.acceptedAt == b.acceptedAt;
