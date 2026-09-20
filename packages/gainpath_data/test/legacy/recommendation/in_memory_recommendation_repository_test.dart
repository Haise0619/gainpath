import 'package:test/test.dart';
import 'package:gainpath_data/src/recommendation/in_memory/in_memory_recommendation_repository.dart';

void main() {
  test('InMemoryRecommendationRepository serves seed data', () {
    final repo = InMemoryRecommendationRepository();
    expect(repo.riskExercises, isNotEmpty);
    expect(repo.atRiskLeads, isNotEmpty);
    expect(repo.trainerLeadsPool, isNotEmpty);
    expect(repo.contentLeads, isNotEmpty);
    expect(repo.contentLeadsPool, isNotEmpty);
    expect(repo.contentGaps, isNotEmpty);
  });
}
