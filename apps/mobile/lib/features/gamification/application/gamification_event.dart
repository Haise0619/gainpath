part of 'gamification_bloc.dart';

sealed class GamificationEvent extends Equatable {
  const GamificationEvent();
  @override
  List<Object?> get props => [];
}

/// Re-read points and streak from the repository.
class GamificationLoaded extends GamificationEvent {
  const GamificationLoaded();
}

/// Member tapped the daily check-in (SD-M3.2). Ignored if already claimed today.
class DailyCheckInClaimed extends GamificationEvent {
  const DailyCheckInClaimed();
}

/// A mini-game session finished with [score] (SD-M3.1).
class MiniGameCompleted extends GamificationEvent {
  const MiniGameCompleted(this.score);
  final int score;
  @override
  List<Object?> get props => [score];
}
