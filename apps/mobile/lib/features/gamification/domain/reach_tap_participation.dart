import 'package:gainpath_domain/gamification.dart'
    show MiniGameRewardGame, MiniGameRewardPolicy;

/// Historical local proposal only, retained for compatibility. This is neither a
/// live reward status nor an issuer port.
///
/// The existing participation architecture owns points and the shared daily
/// cap. Current Reach eligibility comes from the scoped participation repository,
/// never this archived proposal or a local constant.
final class ReachTapParticipationProposal {
  const ReachTapParticipationProposal();

  static final _architecture = MiniGameRewardPolicy.draft();
  static const _gameDefaults = MiniGameRewardGame();

  String get gameId => 'reach-tap-v1';
  int get pointsPerCompletedRound => _gameDefaults.points;
  int get claimsPerGamePerDay => _gameDefaults.dailyClaimLimit;
  int get sharedDailyPointsCap => _architecture.dailyPointsCap;
  String get timezone => _architecture.timezone;
  bool get issuanceEnabled => false;
}
