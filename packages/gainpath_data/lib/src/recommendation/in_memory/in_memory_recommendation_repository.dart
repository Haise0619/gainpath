import '../../fakes/mock_data_session.dart';
import 'recommendation_seed.dart';
import 'package:gainpath_domain/recommendation.dart';

/// Session-scoped in-memory [RecommendationRepository] backed by [RecommendationSeed].
class InMemoryRecommendationRepository implements RecommendationRepository {
  InMemoryRecommendationRepository({MockDataSession? session})
      : _seed = (session ?? MockDataSession()).recommendation;

  final RecommendationSeed _seed;

  @override
  List<List<String>> get riskExercises => _seed.riskExercises;

  @override
  int get postureRiskThreshold => _seed.postureRiskThreshold;

  @override
  set postureRiskThreshold(int v) => _seed.postureRiskThreshold = v;

  @override
  List<RiskLead> get atRiskLeads => _seed.atRiskLeads;

  @override
  List<RiskLead> get trainerLeadsPool => _seed.trainerLeadsPool;

  @override
  List<RiskLead> get contentLeads => _seed.contentLeads;

  @override
  List<RiskLead> get contentLeadsPool => _seed.contentLeadsPool;

  @override
  List<List<String>> get contentGaps => _seed.contentGaps;
}
