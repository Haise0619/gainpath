/// Gamification point rules (report §4.9, Gamification Points and Streak).
class RewardPolicy {
  const RewardPolicy();

  /// Points awarded for the daily attendance check-in (SD-M3.2).
  static const dailyCheckIn = 50;

  /// Points credited for a mini-game session: one point per ten score.
  static int pointsForMiniGameScore(int score) => (score / 10).round();
}
