import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:test/test.dart';

class MemoryGateway implements FitnessProfileGateway {
  final records = <SessionScope, Map<String, Object?>>{};
  @override
  Future<Map<String, Object?>?> read(SessionScope scope) async =>
      records[scope];
  @override
  Future<void> write(SessionScope scope, Map<String, Object?> data,
      {required Map<String, Object?>? expectedSnapshot}) async {
    if (!sameMemberDocumentValue(records[scope], expectedSnapshot)) {
      throw const FitnessProfileException('Conflict.', reloadRequired: true);
    }
    records[scope] = {...?records[scope], ...data};
  }
}

void main() {
  final scope = SessionScope(userId: 'a', organizationId: 'org');
  test('round trips editable fields and isolates accounts and organizations',
      () async {
    final gateway = MemoryGateway();
    final repository =
        FirebaseFitnessProfileRepository(scope: scope, gateway: gateway);
    expect(await repository.load(), isNull);
    await repository.save(FitnessProfile(
      gender: ProfileGender.unspecified,
      age: 25,
      heightCm: 165,
      weightKg: 65,
      experience: TrainingExperience.beginner,
      activity: ActivityLevel.lightlyActive,
      goals: {FitnessGoal.generalFitness, FitnessGoal.buildMuscle},
    ));
    final value = (await repository.load())!;
    expect(value.gender, ProfileGender.unspecified);
    expect(value.age, 25);
    expect(value.heightCm, 165);
    expect(value.weightKg, 65);
    expect(value.experience, TrainingExperience.beginner);
    expect(value.activity, ActivityLevel.lightlyActive);
    expect(value.goals, {FitnessGoal.generalFitness, FitnessGoal.buildMuscle});
    expect(
        gateway.records[scope]!.keys,
        unorderedEquals([
          'schemaVersion',
          'gender',
          'age',
          'heightCm',
          'weightKg',
          'experience',
          'activity',
          'goals',
        ]));
    for (final other in [
      SessionScope(userId: 'b', organizationId: 'org'),
      SessionScope(userId: 'a', organizationId: 'other')
    ]) {
      expect(
          await FirebaseFitnessProfileRepository(scope: other, gateway: gateway)
              .load(),
          isNull);
    }
  });

  test('malformed stored data is an error, never an absent profile', () async {
    final gateway = MemoryGateway();
    final repository =
        FirebaseFitnessProfileRepository(scope: scope, gateway: gateway);
    for (final data in <Map<String, Object?>>[
      {},
      {'schemaVersion': 99},
      {'schemaVersion': 1, 'gender': 'male', 'age': '25'}
    ]) {
      gateway.records[scope] = data;
      await expectLater(
          repository.load(), throwsA(isA<FitnessProfileException>()));
    }
  });

  test('rejects paths that escape the account document', () {
    expect(
        () => FirebaseFitnessProfileRepository(
              scope: SessionScope(userId: 'a/b', organizationId: 'org'),
              gateway: MemoryGateway(),
            ),
        throwsArgumentError);
  });

  test('an unbaselined profile cannot overwrite a record or create before load',
      () async {
    final gateway = MemoryGateway();
    final repository =
        FirebaseFitnessProfileRepository(scope: scope, gateway: gateway);
    final value = FitnessProfile(
        gender: ProfileGender.unspecified,
        age: 25,
        heightCm: 165,
        weightKg: 65,
        experience: TrainingExperience.beginner,
        activity: ActivityLevel.lightlyActive,
        goals: {FitnessGoal.generalFitness});
    await expectLater(
        repository.save(value), throwsA(isA<FitnessProfileException>()));
    expect(gateway.records, isEmpty);
    expect(await repository.load(), isNull);
    await repository.save(value);
    await repository.load();
    await expectLater(repository.save(value.copyWith(weightKg: 66)),
        throwsA(isA<FitnessProfileException>()));
    expect(gateway.records[scope]!['weightKg'], 65);
  });
}
