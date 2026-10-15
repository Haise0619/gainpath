import 'identity.dart';

enum ProfileGender {
  female('Female'),
  male('Male'),
  unspecified('Prefer not to say');

  const ProfileGender(this.label);
  final String label;
}

enum TrainingExperience {
  beginner('Beginner'),
  intermediate('Intermediate'),
  advanced('Advanced');

  const TrainingExperience(this.label);
  final String label;
}

enum ActivityLevel {
  sedentary('Sedentary'),
  lightlyActive('Lightly active'),
  moderatelyActive('Moderately active'),
  veryActive('Very active'),
  extremelyActive('Extremely active');

  const ActivityLevel(this.label);
  final String label;
}

enum FitnessGoal {
  loseWeight('Lose weight'),
  buildMuscle('Build muscle'),
  improveEndurance('Improve endurance'),
  increaseFlexibility('Increase flexibility'),
  generalFitness('General fitness'),
  reduceStress('Reduce stress');

  const FitnessGoal(this.label);
  final String label;
}

/// Private fitness preferences. Authorization and membership fields belong to
/// the account assignment, never to this user-editable record.
class FitnessProfile {
  FitnessProfile({
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.experience,
    required this.activity,
    required Set<FitnessGoal> goals,
    this.editBaseline,
  }) : goals = Set.unmodifiable(goals) {
    if (age < 13 ||
        age > 80 ||
        heightCm < 130 ||
        heightCm > 210 ||
        weightKg < 35 ||
        weightKg > 160 ||
        goals.isEmpty) {
      throw ArgumentError(
          'Complete the profile using the supported measurement ranges.');
    }
  }

  final ProfileGender gender;
  final int age;
  final int heightCm;
  final int weightKg;
  final TrainingExperience experience;
  final ActivityLevel activity;
  final Set<FitnessGoal> goals;

  /// Opaque repository provenance; never serialized as a profile field.
  final Object? editBaseline;

  FitnessProfile copyWith({
    ProfileGender? gender,
    int? age,
    int? heightCm,
    int? weightKg,
    TrainingExperience? experience,
    ActivityLevel? activity,
    Set<FitnessGoal>? goals,
  }) =>
      FitnessProfile(
        gender: gender ?? this.gender,
        age: age ?? this.age,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        experience: experience ?? this.experience,
        activity: activity ?? this.activity,
        goals: goals ?? this.goals,
        editBaseline: editBaseline,
      );
}

/// A repository instance is permanently bound to one authenticated account.
abstract interface class FitnessProfileRepository {
  SessionScope get scope;
  Future<FitnessProfile?> load();
  Future<void> save(FitnessProfile profile);
}

class FitnessProfileException implements Exception {
  const FitnessProfileException(this.message, {this.reloadRequired = false});
  final String message;
  final bool reloadRequired;
  @override
  String toString() => message;
}
