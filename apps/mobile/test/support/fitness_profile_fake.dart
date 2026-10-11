import 'dart:async';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

class FakeProfileGateway implements FitnessProfileGateway {
  final records = <SessionScope, Map<String, Object?>>{};
  bool failRead = false;
  bool failWrite = false;
  int writes = 0;
  Completer<void>? pendingWrite;

  FitnessProfileRepository repository(SessionScope scope) =>
      FirebaseFitnessProfileRepository(scope: scope, gateway: this);

  @override
  Future<Map<String, Object?>?> read(SessionScope scope) async {
    if (failRead) {
      throw const FitnessProfileException('Could not load profile.');
    }
    return records[scope];
  }

  @override
  Future<void> write(SessionScope scope, Map<String, Object?> data) async {
    writes++;
    if (failWrite) {
      throw const FitnessProfileException('Could not save profile. Retry.');
    }
    await pendingWrite?.future;
    records[scope] = data;
  }
}

FitnessProfile sampleProfile() => FitnessProfile(
      gender: ProfileGender.unspecified,
      age: 25,
      heightCm: 165,
      weightKg: 65,
      experience: TrainingExperience.beginner,
      activity: ActivityLevel.lightlyActive,
      goals: {FitnessGoal.generalFitness},
    );
