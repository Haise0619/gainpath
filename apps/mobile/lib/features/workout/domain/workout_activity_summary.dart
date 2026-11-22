import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/workout.dart' show WorkoutRecord;
import 'routine_attempt.dart';
import 'workout_contracts.dart';

class WorkoutActivityDay {
  const WorkoutActivityDay({
    required this.label,
    required this.date,
    required this.minutes,
    required this.isToday,
    required this.hasWorkout,
  });

  final String label;
  final DateTime date;
  final int minutes;
  final bool isToday;
  final bool hasWorkout;
}

class WorkoutActivitySummary {
  const WorkoutActivitySummary({
    required this.workoutsCount,
    required this.minutesCount,
    required this.activeDays,
    this.targetDays = 5,
    required this.days,
  });

  final int workoutsCount;
  final int minutesCount;
  final int activeDays;
  final int targetDays;
  final List<WorkoutActivityDay> days;

  String get activeDaysText => '$activeDays / $targetDays';

  static WorkoutActivitySummary empty({DateTime? now, int targetDays = 5}) {
    final current = now ?? DateTime.now();
    final localMidnight = DateTime(current.year, current.month, current.day);
    final monday = localMidnight
        .subtract(Duration(days: current.weekday - DateTime.monday));
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return WorkoutActivitySummary(
      workoutsCount: 0,
      minutesCount: 0,
      activeDays: 0,
      targetDays: targetDays,
      days: List.generate(7, (i) {
        final dayDate = monday.add(Duration(days: i));
        return WorkoutActivityDay(
          label: labels[i],
          date: dayDate,
          minutes: 0,
          isToday: dayDate.year == current.year &&
              dayDate.month == current.month &&
              dayDate.day == current.day,
          hasWorkout: false,
        );
      }),
    );
  }
}

WorkoutActivitySummary calculateWeeklyWorkoutActivity({
  required DateTime now,
  Iterable<LocalWorkoutProgressRecord> records = const [],
  Iterable<RoutineAttempt> attempts = const [],
  Iterable<WorkoutSessionSummary> summaries = const [],
  Iterable<WorkoutRecord> legacyHistory = const [],
  int targetDays = 5,
}) {
  final localNow = now.toLocal();
  final monday = DateTime(localNow.year, localNow.month, localNow.day)
      .subtract(Duration(days: localNow.weekday - DateTime.monday));
  final nextMonday = monday.add(const Duration(days: 7));

  final dailyMinutes = List<int>.filled(7, 0);
  final activeDaysSet = <int>{};
  var totalWorkouts = 0;
  final countedSessionIds = <String>{};

  // 1. Process local measured captures
  for (final record in records) {
    final recordTime = record.endedAt.toLocal();
    if (!recordTime.isBefore(monday) && recordTime.isBefore(nextMonday)) {
      final dayIndex = recordTime.weekday - 1;
      final minutes =
          (record.trackedDurationMicros / 60000000).ceil().clamp(1, 1440);
      dailyMinutes[dayIndex] += minutes;
      activeDaysSet.add(dayIndex);
      countedSessionIds.add(record.sessionId);
      totalWorkouts++;
    }
  }

  // 2. Process workout summaries (dedup with sessionId)
  for (final summary in summaries) {
    if (!countedSessionIds.contains(summary.sessionId)) {
      final summaryTime = summary.startedAt.toLocal();
      if (!summaryTime.isBefore(monday) && summaryTime.isBefore(nextMonday)) {
        final dayIndex = summaryTime.weekday - 1;
        final minutes = summary.endedAt
            .difference(summary.startedAt)
            .inMinutes
            .clamp(1, 1440);
        dailyMinutes[dayIndex] += minutes;
        activeDaysSet.add(dayIndex);
        countedSessionIds.add(summary.sessionId);
        totalWorkouts++;
      }
    }
  }

  // 3. Process completed routine attempts
  for (final attempt in attempts) {
    if (attempt.isComplete) {
      final timeMicros = attempt.finishedAtMicros ?? attempt.updatedAtMicros;
      final attemptTime =
          DateTime.fromMicrosecondsSinceEpoch(timeMicros).toLocal();
      if (!attemptTime.isBefore(monday) && attemptTime.isBefore(nextMonday)) {
        final dayIndex = attemptTime.weekday - 1;
        if (countedSessionIds.isEmpty) {
          final minutes = attempt.routine.estimatedMinutes;
          dailyMinutes[dayIndex] += minutes;
          activeDaysSet.add(dayIndex);
          totalWorkouts++;
        }
      }
    }
  }

  // 4. Process legacy prototype history
  for (final legacy in legacyHistory) {
    final legacyTime = legacy.date.toLocal();
    if (!legacyTime.isBefore(monday) && legacyTime.isBefore(nextMonday)) {
      final dayIndex = legacyTime.weekday - 1;
      dailyMinutes[dayIndex] += legacy.durationMin;
      activeDaysSet.add(dayIndex);
      totalWorkouts++;
    }
  }

  final totalMinutes = dailyMinutes.fold<int>(0, (sum, m) => sum + m);
  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  final days = List.generate(7, (i) {
    final dayDate = monday.add(Duration(days: i));
    return WorkoutActivityDay(
      label: labels[i],
      date: dayDate,
      minutes: dailyMinutes[i],
      isToday: dayDate.year == localNow.year &&
          dayDate.month == localNow.month &&
          dayDate.day == localNow.day,
      hasWorkout: dailyMinutes[i] > 0,
    );
  });

  return WorkoutActivitySummary(
    workoutsCount: totalWorkouts,
    minutesCount: totalMinutes,
    activeDays: activeDaysSet.length,
    targetDays: targetDays,
    days: days,
  );
}
