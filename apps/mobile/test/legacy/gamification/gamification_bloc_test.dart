import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/application/gamification_bloc.dart';
import 'package:gainpath_domain/gamification.dart';

class _FakeGamificationRepository implements GamificationRepository {
  @override
  int points = 100;
  @override
  int streak = 3;
  @override
  int longestStreak = 10;
  @override
  List<AchievementBadge> get badges => const [];
  @override
  List<MiniGame> get miniGames => const [];
  @override
  List<RewardItem> get rewards => const [];
  @override
  List<List<String>> get leaderboard => const [];
  @override
  void addPoints(int n) => points += n;
  @override
  void extendStreak() {
    streak += 1;
    if (streak > longestStreak) longestStreak = streak;
  }
}

void main() {
  late _FakeGamificationRepository repo;
  setUp(() => repo = _FakeGamificationRepository());

  blocTest<GamificationBloc, GamificationState>(
    'initial state mirrors the repository',
    build: () => GamificationBloc(repo),
    verify: (b) => expect(b.state, const GamificationState(points: 100, streak: 3, longestStreak: 10)),
  );

  blocTest<GamificationBloc, GamificationState>(
    'daily check-in awards the policy points and extends the streak once',
    build: () => GamificationBloc(repo),
    act: (b) => b
      ..add(const DailyCheckInClaimed())
      ..add(const DailyCheckInClaimed()),
    verify: (b) {
      expect(b.state.points, 100 + RewardPolicy.dailyCheckIn);
      expect(b.state.streak, 4);
      expect(b.state.checkedInToday, isTrue);
      expect(repo.points, b.state.points);
    },
  );

  blocTest<GamificationBloc, GamificationState>(
    'a completed mini-game adds one point per ten score',
    build: () => GamificationBloc(repo),
    act: (b) => b.add(const MiniGameCompleted(1234)),
    verify: (b) => expect(b.state.points, 100 + 123),
  );

  blocTest<GamificationBloc, GamificationState>(
    'GamificationLoaded re-reads the repository',
    build: () => GamificationBloc(repo),
    act: (b) {
      repo.points = 999;
      b.add(const GamificationLoaded());
    },
    verify: (b) => expect(b.state.points, 999),
  );
}
