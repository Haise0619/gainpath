import 'package:gainpath/features/recommendation/data/in_memory/recommendation_seed.dart';
import 'package:gainpath/features/recommendation/domain/entities/risk_lead.dart';
import 'package:gainpath/features/recommendation/domain/repositories/recommendation_repository.dart';

/// Session-scoped in-memory [RecommendationRepository] backed by [RecommendationSeed].
class InMemoryRecommendationRepository implements RecommendationRepository {
  @override
  List<List<String>> get riskExercises => RecommendationSeed.riskExercises;

  @override
  int get postureRiskThreshold => RecommendationSeed.postureRiskThreshold;

  @override
  set postureRiskThreshold(int v) => RecommendationSeed.postureRiskThreshold = v;

  @override
  List<RiskLead> get atRiskLeads => RecommendationSeed.atRiskLeads;

  @override
  List<RiskLead> get trainerLeadsPool => RecommendationSeed.trainerLeadsPool;

  @override
  List<RiskLead> get contentLeads => RecommendationSeed.contentLeads;

  @override
  List<RiskLead> get contentLeadsPool => RecommendationSeed.contentLeadsPool;

  @override
  List<List<String>> get contentGaps => RecommendationSeed.contentGaps;
}
