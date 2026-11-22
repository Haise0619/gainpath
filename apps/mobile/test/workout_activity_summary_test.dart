import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart' show WorkoutRecord;
import 'package:gainpath_mobile/features/workout/domain/workout_activity_summary.dart';

void main() {
  final testScope = SessionScope(
    userId: 'user1',
    organizationId: 'org1',
  );

  test('empty records produces zero activity with 7 default day entries', () {
    final now = DateTime(2026, 11, 14, 12, 0); // Saturday
    final summary = calculateWeeklyWorkoutActivity(now: now);

    expect(summary.workoutsCount, 0);
    expect(summary.minutesCount, 0);
    expect(summary.activeDays, 0);
    expect(summary.activeDaysText, '0 / 5');
    expect(summary.days.length, 7);
    expect(summary.days.every((d) => d.minutes == 0), isTrue);
    expect(summary.days.every((d) => !d.hasWorkout), isTrue);
    // Saturday is day index 5
    expect(summary.days[5].isToday, isTrue);
    expect(summary.days[0].isToday, isFalse);
  });

  test('calculates workouts, minutes, and active days from this week records', () {
    final now = DateTime(2026, 11, 14, 12, 0); // Saturday

    final tuesdayRecord = LocalWorkoutProgressRecord(
      scope: testScope,
      sessionId: 'sess-1',
      exerciseId: 'squat',
      startedAt: DateTime(2026, 11, 10, 10, 0), // Tuesday
      endedAt: DateTime(2026, 11, 10, 10, 30),
      repetitions: 24,
      partialRepetitions: 0,
      trackedDurationMicros: 30 * 60 * 1000 * 1000, // 30 minutes
      rejectedDurationMicros: 0,
      formScorePercent: 90,
      scoringVersion: 'v1',
      detectorId: 'd1',
      detectorVersion: 'v1',
      cameraView: 'front',
      status: LocalWorkoutRecordStatus.localOnly,
    );

    final thursdayRecord = LocalWorkoutProgressRecord(
      scope: testScope,
      sessionId: 'sess-2',
      exerciseId: 'squat',
      startedAt: DateTime(2026, 11, 12, 18, 0), // Thursday
      endedAt: DateTime(2026, 11, 12, 18, 45),
      repetitions: 32,
      partialRepetitions: 0,
      trackedDurationMicros: 45 * 60 * 1000 * 1000, // 45 minutes
      rejectedDurationMicros: 0,
      formScorePercent: 88,
      scoringVersion: 'v1',
      detectorId: 'd1',
      detectorVersion: 'v1',
      cameraView: 'front',
      status: LocalWorkoutRecordStatus.localOnly,
    );

    // Old record from previous week
    final lastWeekRecord = LocalWorkoutProgressRecord(
      scope: testScope,
      sessionId: 'sess-old',
      exerciseId: 'squat',
      startedAt: DateTime(2026, 11, 2, 10, 0),
      endedAt: DateTime(2026, 11, 2, 10, 40),
      repetitions: 20,
      partialRepetitions: 0,
      trackedDurationMicros: 40 * 60 * 1000 * 1000,
      rejectedDurationMicros: 0,
      formScorePercent: 85,
      scoringVersion: 'v1',
      detectorId: 'd1',
      detectorVersion: 'v1',
      cameraView: 'front',
      status: LocalWorkoutRecordStatus.localOnly,
    );

    final summary = calculateWeeklyWorkoutActivity(
      now: now,
      records: [tuesdayRecord, thursdayRecord, lastWeekRecord],
    );

    expect(summary.workoutsCount, 2);
    expect(summary.minutesCount, 75);
    expect(summary.activeDays, 2);
    expect(summary.activeDaysText, '2 / 5');

    // Tuesday is day index 1
    expect(summary.days[1].minutes, 30);
    expect(summary.days[1].hasWorkout, isTrue);

    // Thursday is day index 3
    expect(summary.days[3].minutes, 45);
    expect(summary.days[3].hasWorkout, isTrue);

    // Monday (index 0) has no workout
    expect(summary.days[0].minutes, 0);
    expect(summary.days[0].hasWorkout, isFalse);
  });

  test('calculates correctly from legacy WorkoutRecord history', () {
    final now = DateTime(2026, 11, 14, 12, 0); // Saturday

    final legacy = [
      WorkoutRecord('Squat', DateTime(2026, 11, 11, 9, 0), 20, 80, 25), // Wed
      WorkoutRecord('Press', DateTime(2026, 11, 13, 17, 0), 24, 85, 35), // Fri
    ];

    final summary = calculateWeeklyWorkoutActivity(
      now: now,
      legacyHistory: legacy,
    );

    expect(summary.workoutsCount, 2);
    expect(summary.minutesCount, 60);
    expect(summary.activeDays, 2);
    expect(summary.activeDaysText, '2 / 5');
    expect(summary.days[2].minutes, 25); // Wed
    expect(summary.days[4].minutes, 35); // Fri
  });
}
