import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_mobile/features/workout/domain/guided_timed_progress.dart';

void main() {
  test('bounded truthful progress round trip', () {
    final p = GuidedTimedProgress(
        runId: 'run',
        entryId: 'entry',
        entryIndex: 0,
        exerciseId: 'exercise',
        prescription:
            TimedPrescription(sets: 3, durationSeconds: 45, restSeconds: 0),
        mediaIdentity: 'video@1',
        updatedAt: DateTime.utc(2026));
    expect(GuidedTimedProgress.fromJson(p.toJson()).toJson(), p.toJson());
    expect(p.toJson().containsKey('repetitions'), false);
    expect(() => p.copyWith(completedSetActiveMicroseconds: [1]),
        throwsFormatException);
  });
  test(
      'rejects invented chronology, oversized rest and nested measurement fields',
      () {
    GuidedTimedProgress base() => GuidedTimedProgress(
        runId: 'r',
        entryId: 'e',
        entryIndex: 0,
        exerciseId: 'x',
        prescription:
            TimedPrescription(sets: 1, durationSeconds: 45, restSeconds: 0),
        mediaIdentity: 'v',
        updatedAt: DateTime.utc(2026));
    expect(() => base().copyWith(currentSetActiveMicroseconds: 1),
        throwsFormatException);
    final json = base().toJson();
    (json['prescription'] as Map)['reps'] = 8;
    expect(() => GuidedTimedProgress.fromJson(json), throwsFormatException);
    expect(
        () => base().copyWith(
            completedSetActiveMicroseconds: [45000000],
            phase: GuidedTimedPhase.completed),
        throwsFormatException);
  });
}
