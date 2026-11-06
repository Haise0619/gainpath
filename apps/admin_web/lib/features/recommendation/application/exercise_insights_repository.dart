import 'exercise_insights.dart';

class ExerciseInsightsUnavailable implements Exception {
  const ExerciseInsightsUnavailable();
}
abstract interface class InsightsReadOnlyPresentation {bool get readOnly;}

class ReviewedPolicyChoice {
  const ReviewedPolicyChoice(
      {required this.policyId, required this.title, required this.definition});
  final String policyId, title, definition;
}

class InsightsConfigurationOptions {
  InsightsConfigurationOptions(
      {required this.revision,
      required List<String> selectedPolicyIds,
      required List<ReviewedPolicyChoice> availablePolicies})
      : selectedPolicyIds = List.unmodifiable(selectedPolicyIds),
        availablePolicies = List.unmodifiable(availablePolicies);
  final int revision;
  final List<String> selectedPolicyIds;
  final List<ReviewedPolicyChoice> availablePolicies;
}

abstract interface class ExerciseInsightsRepository {
  String get organizationId;
  bool get isCurrent;
  bool get fixtureOnly;
  bool get enabled;
  Future<Object?> load(ExerciseInsightsQuery query);
  Future<InsightsConfigurationOptions> configuration();
  Future<int> saveConfiguration(int expectedRevision, List<String> policyIds);
}

/// Normal composition is intentionally disabled; it never recovers with sample data or touches Firebase.
class UnavailableExerciseInsightsRepository
    implements ExerciseInsightsRepository {
  const UnavailableExerciseInsightsRepository();
  @override
  String get organizationId => 'unavailable';
  @override
  bool get isCurrent => true;
  @override
  bool get fixtureOnly => false;
  @override
  bool get enabled => false;
  @override
  Future<Object?> load(ExerciseInsightsQuery query) async =>
      throw const ExerciseInsightsUnavailable();
  @override
  Future<InsightsConfigurationOptions> configuration() async =>
      throw const ExerciseInsightsUnavailable();
  @override
  Future<int> saveConfiguration(
          int expectedRevision, List<String> policyIds) async =>
      throw const ExerciseInsightsUnavailable();
}
