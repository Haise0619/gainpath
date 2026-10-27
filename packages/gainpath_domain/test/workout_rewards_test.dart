import 'package:test/test.dart';
import 'package:gainpath_domain/gamification.dart';

void main() {
  final json = {
    'schemaVersion': 1,
    'revision': 0,
    'version': 'draft-unconfigured',
    'enabled': false,
    'difficultyMultipliersEnabled': false,
    'eligibilityMode': 'verified_ai_only',
    'timezone': 'Asia/Kuala_Lumpur',
    ...const WorkoutRewardDraft().toFields()
  };
  test('draft defaults are100/day1 and no activation fields are sent', () {
    final draft = WorkoutRewardDraft.fromJson(json);
    expect(draft.points, 100);
    expect(draft.dailyClaimLimit, 1);
    expect(draft.toFields().containsKey('enabled'), false);
    expect(draft.minimumCompletionPercent, 100);
  });
  test('enabled or malformed draft data is never accepted by client', () {
    for (final patch in [
      {'enabled': true},
      {'difficultyMultipliersEnabled': true},
      {'minimumCompletionPercent': 0},
      {
        'eligibleRoutineIds': ['x', 'x']
      },
      {
        'difficultyPoints': {'Beginner': 100}
      },
      {'schemaVersion': 2}
    ]) {
      expect(() => WorkoutRewardDraft.fromJson({...json, ...patch}),
          throwsFormatException);
    }
  });
  test('parsed draft collections cannot be mutated', () {
    final draft = WorkoutRewardDraft.fromJson(json);
    expect(() => draft.eligibleRoutineIds.add('x'), throwsUnsupportedError);
    expect(
        () => draft.difficultyPoints['Beginner'] = 999, throwsUnsupportedError);
  });
}
