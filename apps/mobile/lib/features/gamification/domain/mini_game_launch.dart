import 'package:gainpath_domain/gamification.dart';

/// Ephemeral explicit choice, never a persisted earning opt-in.
class MiniGameLaunchArguments {
  const MiniGameLaunchArguments(
      {required this.content, this.playAndEarn = false});
  final MiniGameContent content;
  final bool playAndEarn;
  static bool canEarn(MiniGameParticipation? result, String gameId) {
    if (result == null || !result.active || result.gameId != gameId) {
      return false;
    }
    final games = result.policy.games.where((g) => g.gameId == gameId);
    if (games.length != 1) return false;
    final game = games.single;
    return game.points > 0 &&
        game.dailyClaimLimit > result.claimsToday &&
        result.remainingToday >= game.points;
  }
}
