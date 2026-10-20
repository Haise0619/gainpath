import 'dart:async';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

class FakeProfileGateway implements FitnessProfileGateway {
  final records = <SessionScope, Map<String, Object?>>{};
  bool failRead = false;
  bool failWrite = false;
  int writes = 0;
  Completer<void>? pendingWrite;
  void Function()? afterWrite;

  FitnessProfileRepository repository(SessionScope scope) =>
      _SeedableProfileRepository(
          FirebaseFitnessProfileRepository(scope: scope, gateway: this));

  @override
  Future<Map<String, Object?>?> read(SessionScope scope) async {
    if (failRead) {
      throw const FitnessProfileException('Could not load profile.');
    }
    return records[scope];
  }

  @override
  Future<void> write(SessionScope scope, Map<String, Object?> data,
      {required Map<String, Object?>? expectedSnapshot}) async {
    writes++;
    if (failWrite) {
      throw const FitnessProfileException('Could not save profile. Retry.');
    }
    await pendingWrite?.future;
    if (!sameMemberDocumentValue(records[scope], expectedSnapshot)) {
      throw const FitnessProfileException('Profile changed.',
          reloadRequired: true);
    }
    records[scope] = {...?records[scope], ...data};
    if (data.containsKey('age') && data['age'] == null) {
      records[scope]!.remove('age');
    }
    afterWrite?.call();
  }
}

/// Existing tests seed a missing fixture through save before mounting the app.
/// Real app reads and writes still use the production repository and baseline.
class _SeedableProfileRepository implements FitnessProfileRepository {
  _SeedableProfileRepository(this.delegate);
  final FitnessProfileRepository delegate;
  bool _loaded = false;
  @override
  SessionScope get scope => delegate.scope;
  @override
  Future<FitnessProfile?> load() async {
    final profile = await delegate.load();
    _loaded = true;
    return profile;
  }

  @override
  Future<void> save(FitnessProfile profile) async {
    if (!_loaded) await load();
    await delegate.save(profile);
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
