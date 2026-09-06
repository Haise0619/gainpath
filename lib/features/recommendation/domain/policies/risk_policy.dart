/// AD-M13.1 — `RiskThresholdConfig`: an exercise whose average posture
/// score falls below [thresholdPct] is High risk; within 12 points above it
/// is Moderate; otherwise Low.
class RiskPolicy {
  const RiskPolicy({this.thresholdPct = defaultThresholdPct});

  static const defaultThresholdPct = 70;
  static const moderateBandPct = 12;
  final int thresholdPct;

  String tierFor(int avgScorePct) {
    if (avgScorePct < thresholdPct) return 'High';
    if (avgScorePct < thresholdPct + moderateBandPct) return 'Moderate';
    return 'Low';
  }
}
