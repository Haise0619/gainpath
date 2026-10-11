import 'package:gainpath_domain/gainpath_domain.dart';

/// SDK-free boundary; the mobile adapter adds a server timestamp on writes.
abstract interface class FitnessProfileGateway {
  Future<Map<String, Object?>?> read(SessionScope scope);
  Future<void> write(SessionScope scope, Map<String, Object?> data);
}

class FirebaseFitnessProfileRepository implements FitnessProfileRepository {
  FirebaseFitnessProfileRepository(
      {required this.scope, required this.gateway}) {
    for (final id in [scope.userId, scope.organizationId]) {
      if (id.contains('/') || id == '.' || id == '..') {
        throw ArgumentError('Profile ownership requires document IDs.');
      }
    }
  }

  @override
  final SessionScope scope;
  final FitnessProfileGateway gateway;

  @override
  Future<FitnessProfile?> load() async {
    final data = await gateway.read(scope);
    if (data == null) return null;
    try {
      if (data['schemaVersion'] != 1) throw const FormatException();
      final rawGoals = (data['goals'] as List).cast<String>();
      if (rawGoals.toSet().length != rawGoals.length) {
        throw const FormatException();
      }
      return FitnessProfile(
        gender: ProfileGender.values.byName(data['gender'] as String),
        age: data['age'] as int,
        heightCm: data['heightCm'] as int,
        weightKg: data['weightKg'] as int,
        experience:
            TrainingExperience.values.byName(data['experience'] as String),
        activity: ActivityLevel.values.byName(data['activity'] as String),
        goals: rawGoals.map(FitnessGoal.values.byName).toSet(),
      );
    } catch (_) {
      throw const FitnessProfileException(
          'Your saved profile could not be read. Please contact support.');
    }
  }

  @override
  Future<void> save(FitnessProfile profile) => gateway.write(scope, {
        'schemaVersion': 1,
        'gender': profile.gender.name,
        'age': profile.age,
        'heightCm': profile.heightCm,
        'weightKg': profile.weightKg,
        'experience': profile.experience.name,
        'activity': profile.activity.name,
        'goals': profile.goals.map((goal) => goal.name).toList()..sort(),
      });
}
