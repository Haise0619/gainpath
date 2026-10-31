import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/analytics/domain/local_member_progress_repository.dart';
import 'package:gainpath_mobile/features/analytics/domain/member_workout_report.dart';
import 'routine_history_ui_test.dart' as support;

final reportScope = SessionScope(userId: 'member', organizationId: 'gainpath');
LocalWorkoutProgressRecord reportRecord(String id, DateTime end,
        {String exercise = 'squat',
        int full = 5,
        int partial = 1,
        double? score = 80,
        String version = 'v1',
        LocalWorkoutRecordStatus status = LocalWorkoutRecordStatus.localOnly,
        DateTime? acceptedAt,
        SessionScope? scope}) =>
    LocalWorkoutProgressRecord(
        scope: scope ?? reportScope,
        sessionId: id,
        exerciseId: exercise,
        startedAt: end.subtract(const Duration(seconds: 30)),
        endedAt: end,
        repetitions: full,
        partialRepetitions: partial,
        trackedDurationMicros: 20000000,
        rejectedDurationMicros: 0,
        formScorePercent: score,
        scoringVersion: version,
        detectorId: 'pose',
        detectorVersion: 'model1',
        cameraView: 'side',
        status: status,
        acceptedAt: acceptedAt);
final reportNow = DateTime.utc(2026, 10, 26, 12);
MemberWorkoutReport makeReport(List<LocalWorkoutProgressRecord> records,
        {WorkoutReportFilter? filter, bool routines = true}) =>
    MemberWorkoutReport.build(
        scope: reportScope,
        source: LocalMemberProgressSnapshot(
            records: records,
            attempts: [support.attempt()],
            routineHistoryAvailable: routines),
        filter: filter ?? WorkoutReportFilter.all(),
        asOf: reportNow);

