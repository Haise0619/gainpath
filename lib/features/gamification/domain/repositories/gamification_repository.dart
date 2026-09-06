import 'package:gainpath/features/gamification/domain/entities/achievement_badge.dart';
import 'package:gainpath/features/gamification/domain/entities/mini_game.dart';
import 'package:gainpath/features/gamification/domain/entities/reward_item.dart';

/// Data access contract for the gamification feature. Implemented in-memory for the
/// prototype; a Firebase implementation will sit behind the same interface.
abstract class GamificationRepository {
  int get points;
  int get streak;
  int get longestStreak;
  List<AchievementBadge> get badges;
  List<MiniGame> get miniGames;
  List<RewardItem> get rewards;
  List<List<String>> get leaderboard;
}
