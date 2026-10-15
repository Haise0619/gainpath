import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';

FitnessProfile profile({int weight = 65}) => FitnessProfile(
      gender: ProfileGender.unspecified,
      age: 25,
      heightCm: 165,
      weightKg: weight,
      experience: TrainingExperience.beginner,
      activity: ActivityLevel.lightlyActive,
      goals: {FitnessGoal.generalFitness},
    );

class ProfileRepositoryFake implements FitnessProfileRepository {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'org');
  FitnessProfile? value;
  Completer<FitnessProfile?>? pendingLoad;
  Completer<void>? pendingSave;
  bool fail = false;
  int writes = 0;
  FitnessProfile? readBackOverride;
  bool failReadBack = false;
  @override
  Future<FitnessProfile?> load() async {
    if (writes > 0 && failReadBack) throw Exception('read-back');
    if (writes > 0 && readBackOverride != null) return readBackOverride;
    if (fail) throw Exception('network');
    return pendingLoad == null ? value : pendingLoad!.future;
  }

  @override
  Future<void> save(FitnessProfile profile) async {
    writes++;
    if (fail) throw Exception('network');
    await pendingSave?.future;
    value = profile;
  }
}

void main() {
  test('save displays authoritative read-back rather than submitted values',
      () async {
    final repository = ProfileRepositoryFake()
      ..value = profile()
      ..readBackOverride = profile(weight: 71);
    final cubit = FitnessProfileCubit(repository);
    await cubit.load();
    await cubit.save(profile(weight: 70));
    expect(cubit.state.profile!.weightKg, 71);
    await cubit.close();
  });

  test('failed read-back does not claim a submitted profile was saved',
      () async {
    final repository = ProfileRepositoryFake()..value = profile();
    final cubit = FitnessProfileCubit(repository);
    await cubit.load();
    repository.failReadBack = true;
    await expectLater(cubit.save(profile(weight: 70)),
        throwsA(isA<FitnessProfileException>()));
    expect(cubit.state.profile!.weightKg, 65);
    await expectLater(cubit.save(profile(weight: 72)),
        throwsA(isA<FitnessProfileException>()));
    expect(repository.writes, 1);
    repository.failReadBack = false;
    await cubit.load();
    expect(cubit.state.profile!.weightKg, 70);
    await cubit.close();
  });
  test('missing profile opens setup; a saved profile reloads on a new session',
      () async {
    final repository = ProfileRepositoryFake();
    final cubit = FitnessProfileCubit(repository);
    await cubit.load();
    expect(cubit.state.status, FitnessProfileStatus.missing);
    await cubit.save(profile());
    expect(cubit.state.profile!.weightKg, 65);
    await cubit.close();
    final restored = FitnessProfileCubit(repository);
    await restored.load();
    expect(restored.state.status, FitnessProfileStatus.ready);
    expect(restored.state.profile!.weightKg, 65);
    await restored.close();
  });

  test('load failure is not treated as a missing profile and can be retried',
      () async {
    final repository = ProfileRepositoryFake()..fail = true;
    final cubit = FitnessProfileCubit(repository);
    await cubit.load();
    expect(cubit.state.status, FitnessProfileStatus.loadFailure);
    repository.fail = false;
    await cubit.load();
    expect(cubit.state.status, FitnessProfileStatus.missing);
    await cubit.close();
  });

  test('failed save preserves the previous profile and permits retry',
      () async {
    final repository = ProfileRepositoryFake()..value = profile();
    final cubit = FitnessProfileCubit(repository);
    await cubit.load();
    repository.fail = true;
    await expectLater(cubit.save(profile(weight: 70)),
        throwsA(isA<FitnessProfileException>()));
    expect(cubit.state.profile!.weightKg, 65);
    repository.fail = false;
    await cubit.save(profile(weight: 70));
    expect(cubit.state.profile!.weightKg, 70);
    await cubit.close();
  });

  test('duplicate saves are rejected while a write is pending', () async {
    final repository = ProfileRepositoryFake()..pendingSave = Completer<void>();
    final cubit = FitnessProfileCubit(repository);
    await cubit.load();
    final first = cubit.save(profile());
    await expectLater(cubit.save(profile(weight: 70)),
        throwsA(isA<FitnessProfileException>()));
    expect(repository.writes, 1);
    repository.pendingSave!.complete();
    await first;
    await cubit.close();
  });

  test('late results after logout cannot repopulate closed account state',
      () async {
    final repository = ProfileRepositoryFake()
      ..pendingLoad = Completer<FitnessProfile?>();
    final cubit = FitnessProfileCubit(repository);
    final load = cubit.load();
    await cubit.close();
    repository.pendingLoad!.complete(profile());
    await load;
    expect(cubit.state.profile, isNull);
  });

  test(
      'profile rejects invalid measurements and empty goals; goals are immutable',
      () {
    expect(() => profile(weight: 0), throwsArgumentError);
    final goals = {FitnessGoal.generalFitness};
    final value = FitnessProfile(
      gender: ProfileGender.female,
      age: 25,
      heightCm: 170,
      weightKg: 65,
      experience: TrainingExperience.beginner,
      activity: ActivityLevel.sedentary,
      goals: goals,
    );
    goals.clear();
    expect(value.goals, {FitnessGoal.generalFitness});
    expect(() => value.goals.clear(), throwsUnsupportedError);
    expect(
        () => FitnessProfile(
              gender: ProfileGender.female,
              age: 25,
              heightCm: 170,
              weightKg: 65,
              experience: TrainingExperience.beginner,
              activity: ActivityLevel.sedentary,
              goals: {},
            ),
        throwsArgumentError);
  });
}
