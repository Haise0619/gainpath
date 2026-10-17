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

/// Age ranges for new inputs; existing exact ages remain legacy user facts.
enum AgeBracket {
  teens('13–17', 13, 17),
  youngAdult('18–24', 18, 24),
  adult('25–34', 25, 34),
  midAdult('35–44', 35, 44),
  matureAdult('45–54', 45, 54),
  olderAdult('55–64', 55, 64),
  senior('65–80', 65, 80);

  const AgeBracket(this.label, this.minimum, this.maximum);
  final String label;
  final int minimum, maximum;
  static AgeBracket fromAge(int age) => values
      .firstWhere((value) => age >= value.minimum && age <= value.maximum);
}

/// Private fitness preferences. Authorization and membership fields belong to
/// the account assignment, never to this user-editable record.
class FitnessProfile {
  FitnessProfile({
    required this.gender,
    this.age,
    this.ageBracket,
    required this.heightCm,
    required this.weightKg,
    required this.experience,
    required this.activity,
    required Set<FitnessGoal> goals,
    this.editBaseline,
  }) : goals = Set.unmodifiable(goals) {
    if ((age == null) == (ageBracket == null) ||
        (age != null && (age! < 13 || age! > 80)) ||
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
  final int? age;
  final AgeBracket? ageBracket;
  String get ageLabel => age == null ? '${ageBracket!.label} yrs' : '$age yrs';
  AgeBracket get effectiveAgeBracket => ageBracket ?? AgeBracket.fromAge(age!);
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
    AgeBracket? ageBracket,
    int? heightCm,
    int? weightKg,
    TrainingExperience? experience,
    ActivityLevel? activity,
    Set<FitnessGoal>? goals,
  }) =>
      FitnessProfile(
        gender: gender ?? this.gender,
        age: ageBracket != null ? null : age ?? this.age,
        ageBracket: age != null ? null : ageBracket ?? this.ageBracket,
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
