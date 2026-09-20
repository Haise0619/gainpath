import '../../fakes/mock_data_session.dart';
import 'gamification_seed.dart';
import 'package:gainpath_domain/gamification.dart';

/// Session-scoped in-memory [GamificationRepository] backed by [GamificationSeed].
class InMemoryGamificationRepository implements GamificationRepository {
  InMemoryGamificationRepository({MockDataSession? session})
      : _seed = (session ?? MockDataSession()).gamification;

  final GamificationSeed _seed;

  @override
  int get points => _seed.points;

  @override
  int get streak => _seed.streak;

  @override
  int get longestStreak => _seed.longestStreak;

  @override
  List<AchievementBadge> get badges => _seed.badges;

  @override
  List<MiniGame> get miniGames => _seed.miniGames;

  @override
  List<RewardItem> get rewards => _seed.rewards;

  @override
  List<List<String>> get leaderboard => _seed.leaderboard;

  @override
  void addPoints(int n) => _seed.points += n;

  @override
  void extendStreak() {
    _seed.streak += 1;
    if (_seed.streak > _seed.longestStreak) {
      _seed.longestStreak = _seed.streak;
    }
  }
}