void main() {
  test('acceptance status is explicitly separate from backup', () {
    final text = makeReport([reportRecord('camera', reportNow)])
        .toDocument()
        .lines
        .join(' \n');
    expect(text, contains('Workout acceptance:'));
    expect(text, contains('not Cloud Backup status'));
  });
  test('server acceptance label requires saved acceptance metadata', () {
    for (final status in LocalWorkoutRecordStatus.values) {
      final record = reportRecord('capture', reportNow, status: status);
      expect(workoutAcceptanceLabel(record), contains('not server accepted'));
    }
    final accepted = reportRecord('accepted', reportNow,
        status: LocalWorkoutRecordStatus.accepted, acceptedAt: reportNow);
    expect(workoutAcceptanceLabel(accepted),
        'Workout acceptance: server accepted');
  });
  test(
      'filtered chronological timeline retains manual provenance and matches PDF',
      () {
    final r = makeReport([
      reportRecord('later', reportNow),
      reportRecord('camera', DateTime.utc(2026, 10, 25, 14)),
    ]);
    expect(r.timeline.map((e) => e.id), ['later', 'attempt', 'camera']);
    expect(r.timeline[0].sourceLabel, 'Measured AI capture');
    expect(r.timeline[1].detail, contains('2 self-reported sets'));
    expect(r.fullReps, 10);
    final pdf = r.toDocument().lines;
    for (final event in r.timeline) {
      expect(pdf, contains(event.documentLine));
    }
    final selected = makeReport([
      reportRecord('later', reportNow),
      reportRecord('camera', DateTime.utc(2026, 10, 25, 14)),
    ],
        filter: WorkoutReportFilter(
            startDay: DateTime.utc(2026, 10, 25),
            endDay: DateTime.utc(2026, 10, 25)));
    expect(selected.timeline.map((e) => e.id), ['attempt', 'camera']);
    expect(selected.toDocument().lines.join('\n'), isNot(contains('later')));
    expect(selected.fullReps, 5);
  });
  test('unscored measured capture stays unavailable in timeline and PDF', () {
    final r = makeReport([reportRecord('unscored', reportNow, score: null)]);
    expect(
        r.timeline.first.detail, contains('Estimated Form Score unavailable'));
    expect(r.formCharts.single.points.single.score, isNull);
    expect(r.formGroups.single.meanScore, isNull);
    expect(r.toDocument().lines.join('\n'), contains('ESTIMATED FORM SCORES'));
  });

  test('form chart preserves chronological missing captures including same day',
      () {
    final start = DateTime.utc(2026, 10, 24, 12);
    final r = makeReport([
      reportRecord('last', start.add(const Duration(days: 2)), score: 90),
      reportRecord('missing-day', start.add(const Duration(days: 1)),
          score: null),
      reportRecord('same-day-last', start.add(const Duration(hours: 2)),
          score: 80),
      reportRecord('same-day-missing', start.add(const Duration(hours: 1)),
          score: null),
      reportRecord('first', start, score: 70),
    ]);
    final points = r.formCharts.single.points;
    expect(points.map((p) => p.score), [70.0, null, 80.0, null, 90.0]);
    expect(points.map((p) => p.date).toSet(), hasLength(5));
    expect(r.formGroups.single.meanScore, 80);
    final chart = (r.toDocument().toJson()['formTrends'] as List).single as Map;
    expect((chart['points'] as List).map((p) => (p as Map)['score']),
        [70.0, null, 80.0, null, 90.0]);
  });

  test('Malaysia date includes whole end day independent of host timezone', () {
    final r = makeReport([
      reportRecord('before', DateTime.utc(2026, 10, 24, 15, 59)),
      reportRecord('start', DateTime.utc(2026, 10, 24, 16)),
      reportRecord('end', DateTime.utc(2026, 10, 25, 15, 59, 59)),
      reportRecord('after', DateTime.utc(2026, 10, 25, 16))
    ],
        filter: WorkoutReportFilter(
            startDay: DateTime.utc(2026, 10, 25),
            endDay: DateTime.utc(2026, 10, 25)));
    expect(r.sessions.map((s) => s.sessionId), ['end', 'start']);
  });
  test('linked routine sessions deduplicate; manual sets never add AI reps',
      () {
    final a = support.attempt();
    final camera = reportRecord('camera', DateTime.utc(2026, 10, 25, 15));
    final r = MemberWorkoutReport.build(
        scope: reportScope,
        source: LocalMemberProgressSnapshot(
            records: [camera, camera],
            attempts: [a, a],
            routineHistoryAvailable: true),
        filter: WorkoutReportFilter.all(),
        asOf: reportNow);
    expect(r.sessions.length, 1);
    expect(r.fullReps, 5);
    expect(r.partialReps, 1);
    expect(r.manualSets, 2);
    expect(r.completedRoutineDays, 1);
    expect(r.trackedMicros, 20000000);
  });
  test(
      'routine filter excludes standalone captures and exercise filter narrows manual sets',
      () {
    final a = support.attempt(),
        exercise = a.routine.exercises.first.exerciseId;
    final r = makeReport([
      reportRecord('camera', DateTime.utc(2026, 10, 25, 15),
          exercise: exercise),
      reportRecord('solo', DateTime.utc(2026, 10, 25, 15), exercise: exercise)
    ],
        filter:
            WorkoutReportFilter(routineId: a.routine.id, exerciseId: exercise));
    expect(r.sessions.map((s) => s.sessionId), ['camera']);
    expect(r.manualSets, 0);
    expect(r.completedRoutineDays, 1);
  });
  test('incompatible form rules remain separate and empty form is unavailable',
      () {
    final r = makeReport([
      reportRecord('a', reportNow, score: 90),
      reportRecord('b', reportNow, score: 50, version: 'v2'),
      reportRecord('c', reportNow, full: 0, partial: 0, score: null)
    ]);
    expect(r.formGroups.length, 2);
    expect(r.formGroups.map((g) => g.meanScore).toSet(), {90.0, 50.0});
    expect(
        r.formGroups.map((g) => g.scoredAttempts).reduce((a, b) => a + b), 12);
  });
  test('missing routine history is unknown rather than fabricated zero', () {
    final r = makeReport([], routines: false);
    expect(r.completedRoutineDays, isNull);
    expect(r.manualSets, isNull);
    expect(r.sessions, isEmpty);
    expect(r.toDocument().lines.join('\n'),
        contains('Routine history unavailable'));
  });
  test('foreign accounts and invalid date ranges fail closed', () {
    expect(
        () => makeReport([
              reportRecord('foreign', reportNow,
                  scope:
                      SessionScope(userId: 'other', organizationId: 'gainpath'))
            ]),
        throwsArgumentError);
    expect(
        () => WorkoutReportFilter(
            startDay: DateTime.utc(2026, 10, 27),
            endDay: DateTime.utc(2026, 10, 26)),
        throwsArgumentError);
  });
  test(
      'export contains current filters and every row without silent truncation',
      () {
    final rows = List.generate(
        65, (i) => reportRecord('session$i', DateTime.utc(2026, 10, 25, 12)));
    final r =
        makeReport(rows, filter: WorkoutReportFilter(exerciseId: 'squat'));
    final d = r.toDocument(), text = d.lines.join('\n');
    expect(text, contains('Exercise: Squat'));
    expect(text, contains('65 camera sessions'));
    for (var i = 0; i < 65; i++) {
      expect(text, contains('session$i'));
    }
    expect(d.repTrend.single.fullReps, 325);
    expect(text, contains('Provisional'));
    expect(text, contains('Self-reported'));
  });
}
