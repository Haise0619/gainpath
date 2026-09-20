part of 'gamification_bloc.dart';

class GamificationState extends Equatable {
  const GamificationState({
    required this.points,
    required this.streak,
    required this.longestStreak,
    this.checkedInToday = false,
  });

  factory GamificationState.from(GamificationRepository repo) => GamificationState(
        points: repo.points,
        streak: repo.streak,
        longestStreak: repo.longestStreak,
      );

  final int points;
  final int streak;
  final int longestStreak;
  final bool checkedInToday;

  @override
  List<Object?> get props => [points, streak, longestStreak, checkedInToday];
}
