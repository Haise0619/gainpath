enum RepetitionPhase { ready, down }

class RepetitionUpdate {
  const RepetitionUpdate({
    required this.count,
    required this.phase,
    required this.completed,
  });

  final int count;
  final RepetitionPhase phase;
  final bool completed;
}

/// Hysteresis-based repetition counter.
///
/// [metric] must be an exercise-specific normalized movement metric. The
/// engine does not assume that one metric or threshold fits every exercise.
class RepetitionFsm {
  RepetitionFsm({
    required this.downThreshold,
    required this.upThreshold,
  })  : assert(downThreshold > upThreshold),
        assert(upThreshold >= 0),
        assert(downThreshold <= 1);

  final double downThreshold;
  final double upThreshold;
  RepetitionPhase _phase = RepetitionPhase.ready;
  int _count = 0;

  RepetitionUpdate update(double metric) {
    var completed = false;
    if (_phase == RepetitionPhase.ready && metric >= downThreshold) {
      _phase = RepetitionPhase.down;
    } else if (_phase == RepetitionPhase.down && metric <= upThreshold) {
      _phase = RepetitionPhase.ready;
      _count++;
      completed = true;
    }
    return RepetitionUpdate(count: _count, phase: _phase, completed: completed);
  }
}
