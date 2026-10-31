enum GuidedWorkoutStage { working, resting, complete }

/// Session-local guidance over measured cumulative full reps. This never
/// manufactures pose results or changes the analyzer's counting rules.
class GuidedWorkoutProgress {
  GuidedWorkoutProgress({
    required this.sets,
    required this.repetitions,
    int restSeconds = 60,
  }) : _restSeconds = restSeconds {
    if (sets < 1 ||
        sets > 50 ||
        repetitions < 1 ||
        repetitions > 1000 ||
        restSeconds < 0 ||
        restSeconds > 600) {
      throw ArgumentError('Invalid guided workout targets');
    }
  }

  final int sets, repetitions;
  int _restSeconds;
  int get restSeconds => _restSeconds;
  GuidedWorkoutStage stage = GuidedWorkoutStage.working;
  int completedSets = 0, _setStart = 0, _lastRepetitions = 0;
  int _remainingRestMicros = 0;
  int? _lastTick;
  bool _suspended = false;
  int get currentSet =>
      stage == GuidedWorkoutStage.complete ? sets : completedSets + 1;
  int get setRepetitions =>
      (_lastRepetitions - _setStart).clamp(0, repetitions);
  int get remainingRestSeconds => (_remainingRestMicros / 1000000).ceil();

  void setRestSeconds(int seconds) {
    if (seconds < 0 || seconds > 600) throw ArgumentError.value(seconds);
    _restSeconds = seconds;
  }

  void observe(int cumulativeRepetitions, {required int nowMicros}) {
    if (cumulativeRepetitions < _lastRepetitions) return;
    // Retain the baseline even for stray input while resting, without earning
    // another set or carrying those reps into the next set.
    _lastRepetitions = cumulativeRepetitions;
    if (stage != GuidedWorkoutStage.working || setRepetitions < repetitions) {
      return;
    }
    completedSets++;
    stage = completedSets == sets
        ? GuidedWorkoutStage.complete
        : GuidedWorkoutStage.resting;
    _remainingRestMicros = _restSeconds * 1000000;
    _lastTick = nowMicros;
  }

  void tick(int nowMicros) {
    final last = _lastTick;
    if (last != null && nowMicros < last) return;
    if (!_suspended && last != null && stage == GuidedWorkoutStage.resting) {
      _remainingRestMicros =
          (_remainingRestMicros - (nowMicros - last)).clamp(0, 600000000);
    }
    _lastTick = nowMicros;
  }

  void suspend(int nowMicros) {
    tick(nowMicros);
    _suspended = true;
  }

  void resumeClock(int nowMicros) {
    _lastTick = nowMicros;
    _suspended = false;
  }

  bool startNextSet({required int nowMicros, bool skipRest = false}) {
    tick(nowMicros);
    if (_suspended ||
        stage != GuidedWorkoutStage.resting ||
        (!skipRest && _remainingRestMicros > 0)) {
      return false;
    }
    _setStart = _lastRepetitions;
    _remainingRestMicros = 0;
    stage = GuidedWorkoutStage.working;
    return true;
  }
}
