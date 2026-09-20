import '../entities/risk_lead.dart';

/// Data access contract for the recommendation feature. Implemented in-memory for the
/// prototype; a Firebase implementation will sit behind the same interface.
abstract class RecommendationRepository {
  List<List<String>> get riskExercises;
  int get postureRiskThreshold;
  set postureRiskThreshold(int v);
  List<RiskLead> get atRiskLeads;
  List<RiskLead> get trainerLeadsPool;
  List<RiskLead> get contentLeads;
  List<RiskLead> get contentLeadsPool;
  List<List<String>> get contentGaps;
}
