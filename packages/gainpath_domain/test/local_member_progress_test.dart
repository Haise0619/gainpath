import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:test/test.dart';

final scope = SessionScope(userId: 'member-1', organizationId: 'org-1');
final asOf = DateTime.utc(2026, 10, 13, 12);

LocalWorkoutProgressRecord record({
  String id = 'session-1',
  SessionScope? owner,
  String exercise = 'squat',
  DateTime? start,
  DateTime? end,
  int reps = 3,
  int partial = 1,
  int tracked = 3000000,
  int rejected = 1000000,
  double? score,
  String scoring = 'squat-rules-v1',
  String detector = 'pose-detector',
  String model = 'model-1',
  String view = 'front',
  LocalWorkoutRecordStatus status = LocalWorkoutRecordStatus.localOnly,
  String? failureCode,
  DateTime? acceptedAt,
}) =>
    LocalWorkoutProgressRecord(
      scope: owner ?? scope,
      sessionId: id,
      exerciseId: exercise,
      startedAt: start ?? DateTime.utc(2026, 10, 12, 0),
      endedAt: end ?? DateTime.utc(2026, 10, 12, 0, 0, 10),
      repetitions: reps,
      partialRepetitions: partial,
      trackedDurationMicros: tracked,
      rejectedDurationMicros: rejected,
      formScorePercent: score,
      scoringVersion: scoring,
      detectorId: detector,
      detectorVersion: model,
      cameraView: view,
      status: status,
      failureCode: failureCode,
      acceptedAt: acceptedAt,
    );

MemberLocalProgress progress(Iterable<LocalWorkoutProgressRecord> records,
        {DateTime? now,
        Duration offset = const Duration(hours: 8),
        int count = 7}) =>
    calculateLocalMemberProgress(
      scope: scope,
      records: records,
      asOf: now ?? asOf,
      utcOffset: offset,
      weekCount: count,
    );

