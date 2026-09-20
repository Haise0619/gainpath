import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gamification.dart';

part 'gamification_event.dart';
part 'gamification_state.dart';

/// The member's points and streak (M3). One instance is shared by the home
/// dashboard and every gamification screen so both always show the same
/// balance (SD-M3.1, SD-M3.2).
class GamificationBloc extends Bloc<GamificationEvent, GamificationState> {
  GamificationBloc(this._repo) : super(GamificationState.from(_repo)) {
    on<GamificationLoaded>((_, emit) => emit(_snapshot()));
    on<DailyCheckInClaimed>(_onDailyCheckIn);
    on<MiniGameCompleted>(_onMiniGameCompleted);
  }

  final GamificationRepository _repo;

  GamificationState _snapshot({bool? checkedInToday}) => GamificationState(
        points: _repo.points,
        streak: _repo.streak,
        longestStreak: _repo.longestStreak,
        checkedInToday: checkedInToday ?? state.checkedInToday,
      );

  void _onDailyCheckIn(DailyCheckInClaimed e, Emitter<GamificationState> emit) {
    if (state.checkedInToday) return; // one claim per day
    _repo.addPoints(RewardPolicy.dailyCheckIn);
    _repo.extendStreak();
    emit(_snapshot(checkedInToday: true));
  }

  void _onMiniGameCompleted(MiniGameCompleted e, Emitter<GamificationState> emit) {
    _repo.addPoints(RewardPolicy.pointsForMiniGameScore(e.score));
    emit(_snapshot());
  }
}
