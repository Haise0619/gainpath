import 'dart:math';

enum MoveCatchPhase {
  calibrating,
  ready,
  countdown,
  playing,
  paused,
  trackingLost,
  finished
}

enum MoveCatchObjectKind { star, obstacle }

class MoveCatchObject {
  const MoveCatchObject(
      {required this.id, required this.x, required this.y, required this.kind});
  final int id;
  final double x, y;
  final MoveCatchObjectKind kind;
}

/// A local game clock and collision model. No pose/workout counts or rewards.
/// The caller supplies normalized, already mirrored torso observations.
class MoveCatchEngine {
  static const catchY = .84, catchHalfWidth = .10;
  static const trackingGraceMicros = 3000000;
  MoveCatchEngine({Random? random, this.durationMicros = 40000000})
      : _random = random ?? Random() {
    if (durationMicros <= 0) {
      throw ArgumentError.value(durationMicros, 'durationMicros');
    }
  }

  static const _frameAgeMicros = 250000, _lossMicros = 500000;
  static const _calibrationMicros = 1200000, _countdownMicros = 3000000;
  static const _spawnIntervalMicros = 700000;
  final Random _random;
  final int durationMicros;
  MoveCatchPhase _phase = MoveCatchPhase.calibrating;
  int _score = 0, _caught = 0, _obstaclesHit = 0, _missed = 0;
  int _now = 0, _captureWatermark = -1, _activeMicros = 0;
  int? _lastTick, _lastPoseCapture, _calibrationCapture;
  int _stableMicros = 0, _unstableMicros = 0;
  int _countdownRemaining = 0, _spawnMicros = 0, _nextObjectId = 0;
  double _baselineX = .5, _baselineWidth = .3, _playerX = .5;
  List<MoveCatchObject> _objects = [];

  MoveCatchPhase get phase => _phase;
  int get score => _score;
  int get caught => _caught;
  int get obstaclesHit => _obstaclesHit;
  int get missed => _missed;
  int get activeMillis => _activeMicros ~/ 1000;
  /// Optional ordered discrete-event observer; reporting never changes play.
  void Function(String type)? onScoreEvent;
  void _reportScoreEvent(String type) {
    try { onScoreEvent?.call(type); } catch (_) { /* Reporting is optional. */ }
  }
  double get remainingSeconds =>
      max(0, durationMicros - _activeMicros) / 1000000;
  double get calibrationProgress =>
      (_stableMicros / _calibrationMicros).clamp(0.0, 1.0);
  int get countdownSeconds => _phase == MoveCatchPhase.countdown
      ? (_countdownRemaining / 1000000).ceil()
      : 0;
  double get playerX => _playerX;
  List<MoveCatchObject> get objects => List.unmodifiable(_objects);
  bool get trackingReady =>
      _lastPoseCapture != null && _now - _lastPoseCapture! <= _frameAgeMicros;
  bool get inTrackingGrace =>
      (_phase == MoveCatchPhase.playing ||
          _phase == MoveCatchPhase.countdown) &&
      _lastPoseCapture != null &&
      !trackingReady &&
      _now - _lastPoseCapture! < trackingGraceMicros;
  int get trackingGraceSeconds => inTrackingGrace
      ? ((trackingGraceMicros - (_now - _lastPoseCapture!)) / 1000000).ceil()
      : 0;

  bool _observeTime(int nowMicros) {
    if (nowMicros < 0 || nowMicros < _now) return false;
    _now = nowMicros;
    return true;
  }

  void updateTorso(
      {required double centerX,
      required double shoulderWidth,
      required int capturedAtMicros,
      required int nowMicros,
      bool fullTorso = true}) {
    if (!_observeTime(nowMicros) ||
        !centerX.isFinite ||
        !shoulderWidth.isFinite ||
        centerX < 0 ||
        centerX > 1 ||
        shoulderWidth < .04 ||
        shoulderWidth > 1 ||
        capturedAtMicros < 0 ||
        capturedAtMicros <= _captureWatermark ||
        capturedAtMicros > nowMicros ||
        nowMicros - capturedAtMicros > _frameAgeMicros ||
        (!fullTorso && _stableMicros < _calibrationMicros)) {
      return;
    }
    final previousCapture = _lastPoseCapture;
    if (previousCapture != null &&
        nowMicros - previousCapture >= trackingGraceMicros &&
        (_phase == MoveCatchPhase.playing ||
            _phase == MoveCatchPhase.countdown)) {
      _phase = MoveCatchPhase.trackingLost;
    }
    _captureWatermark = capturedAtMicros;
    _lastPoseCapture = capturedAtMicros;
    if (_phase == MoveCatchPhase.calibrating) {
      _calibrate(centerX, shoulderWidth, capturedAtMicros);
    } else if (_stableMicros >= _calibrationMicros) {
      final lean = centerX - _baselineX;
      final target = lean.abs() <= _baselineWidth * .04
          ? .5
          : (.5 + lean / (_baselineWidth * .6) * .42).clamp(.08, .92);
      // Time-based smoothing reaches 86% of a movement in 50ms. The old
      // per-frame .25 blend needed several detector frames to reach the edge.
      final delta = previousCapture == null
          ? 50000
          : (capturedAtMicros - previousCapture).clamp(1000, 100000);
      final alpha = 1 - exp(-delta / 25000);
      _playerX = (_playerX + alpha * (target - _playerX)).clamp(.08, .92);
    }
  }

