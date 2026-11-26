# MemberWorkoutReport.build

Source apps/mobile/lib/features/analytics/domain/member_workout_report.dart:330–369. Contiguous excerpt. Surrounding code omitted.

```dart
        }
      }
    }
    final filtered = calculateLocalMemberProgress(
        scope: scope, records: sessions, asOf: asOf);
    final buckets = <String, List<LocalWorkoutProgressRecord>>{};
    for (final s in sessions) {
      buckets.putIfAbsent(reportDate(s.endedAt), () => []).add(s);
    }
    final days = [
      for (final date in buckets.keys.toList()..sort())
        WorkoutReportDay(
            date,
            buckets[date]!.fold(0, (n, s) => n + s.repetitions),
            buckets[date]!.fold(0, (n, s) => n + s.partialRepetitions),
            buckets[date]!.fold(0, (n, s) => n + s.trackedDurationMicros))
    ];
    final charts = <WorkoutReportFormChart>[];
    for (final g in filtered.formSeries) {
      final records = g.records.toList()
        ..sort((a, b) {
          final order = a.endedAt.compareTo(b.endedAt);
          return order != 0 ? order : a.sessionId.compareTo(b.sessionId);
        });
      charts.add(WorkoutReportFormChart(
          workoutFormGroupLabel(g,
              exerciseNames[g.exerciseId] ?? reportExerciseLabel(g.exerciseId)),
          [
            for (final record in records)
              WorkoutReportFormPoint(
                  record.endedAt
                      .toUtc()
                      .add(workoutReportOffset)
                      .toIso8601String()
                      .substring(0, 19)
                      .replaceFirst('T', ' '),
                  record.formScorePercent,
                  key:
                      '${record.endedAt.toUtc().toIso8601String()}/${record.sessionId}')
          ]));
```

Groups full reps, partial attempts and time by date and keeps compatible form scores in separate series.