void main() {
  test('empty history has zero counts, seven weeks and no assessed coverage',
      () {
    final result = progress([]);
    expect(result.scope, scope);
    expect(result.asOf, asOf);
    expect(result.utcOffset, const Duration(hours: 8));
    expect(result.weekStart, DateTime.utc(2026, 10, 11, 16));
    expect(result.weekEnd, DateTime.utc(2026, 10, 18, 16));
    expect(result.weeks, hasLength(7));
    expect(result.weeks.first.start, DateTime.utc(2026, 8, 30, 16));
    expect(result.weeks.last.end, result.weekEnd);
    expect(result.weeklySessions, 0);
    expect(result.weeklyRepetitions, 0);
    expect(result.weeklyPartialRepetitions, 0);
    expect(result.weeklyCoverage, isNull);
    expect(result.allTimeSessions, 0);
    expect(result.allTimeRepetitions, 0);
    expect(result.allTimePartialRepetitions, 0);
    expect(result.records, isEmpty);
    expect(result.formSeries, isEmpty);
  });

  test('completion at Sunday 16 UTC belongs to the new Malaysia week', () {
    final result = progress([
      record(
          id: 'before',
          start: DateTime.utc(2026, 10, 11, 15, 59),
          end: DateTime.utc(2026, 10, 11, 15, 59, 59),
          reps: 2,
          partial: 1),
      record(
          id: 'boundary',
          start: DateTime.utc(2026, 10, 11, 15, 59),
          end: DateTime.utc(2026, 10, 11, 16),
          reps: 5,
          partial: 2),
    ]);
    expect(result.weeks[result.weeks.length - 2].sessions, 1);
    expect(result.weeks[result.weeks.length - 2].repetitions, 2);
    expect(result.weeklySessions, 1);
    expect(result.weeklyRepetitions, 5);
    expect(result.weeklyPartialRepetitions, 2);
    expect(result.allTimeRepetitions, 7);
  });

  test('Monday weeks cross year boundaries without splitting January', () {
    final result = progress([
      record(
          id: 'dec',
          start: DateTime.utc(2025, 12, 31),
          end: DateTime.utc(2025, 12, 31, 0, 1)),
      record(
          id: 'jan',
          start: DateTime.utc(2026, 1, 1),
          end: DateTime.utc(2026, 1, 1, 0, 1)),
    ], now: DateTime.utc(2026, 1, 2));
    expect(result.weekStart, DateTime.utc(2025, 12, 28, 16));
    expect(result.weekEnd, DateTime.utc(2026, 1, 4, 16));
    expect(result.weeklySessions, 2);
  });

  test('calendar uses the supplied offset rather than the host timezone', () {
    final result = progress([],
        now: DateTime.utc(2026, 10, 11, 16), offset: Duration.zero, count: 2);
    expect(result.weekStart, DateTime.utc(2026, 10, 5));
    expect(result.weekEnd, DateTime.utc(2026, 10, 12));
    expect(result.weeks, hasLength(2));
  });

  test('ignores future completions and includes completion exactly at asOf',
      () {
    final result = progress([
      record(
          id: 'future', start: asOf, end: asOf.add(const Duration(minutes: 1))),
      record(
          id: 'now',
          start: asOf.subtract(const Duration(minutes: 1)),
          end: asOf),
    ]);
    expect(result.records.map((r) => r.sessionId), ['now']);
    expect(result.allTimeSessions, 1);
  });

  test('all-time totals include records older than the displayed weeks', () {
    final result = progress([
      record(
          id: 'old',
          start: DateTime.utc(2020),
          end: DateTime.utc(2020, 1, 1, 0, 1)),
      record(id: 'recent'),
    ]);
    expect(result.allTimeSessions, 2);
    expect(result.allTimeRepetitions, 6);
    expect(result.allTimePartialRepetitions, 2);
    expect(result.weeks.map((w) => w.sessions), [0, 0, 0, 0, 0, 0, 1]);
    expect(result.records.map((r) => r.sessionId), ['recent', 'old']);
  });

  test('zero-repetition saved capture counts as one session', () {
    final result = progress([record(reps: 0, partial: 0, score: 80)]);
    expect(result.weeklySessions, 1);
    expect(result.weeklyRepetitions, 0);
    expect(result.formSeries.single.meanScore, isNull);
    expect(result.formSeries.single.scoredAttempts, 0);
    expect(result.records.single.formScorePercent, isNull);
  });

  test('rejects another account or organization instead of leaking counts', () {
    for (final owner in [
      SessionScope(userId: 'member-2', organizationId: 'org-1'),
      SessionScope(userId: 'member-1', organizationId: 'org-2'),
    ]) {
      expect(() => progress([record(owner: owner)]), throwsArgumentError);
    }
  });

  test('rejects wrong-scope future records too', () {
    expect(
        () => progress([
              record(
                owner: SessionScope(userId: 'other', organizationId: 'org-1'),
                start: asOf,
                end: asOf.add(const Duration(minutes: 1)),
              )
            ]),
        throwsArgumentError);
  });

  test('identical duplicate session facts count once', () {
    final result = progress([record(), record()]);
    expect(result.records, hasLength(1));
    expect(result.weeklySessions, 1);
    expect(result.weeklyRepetitions, 3);
  });

  test('conflicting duplicate session metrics are rejected', () {
    expect(() => progress([record(), record(reps: 4)]), throwsArgumentError);
    expect(() => progress([record(), record(exercise: 'lunge')]),
        throwsArgumentError);
  });

  test('conflicting duplicate status metadata is rejected', () {
    expect(
        () => progress(
            [record(), record(status: LocalWorkoutRecordStatus.accepted)]),
        throwsArgumentError);
    expect(() => progress([record(), record(failureCode: 'receipt-mismatch')]),
        throwsArgumentError);
    expect(() => progress([record(), record(acceptedAt: asOf)]),
        throwsArgumentError);
  });

  test('statuses retain local counts without implying remote authority', () {
    final result = progress([
      for (final status in LocalWorkoutRecordStatus.values)
        record(id: status.name, status: status),
    ]);
    expect(result.weeklySessions, 6);
    expect(result.records.map((r) => r.status).toSet(),
        LocalWorkoutRecordStatus.values.toSet());
  });

  test('compatible scores average by attempts and retain unassessed counts',
      () {
    final result = progress([
      record(
          id: 'first',
          reps: 1,
          partial: 1,
          score: 50,
          start: DateTime.utc(2026, 10, 10),
          end: DateTime.utc(2026, 10, 10, 0, 1)),
      record(id: 'second', reps: 5, partial: 1, score: 90),
      record(id: 'unassessed', reps: 2, partial: 1),
    ]);
    final series = result.formSeries.single;
    expect(series.meanScore, 80);
    expect(series.scoredAttempts, 8);
    expect(series.unassessedAttempts, 3);
    expect(series.records.map((r) => r.sessionId),
        ['first', 'second', 'unassessed']);
    expect(series.exerciseId, 'squat');
    expect(series.scoringVersion, 'squat-rules-v1');
    expect(series.detectorId, 'pose-detector');
    expect(series.detectorVersion, 'model-1');
    expect(series.cameraView, 'front');
  });

  test('only null form values produce null mean rather than zero', () {
    final result = progress([record(reps: 2, partial: 3)]);
    expect(result.formSeries.single.meanScore, isNull);
    expect(result.formSeries.single.scoredAttempts, 0);
    expect(result.formSeries.single.unassessedAttempts, 5);
  });

  test('exercise, rule, detector, model and camera view each split series', () {
    final result = progress([
      record(id: 'baseline', score: 80),
      record(id: 'exercise', exercise: 'lunge', score: 10),
      record(id: 'rule', scoring: 'squat-rules-v2', score: 20),
      record(id: 'detector', detector: 'other-detector', score: 30),
      record(id: 'model', model: 'model-2', score: 40),
      record(id: 'view', view: 'side', score: 50),
    ]);
    expect(result.formSeries, hasLength(6));
    expect(result.formSeries.map((s) => s.versionKey).toSet(), hasLength(6));
    expect(result.formSeries.map((s) => s.meanScore).toSet(),
        {10, 20, 30, 40, 50, 80});
  });

  test('version keys cannot collide when identifiers contain delimiters', () {
    expect(record(scoring: 'a|b', detector: 'c').versionKey,
        isNot(record(scoring: 'a', detector: 'b|c').versionKey));
  });

  test(
      'coverage aggregates measured durations, excluding pauses and unknown time',
      () {
    final result = progress([
      record(id: 'first', tracked: 3000000, rejected: 1000000),
      record(id: 'second', tracked: 1000000, rejected: 3000000),
      record(id: 'unknown', reps: 0, partial: 0, tracked: 0, rejected: 0),
    ]);
    expect(result.records.first.attempts, 4);
    expect(result.records.first.coverage, .75);
    expect(result.weeklyCoverage, .5);
    expect(result.weeks.last.trackedDurationMicros, 4000000);
    expect(result.weeks.last.rejectedDurationMicros, 4000000);
    expect(
        record(reps: 0, partial: 0, tracked: 0, rejected: 0).coverage, isNull);
    expect(
        record(reps: 0, partial: 0, tracked: 0, rejected: 1000000).coverage, 0);
  });

  test('record timestamps normalize to UTC and lists are immutable', () {
    final localTime = DateTime(2026, 10, 12, 8);
    final result = progress([
      record(
          start: localTime,
          end: localTime.add(const Duration(minutes: 1)),
          acceptedAt: localTime)
    ]);
    expect(result.records.single.startedAt.isUtc, isTrue);
    expect(result.records.single.endedAt.isUtc, isTrue);
    expect(result.records.single.acceptedAt!.isUtc, isTrue);
    expect(result.records.single.startedAt, localTime.toUtc());
    expect(() => result.records.clear(), throwsUnsupportedError);
    expect(() => result.weeks.clear(), throwsUnsupportedError);
    expect(() => result.formSeries.clear(), throwsUnsupportedError);
    expect(
        () => result.formSeries.single.records.clear(), throwsUnsupportedError);
  });

  test('rejects incomplete zero or negative elapsed captures', () {
    final instant = DateTime.utc(2026, 10, 12);
    expect(() => record(start: instant, end: instant), throwsArgumentError);
    expect(
        () => record(
            start: instant, end: instant.subtract(const Duration(seconds: 1))),
        throwsArgumentError);
  });

  test('rejects negative counts or measured durations', () {
    expect(() => record(reps: -1), throwsArgumentError);
    expect(() => record(partial: -1), throwsArgumentError);
    expect(() => record(tracked: -1), throwsArgumentError);
    expect(() => record(rejected: -1), throwsArgumentError);
  });

  test('rejects measured durations exceeding elapsed capture time', () {
    expect(
        () => record(tracked: 9000000, rejected: 1000001), throwsArgumentError);
    expect(() => record(tracked: 10000001, rejected: 0), throwsArgumentError);
    expect(record(tracked: 9000000, rejected: 1000000).coverage, .9);
  });

  test('rejects full or partial attempts without tracked duration', () {
    expect(() => record(reps: 1, partial: 0, tracked: 0), throwsArgumentError);
    expect(() => record(reps: 0, partial: 1, tracked: 0), throwsArgumentError);
  });

  test('rejects supplied form without tracked duration', () {
    expect(() => record(reps: 0, partial: 0, tracked: 0, score: 80),
        throwsArgumentError);
  });

  test('untracked zero-attempt capture retains a saved session and null form',
      () {
    final result = progress([
      record(reps: 0, partial: 0, tracked: 0, rejected: 0),
    ]);
    expect(result.allTimeSessions, 1);
    expect(result.weeklyCoverage, isNull);
    expect(result.records.single.formScorePercent, isNull);
    expect(result.formSeries.single.meanScore, isNull);
  });

  test('rejects malformed score percentages', () {
    for (final score in [-1.0, 101.0, double.nan, double.infinity]) {
      expect(() => record(score: score), throwsArgumentError);
    }
  });

  test('rejects empty identity/version labels but permits future versions', () {
    expect(() => record(id: ' '), throwsArgumentError);
    expect(() => record(exercise: ''), throwsArgumentError);
    expect(() => record(scoring: ''), throwsArgumentError);
    expect(() => record(detector: ''), throwsArgumentError);
    expect(() => record(model: ''), throwsArgumentError);
    expect(() => record(view: ''), throwsArgumentError);
    expect(
        progress([record(scoring: 'rules-v99', model: 'model-v42')])
            .allTimeSessions,
        1);
  });

  test('rejects unsupported calendar parameters', () {
    expect(() => progress([], count: 0), throwsArgumentError);
    expect(() => progress([], count: -1), throwsArgumentError);
    expect(() => progress([], offset: const Duration(hours: 24)),
        throwsArgumentError);
  });
}