  void _calibrate(double center, double width, int capture) {
    final previous = _calibrationCapture;
    _calibrationCapture = capture;
    if (previous == null || capture - previous > _lossMicros) {
      _baselineX = center;
      _baselineWidth = width;
      _stableMicros = 0;
      _unstableMicros = 0;
      return;
    }
    final dt = min(100000, capture - previous);
    final stable = (center - _baselineX).abs() <= .04 &&
        (width - _baselineWidth).abs() <= _baselineWidth * .3;
    if (stable) {
      _unstableMicros = 0;
      _stableMicros = min(_calibrationMicros, _stableMicros + dt);
      _baselineX += .1 * (center - _baselineX);
      _baselineWidth += .1 * (width - _baselineWidth);
    } else {
      // A brief dip costs a little stability; sustained movement recalibrates.
      _unstableMicros += dt;
      _stableMicros = max(0, _stableMicros - dt ~/ 2);
      if (_unstableMicros >= _frameAgeMicros) {
        _baselineX = center;
        _baselineWidth = width;
        _stableMicros = 0;
        _unstableMicros = 0;
      }
    }
    if (_stableMicros >= _calibrationMicros) {
      _phase = MoveCatchPhase.ready;
      _playerX = .5;
    }
  }

  void tick(int nowMicros) {
    if (!_observeTime(nowMicros)) return;
    final previous = _lastTick;
    _lastTick = nowMicros;
    if (_phase == MoveCatchPhase.calibrating) {
      if (_lastPoseCapture != null && _now - _lastPoseCapture! > _lossMicros) {
        _stableMicros = 0;
        _unstableMicros = 0;
        _calibrationCapture = null;
      }
      return;
    }
    if (_phase != MoveCatchPhase.playing &&
        _phase != MoveCatchPhase.countdown) {
      return;
    }
    if (_lastPoseCapture == null ||
        _now - _lastPoseCapture! >= trackingGraceMicros) {
      _phase = MoveCatchPhase.trackingLost;
      return;
    }
    if (previous == null) return;
    final elapsed = nowMicros - previous;
    if (elapsed > _frameAgeMicros) {
      _phase = MoveCatchPhase.paused;
      return;
    }
    // This local, non-reward game keeps playing briefly at the last known
    // basket position. Stale input cannot move it or extend the warning.
    if (elapsed <= 0) return;
    final dt = min(100000, elapsed);
    if (_phase == MoveCatchPhase.countdown) {
      _countdownRemaining = max(0, _countdownRemaining - dt);
      if (_countdownRemaining == 0) _phase = MoveCatchPhase.playing;
      return;
    }
    _advance(min(dt, durationMicros - _activeMicros));
  }

  void _advance(int dt) {
    _activeMicros += dt;
    final speed = .25 + .25 * (_activeMicros / durationMicros).clamp(0.0, 1.0);
    final next = <MoveCatchObject>[];
    for (final object in _objects) {
      final y = object.y + speed * dt / 1000000;
      if (object.y < catchY &&
          y >= catchY &&
          (object.x - _playerX).abs() <= catchHalfWidth) {
        if (object.kind == MoveCatchObjectKind.star) {
          _caught++;
          _score += 10;
          _reportScoreEvent('catch');
        } else {
          _obstaclesHit++;
          _score = max(0, _score - 5);
          _reportScoreEvent('obstacle');
        }
      } else if (y > 1.05) {
        if (object.kind == MoveCatchObjectKind.star) _missed++;
      } else {
        next.add(MoveCatchObject(
            id: object.id, x: object.x, y: y, kind: object.kind));
      }
    }
    _objects = next;
    _spawnMicros += dt;
    while (_spawnMicros >= _spawnIntervalMicros) {
      _spawnMicros -= _spawnIntervalMicros;
      if (_objects.length < 12) {
        final x = .08 + _random.nextDouble() * .84;
        final kind = _random.nextDouble() < .78
            ? MoveCatchObjectKind.star
            : MoveCatchObjectKind.obstacle;
        _objects.add(
            MoveCatchObject(id: _nextObjectId++, x: x, y: .03, kind: kind));
      }
    }
    if (_activeMicros >= durationMicros) {
      _phase = MoveCatchPhase.finished;
      _objects.clear();
    }
  }

  void start(int nowMicros) {
    if (!_observeTime(nowMicros) ||
        _phase != MoveCatchPhase.ready ||
        !trackingReady) {
      return;
    }
    _beginCountdown(nowMicros);
  }

  void _beginCountdown(int nowMicros) {
    _countdownRemaining = _countdownMicros;
    _lastTick = nowMicros;
    _phase = MoveCatchPhase.countdown;
  }

  void pause(int nowMicros) {
    if (!_observeTime(nowMicros) || _phase == MoveCatchPhase.finished) return;
    _phase = MoveCatchPhase.paused;
    _lastTick = nowMicros;
  }

  void resume(int nowMicros) {
    if (!_observeTime(nowMicros) ||
        (_phase != MoveCatchPhase.paused &&
            _phase != MoveCatchPhase.trackingLost) ||
        !trackingReady) {
      return;
    }
    if (_stableMicros < _calibrationMicros) {
      _phase = MoveCatchPhase.calibrating;
      _calibrationCapture = null;
      _stableMicros = 0;
      return;
    }
    _beginCountdown(nowMicros);
  }

  void restart(int nowMicros) {
    if (!_observeTime(nowMicros)) return;
    _phase = MoveCatchPhase.calibrating;
    _score = 0;
    _caught = 0;
    _obstaclesHit = 0;
    _missed = 0;
    _activeMicros = 0;
    _stableMicros = 0;
    _unstableMicros = 0;
    _countdownRemaining = 0;
    _spawnMicros = 0;
    _nextObjectId = 0;
    _lastTick = nowMicros;
    _lastPoseCapture = null;
    _calibrationCapture = null;
    _baselineX = .5;
    _baselineWidth = .3;
    _playerX = .5;
    _objects = [];
  }
}
