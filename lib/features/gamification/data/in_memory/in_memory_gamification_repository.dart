import 'package:gainpath/features/gamification/data/in_memory/gamification_seed.dart';
import 'package:gainpath/features/gamification/domain/entities/achievement_badge.dart';
import 'package:gainpath/features/gamification/domain/entities/mini_game.dart';
import 'package:gainpath/features/gamification/domain/entities/reward_item.dart';
import 'package:gainpath/features/gamification/domain/repositories/gamification_repository.dart';

/// Session-scoped in-memory [GamificationRepository] backed by [GamificationSeed].
class InMemoryGamificationRepository implements GamificationRepository {
  @override
  int get points => GamificationSeed.points;

  @override
  int get streak => GamificationSeed.streak;

  @override
  int get longestStreak => GamificationSeed.longestStreak;

  @override
  List<AchievementBadge> get badges => GamificationSeed.badges;

  @override
  List<MiniGame> get miniGames => GamificationSeed.miniGames;

  @override
  List<RewardItem> get rewards => GamificationSeed.rewards;

  @override
  List<List<String>> get leaderboard => GamificationSeed.leaderboard;

  @override
  void addPoints(int n) => GamificationSeed.points += n;

  @override
  void extendStreak() {
    GamificationSeed.streak += 1;
    if (GamificationSeed.streak > GamificationSeed.longestStreak) {
      GamificationSeed.longestStreak = GamificationSeed.streak;
    }
  }
}
