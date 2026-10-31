import 'dart:math';

enum ReachTapPhase {
  calibrating,
  ready,
  countdown,
  playing,
  recovering,
  paused,
  trackingLost,
  finished
}

/// Real observed joints after upright preview projection, never inferred joints.
class ReachTapSample {
  const ReachTapSample(
      {required this.leftShoulder,
      required this.rightShoulder,
      required this.leftElbow,
      required this.rightElbow,
      required this.leftHand,
      required this.rightHand,
      required this.leftHip,
      required this.rightHip,
      required this.capturedAtMicros,
      required this.boardWidth,
      required this.boardHeight,
      required this.geometryKey});
  final Point<double>? leftShoulder,
      rightShoulder,
      leftElbow,
      rightElbow,
      leftHand,
      rightHand,
      leftHip,
      rightHip;
  final int capturedAtMicros;
  final double boardWidth, boardHeight;
  final String geometryKey;
}

class ReachTapEngine {
  ReachTapEngine({Random? random}) : _random = random ?? Random();
  final Random _random;
  static const _freshMicros = 200000;
  static const _alignmentMicros = 2000000;
  static const _recoveryWindowMicros = 3000000;
  static const _returnHoldMicros = 400000;
  static const _roundMicros = 40000000;
  ReachTapPhase _phase = ReachTapPhase.calibrating;
  ReachTapPhase get phase => _phase;
  int _hits = 0, _activeMicros = 0;
  int get hits => _hits;
  int get hitSerial => _hits;
  int get activeMicros => _activeMicros;
  int get score => hits * 10;
  int get activeMillis => _activeMicros ~/ 1000;
  /// Reports only already-confirmed hits, never pose data or inferred contact.
  void Function(String type)? onScoreEvent;
  void _reportHit() {
    try { onScoreEvent?.call('hit'); } catch (_) { /* Reporting is optional. */ }
  }
  int get remainingSeconds =>
      (_roundMicros - _activeMicros + 999999) ~/ 1000000;
  double get calibrationProgress =>
      (_alignedMicros / _alignmentMicros).clamp(0, 1);
  double get recoveryProgress =>
      (_recoveryMicros / _returnHoldMicros).clamp(0, 1);
  int get countdownSeconds => _phase == ReachTapPhase.countdown
      ? ((3000000 - _countdownMicros + 999999) ~/ 1000000).clamp(1, 3)
      : 0;
  bool get trackingReady =>
      _phase == ReachTapPhase.ready ||
      _phase == ReachTapPhase.countdown ||
      _phase == ReachTapPhase.playing;
  String _feedback = 'Stand still with shoulders, hips and both hands visible';
  String get feedback => _feedback;
  Point<double>? _leftHand, _rightHand, _target;
  Point<double>? get leftHand => _leftHand;
  Point<double>? get rightHand => _rightHand;
  Point<double>? get target => _target;
  double _targetRadius = .09, _cursorRadius = .035;
  double get targetRadius => _targetRadius;
  double get cursorRadius => _cursorRadius;
  int? _lastNow, _lastCapture, _activeAt, _dwellAt, _hitAt;
  int? _recoveryStarted, _returnCapture, _returnNow, _lastSampleNow;
  int _recoveryMicros = 0, _captureFloor = 0;
  int _returnHands = 0;
  int _alignedMicros = 0, _readyMicros = 0, _countdownMicros = 0;
  int? _dwellArm;
  ReachTapSample? _anchor, _previous;
  double _leftReach = 0, _rightReach = 0;
  int _nextTargetRegion = 0;

  double _distance(Point<double> a, Point<double> b, ReachTapSample s) => sqrt(
      pow((a.x - b.x) * s.boardWidth, 2) + pow((a.y - b.y) * s.boardHeight, 2));
  double _short(ReachTapSample s) => min(s.boardWidth, s.boardHeight);
  Point<double> _center(Point<double> l, Point<double> r) =>
      Point((l.x + r.x) / 2, (l.y + r.y) / 2);
  List<Point<double>?> _joints(ReachTapSample s) => [
        s.leftShoulder,
        s.rightShoulder,
        s.leftElbow,
        s.rightElbow,
        s.leftHand,
        s.rightHand,
        s.leftHip,
        s.rightHip
      ];
  bool _valid(ReachTapSample s) {
    if (!s.boardWidth.isFinite ||
        !s.boardHeight.isFinite ||
        s.boardWidth <= 0 ||
        s.boardHeight <= 0 ||
        s.geometryKey.isEmpty) {
      return false;
    }
    final active =
        _phase == ReachTapPhase.playing || _phase == ReachTapPhase.recovering;
    final required = active
        ? [s.leftShoulder, s.rightShoulder, s.leftHip, s.rightHip]
        : _joints(s);
    bool malformed(Point<double>? p) =>
        p == null ||
        !p.x.isFinite ||
        !p.y.isFinite ||
        p.x < 0 ||
        p.x > 1 ||
        p.y < 0 ||
        p.y > 1;
    if (required.any(malformed) ||
        (active &&
            ((s.leftHand == null && s.rightHand == null) ||
                (s.leftHand != null && malformed(s.leftHand)) ||
                (s.rightHand != null && malformed(s.rightHand))))) {
      return false;
    }
    final short = _short(s);
    return _distance(s.leftShoulder!, s.rightShoulder!, s) >= short * .12 &&
        _distance(s.leftShoulder!, s.leftHip!, s) >= short * .18 &&
        _distance(s.rightShoulder!, s.rightHip!, s) >= short * .18 &&
        s.leftHip!.y > s.leftShoulder!.y &&
        s.rightHip!.y > s.rightShoulder!.y &&
        // A visible hand may project over its elbow while reaching. The setup
        // lengths establish reach; active projection must not fabricate loss.
        (active ||
            (_frontFacing(s) &&
                _distance(s.leftShoulder!, s.leftElbow!, s) > short * .055 &&
                _distance(s.rightShoulder!, s.rightElbow!, s) > short * .055 &&
                _distance(s.leftElbow!, s.leftHand!, s) > short * .035 &&
                _distance(s.rightElbow!, s.rightHand!, s) > short * .035));
  }

  bool _frontFacing(ReachTapSample s) =>
      (s.rightShoulder!.x - s.leftShoulder!.x).abs() * s.boardWidth >=
          _short(s) * .10 &&
      (s.rightHip!.x - s.leftHip!.x).abs() * s.boardWidth >= _short(s) * .06 &&
      (s.rightShoulder!.x - s.leftShoulder!.x) *
              (s.rightHip!.x - s.leftHip!.x) >
          0 &&
      _distance(_center(s.leftShoulder!, s.rightShoulder!),
              _center(s.leftHip!, s.rightHip!), s) >=
          _short(s) * .18;

  bool _sameGeometry(ReachTapSample a, ReachTapSample b) =>
      a.geometryKey == b.geometryKey &&
      a.boardWidth == b.boardWidth &&
      a.boardHeight == b.boardHeight;
  bool _stable(ReachTapSample s) {
    final anchor = _anchor!;
    final a = _joints(anchor), b = _joints(s);
    final tolerance = _short(s) * .035;
    for (var i = 0; i < a.length; i++) {
      if (_distance(a[i]!, b[i]!, s) > tolerance) return false;
    }
    return true;
  }

  /// Fixed setup proportions constrain view/scale, not a standing position.
  /// Translation is gameplay: side steps and jumps must not invalidate real
  /// hands. Never adapt the reference proportions to accumulating scale/turn.
  String? _bodyProblem(ReachTapSample s) {
    final a = _anchor!;
    if (!_frontFacing(a)) {
      return 'Face the camera. Align to continue automatically';
    }
    final hips = _center(s.leftHip!, s.rightHip!);
    final anchorHips = _center(a.leftHip!, a.rightHip!);
    final shoulders = _center(s.leftShoulder!, s.rightShoulder!);
    final anchorShoulders = _center(a.leftShoulder!, a.rightShoulder!);
    final torso = _distance(anchorShoulders, anchorHips, s);
    final torsoRatio = _distance(shoulders, hips, s) / torso;
    final hipRatio = _distance(s.leftHip!, s.rightHip!, s) /
        _distance(a.leftHip!, a.rightHip!, s);
    if (!torsoRatio.isFinite ||
        !hipRatio.isFinite ||
        torsoRatio < .78 ||
        torsoRatio > 1.25 ||
        hipRatio < .75 ||
        hipRatio > 1.30) {
      return 'Camera distance changed. Align to continue automatically';
    }
    final shoulderRatio = _distance(s.leftShoulder!, s.rightShoulder!, s) /
        _distance(a.leftShoulder!, a.rightShoulder!, s);
    // Signed horizontal spans also reject a collapsed/turned or swapped view.
    if (!shoulderRatio.isFinite ||
        shoulderRatio < .60 ||
        shoulderRatio > 1.55 ||
        (s.rightShoulder!.x - s.leftShoulder!.x) /
                (a.rightShoulder!.x - a.leftShoulder!.x) <
            .55 ||
        (s.rightHip!.x - s.leftHip!.x) / (a.rightHip!.x - a.leftHip!.x) < .65) {
      return 'Face the camera. Align to continue automatically';
    }
    final angle = atan2((shoulders.x - hips.x) * s.boardWidth,
        (hips.y - shoulders.y) * s.boardHeight);
    final anchorAngle = atan2((anchorShoulders.x - anchorHips.x) * s.boardWidth,
        (anchorHips.y - anchorShoulders.y) * s.boardHeight);
    if ((angle - anchorAngle).abs() > pi / 9) {
      return 'Keep your torso upright. Align to continue automatically';
    }
    return null;
  }

  String get _reachFeedback => _leftHand == null
      ? 'Right hand visible · reach to the target'
      : _rightHand == null
          ? 'Left hand visible · reach to the target'
          : 'Reach a hand to the target';

  bool _clock(int now) {
    if (now < 0 || (_lastNow != null && now < _lastNow!)) {
      _lose('Clock changed. Show both hands to align again',
          now: _lastNow ?? 0);
      return false;
    }
    if (_lastNow != null &&
        now - _lastNow! > _freshMicros &&
        _phase != ReachTapPhase.paused &&
        _phase != ReachTapPhase.trackingLost &&
        _phase != ReachTapPhase.finished) {
      _interrupt('Camera frames interrupted', now,
          boundary: min(_lastNow!, _lastCapture ?? _lastNow!) + _freshMicros);
    }
    _lastNow = now;
    return true;
  }

  void _clearDwell() {
    _dwellAt = null;
    _dwellArm = null;
  }

  void _clearReturn() {
    _returnCapture = null;
    _returnNow = null;
    _recoveryMicros = 0;
    _returnHands = 0;
    _leftHand = null;
    _rightHand = null;
    _clearDwell();
  }

  void _interrupt(String reason, int now, {int? boundary}) {
    final startingLoss = _phase == ReachTapPhase.playing;
    final interruptingReturn = _returnCapture != null;
    if (_phase == ReachTapPhase.playing) {
      _phase = ReachTapPhase.recovering;
      _recoveryStarted = boundary ?? now;
      _activeAt = null;
    }
    if (_phase == ReachTapPhase.recovering) {
      // Establish a new watermark only when play or an observed return is
      // interrupted. Rejected frames must not chase normally delayed captures.
      if (startingLoss || interruptingReturn) {
        _captureFloor = max(_captureFloor, now);
      }
      _clearReturn();
      _feedback = '$reason · score and timer paused';
      _expireRecovery(now);
      return;
    }
    _lose(reason, now: now);
  }

  void _expireRecovery(int now) {
    if (_phase == ReachTapPhase.recovering &&
        now - _recoveryStarted! >= _recoveryWindowMicros) {
      _lose('Show both hands and align to continue automatically', now: now);
    }
  }

  void _lose(String reason, {required int now}) {
    if (_phase == ReachTapPhase.finished || _phase == ReachTapPhase.paused) {
      return;
    }
    if (_phase == ReachTapPhase.calibrating) {
      if (_lastCapture != null) _captureFloor = max(_captureFloor, now);
      _resetAlignment();
      _feedback = reason;
      return;
    }
    if (_phase != ReachTapPhase.trackingLost) {
      _captureFloor = max(_captureFloor, now);
    }
    _phase = ReachTapPhase.trackingLost;
    _recoveryStarted = null;
    _clearReturn();
    _feedback = reason;
    _leftHand = null;
    _rightHand = null;
    _target = null;
    _activeAt = null;
    _alignedMicros = 0;
    _readyMicros = 0;
    _countdownMicros = 0;
    _clearDwell();
  }

  void update(ReachTapSample sample, {required int nowMicros}) {
    if (!_clock(nowMicros) ||
        _phase == ReachTapPhase.finished ||
        _phase == ReachTapPhase.paused) {
      return;
    }
    _expireRecovery(nowMicros);
    final capture = sample.capturedAtMicros;
    if (capture < 0 ||
        capture < _captureFloor ||
        capture > nowMicros ||
        nowMicros - capture > _freshMicros ||
        (_lastCapture != null && capture <= _lastCapture!)) {
      _interrupt('Fresh camera frames lost', nowMicros);
      return;
    }
    if (_lastCapture != null &&
        (capture - _lastCapture! > _freshMicros ||
            (_lastSampleNow != null &&
                nowMicros - _lastSampleNow! > _freshMicros)) &&
        (_phase != ReachTapPhase.recovering || _returnCapture != null)) {
      _interrupt('Fresh camera frames lost', nowMicros,
          boundary: _lastCapture! + _freshMicros);
      if (capture < _captureFloor) return;
    }
    if (!_valid(sample)) {
      _interrupt(
          _phase == ReachTapPhase.playing || _phase == ReachTapPhase.recovering
              ? 'Show shoulders, hips and at least one hand'
              : 'Keep shoulders, elbows, both hands and hips visible',
          nowMicros);
      return;
    }
    if (_phase == ReachTapPhase.trackingLost) {
      _phase = ReachTapPhase.calibrating;
      _resetAlignment();
    }
    if (_previous != null && !_sameGeometry(_previous!, sample)) {
      _lose('Camera view changed. Align to continue automatically',
          now: nowMicros);
      return;
    }
    final dt = _lastCapture == null ? 0 : capture - _lastCapture!;
    _lastCapture = capture;
    _lastSampleNow = nowMicros;
    _previous = sample;
    Point<double> smooth(Point<double>? old, Point<double> raw) {
      if (old == null) return raw;
      // Suppress tiny jitter, but do not add a fixed filter backlog to fast
      // observed motion. Interpolation stays inside the two real positions;
      // there is no extrapolation or timer-driven synthetic wrist update.
      final motion = _distance(old, raw, sample) / _short(sample);
      final response = ((motion - .004) / .036).clamp(0.0, 1.0);
      final alpha = max(1 - exp(-dt / 35000), response);
      if (alpha == 1) return raw;
      return Point(
          old.x + (raw.x - old.x) * alpha, old.y + (raw.y - old.y) * alpha);
    }

    if ((sample.leftHand == null && _dwellArm == 0) ||
        (sample.rightHand == null && _dwellArm == 1)) {
      _clearDwell();
    }
    _leftHand =
        sample.leftHand == null ? null : smooth(_leftHand, sample.leftHand!);
    _rightHand =
        sample.rightHand == null ? null : smooth(_rightHand, sample.rightHand!);
    if (_phase == ReachTapPhase.recovering) {
      final bodyProblem = _bodyProblem(sample);
      if (bodyProblem != null) {
        _lose(bodyProblem, now: nowMicros);
        return;
      }
      final hands = (sample.leftHand == null ? 0 : 1) |
          (sample.rightHand == null ? 0 : 2);
      if (_returnCapture == null || (_returnHands & hands) == 0) {
        _returnCapture = capture;
        _returnNow = nowMicros;
        _returnHands = hands;
        _clearDwell();
      } else {
        _returnHands &= hands;
      }
      // Count only the continuously observed return interval in both clocks.
      // The first returning frame and the completion frame never score.
      _recoveryMicros = min(capture - _returnCapture!, nowMicros - _returnNow!);
      _feedback = 'Hold the visible hand steady · score and timer paused';
      if (_recoveryMicros >= _returnHoldMicros) {
        _phase = ReachTapPhase.playing;
        _recoveryStarted = null;
        _recoveryMicros = 0;
        _returnCapture = null;
        _returnNow = null;
        _returnHands = 0;
        _activeAt = nowMicros;
        _clearDwell();
        _feedback = _reachFeedback;
      }
      return;
    }
    if (_phase == ReachTapPhase.calibrating ||
        _phase == ReachTapPhase.ready ||
        _phase == ReachTapPhase.countdown) {
      if (_anchor == null || !_stable(sample)) {
        _anchor = sample;
        _alignedMicros = 0;
        _readyMicros = 0;
        _countdownMicros = 0;
        _phase = ReachTapPhase.calibrating;
        _feedback = 'Stand still with shoulders, hips and both hands visible';
        return;
      }
      if (_phase == ReachTapPhase.calibrating) {
        _alignedMicros += dt;
        if (_alignedMicros >= _alignmentMicros) {
          _phase = ReachTapPhase.ready;
          _feedback = 'Ready';
          _leftReach =
              (_distance(sample.leftShoulder!, sample.leftElbow!, sample) +
                      _distance(sample.leftElbow!, sample.leftHand!, sample)) *
                  .90;
          _rightReach = (_distance(
                      sample.rightShoulder!, sample.rightElbow!, sample) +
                  _distance(sample.rightElbow!, sample.rightHand!, sample)) *
              .90;
          // Keep a usable target in smaller calibrated reach regions while
          // preserving a common physical radius for the board and collision.
          final reach = min(_leftReach, _rightReach) / _short(sample);
          _targetRadius = min(.09, reach * .27);
          // Keep the original hand-cursor calibration independent of the
          // expanded target region; only the target circle becomes larger.
          _cursorRadius = min(.035, reach * .72 / .90 * .12);
        }
      } else if (_phase == ReachTapPhase.ready) {
        _readyMicros += dt;
        if (_readyMicros >= 300000) {
          _phase = ReachTapPhase.countdown;
          _feedback = 'Get ready';
        }
      } else {
        _countdownMicros += dt;
        if (_countdownMicros >= 3000000) {
          _phase = ReachTapPhase.playing;
          _feedback = 'Reach a hand to the target';
          _activeAt = nowMicros;
          _newTarget(sample);
        }
      }
      return;
    }
    final bodyProblem = _bodyProblem(sample);
    if (bodyProblem != null) {
      _lose(bodyProblem, now: nowMicros);
      return;
    }
    _feedback = _reachFeedback;
    _advance(nowMicros);
    if (_phase != ReachTapPhase.playing) return;
    if (_hitAt != null && capture - _hitAt! < 250000) {
      _clearDwell();
      return;
    }
    final radius = (targetRadius + cursorRadius) * _short(sample);
    final left = sample.leftHand != null &&
        _distance(sample.leftHand!, _target!, sample) <= radius &&
        _distance(_leftHand!, _target!, sample) <= radius;
    final right = sample.rightHand != null &&
        _distance(sample.rightHand!, _target!, sample) <= radius &&
        _distance(_rightHand!, _target!, sample) <= radius;
    final arm = left
        ? 0
        : right
            ? 1
            : null;
    if (arm == null) {
      _clearDwell();
      return;
    }
    if (_dwellArm != arm) {
      _dwellArm = arm;
      _dwellAt = capture;
      return;
    }
    if (capture - _dwellAt! >= 100000) {
      _hits++;
      _reportHit();
      _hitAt = capture;
      _clearDwell();
      _newTarget(sample);
    }
  }

  void _newTarget(ReachTapSample s) {
    final previous = _target;
    final short = _short(s), r = targetRadius * _short(s);
    final anchor = _anchor!;
    final torso = _distance(
        _center(anchor.leftShoulder!, anchor.rightShoulder!),
        _center(anchor.leftHip!, anchor.rightHip!),
        s);
    // Fixed play area includes side steps and upward/downward body movement.
    // Bound offsets by torso size and visible torso margins, not live motion:
    // targets stay still when the player moves, including jumping/landing.
    final side = min(short * .32, torso * .50);
    final torsoPoints = [
      anchor.leftShoulder!,
      anchor.rightShoulder!,
      anchor.leftHip!,
      anchor.rightHip!
    ];
    final stepLeft = min(
        side,
        max(
            0.0,
            torsoPoints.map((p) => p.x * s.boardWidth).reduce(min) -
                short * .02));
    final stepRight = min(
        side,
        max(
            0.0,
            s.boardWidth -
                torsoPoints.map((p) => p.x * s.boardWidth).reduce(max) -
                short * .02));
    final up = min(
        min(short * .35, torso * .55),
        max(
            0.0,
            min(anchor.leftShoulder!.y, anchor.rightShoulder!.y) *
                    s.boardHeight -
                short * .12));
    final down = min(
        min(short * .40, torso * .55),
        max(
            0.0,
            s.boardHeight -
                max(anchor.leftHip!.y, anchor.rightHip!.y) * s.boardHeight -
                short * .12));
    bool withinMotionReach(
        Point<double> p, Point<double> shoulder, double reach) {
      final x = (p.x * s.boardWidth).clamp(shoulder.x * s.boardWidth - stepLeft,
          shoulder.x * s.boardWidth + stepRight);
      final y = (p.y * s.boardHeight).clamp(
          shoulder.y * s.boardHeight - up, shoulder.y * s.boardHeight + down);
      return sqrt(pow(p.x * s.boardWidth - x, 2) +
                  pow(p.y * s.boardHeight - y, 2)) +
              r <=
          reach;
    }

    bool allowed(Point<double> p) {
      if (p.x * s.boardWidth < r + short * .02 ||
          p.x * s.boardWidth > s.boardWidth - r - short * .02 ||
          p.y * s.boardHeight < r + short * .02 ||
          p.y * s.boardHeight > s.boardHeight - r - short * .02) {
        return false;
      }
      if (p.y * s.boardHeight >
          min(anchor.leftHip!.y, anchor.rightHip!.y) * s.boardHeight + down) {
        return false;
      }
      if (!withinMotionReach(p, anchor.leftShoulder!, _leftReach) &&
          !withinMotionReach(p, anchor.rightShoulder!, _rightReach)) {
        return false;
      }
      final separation = (targetRadius + cursorRadius + .025) * short;
      if ((s.leftHand != null && _distance(p, s.leftHand!, s) < separation) ||
          (s.rightHand != null && _distance(p, s.rightHand!, s) < separation)) {
        return false;
      }
      return previous == null ||
          _distance(p, previous, s) >
              (2 * (targetRadius + cursorRadius) + .02) * short;
    }

    // Cycle distant regions across three columns and four rows rather than
    // near one shoulder. Every candidate still passes the same visible/reach,
    // current-hand and prior-target exclusion gates above.
    final padding = r + short * .02;
    final left = max(
        padding,
        min(
            anchor.leftShoulder!.x * s.boardWidth - _leftReach - stepLeft + r,
            anchor.rightShoulder!.x * s.boardWidth -
                _rightReach -
                stepLeft +
                r));
    final right = min(
        s.boardWidth - padding,
        max(
            anchor.leftShoulder!.x * s.boardWidth + _leftReach + stepRight - r,
            anchor.rightShoulder!.x * s.boardWidth +
                _rightReach +
                stepRight -
                r));
    final top = max(
        padding,
        min(anchor.leftShoulder!.y * s.boardHeight - _leftReach - up + r,
            anchor.rightShoulder!.y * s.boardHeight - _rightReach - up + r));
    final bottom = min(
        s.boardHeight - padding,
        min(
            min(anchor.leftHip!.y, anchor.rightHip!.y) * s.boardHeight + down,
            max(
                anchor.leftShoulder!.y * s.boardHeight + _leftReach + down - r,
                anchor.rightShoulder!.y * s.boardHeight +
                    _rightReach +
                    down -
                    r)));
    const order = [0, 11, 2, 9, 4, 7, 3, 8, 1, 10, 5, 6];
    if (right > left && bottom > top) {
      for (var offset = 0; offset < order.length; offset++) {
        final index = (_nextTargetRegion + offset) % order.length;
        final region = order[index], column = region % 3, row = region ~/ 3;
        for (var attempt = 0; attempt < 40; attempt++) {
          final x = _random.nextDouble();
          // Use the outer half of side cells so broad coverage is visible,
          // while the center column still supplies intermediate targets.
          final spreadX = column == 0
              ? x * .5
              : column == 2
                  ? .5 + x * .5
                  : x;
          final p = Point(
              (left + (column + spreadX) * (right - left) / 3) / s.boardWidth,
              (top + (row + _random.nextDouble()) * (bottom - top) / 4) /
                  s.boardHeight);
          if (allowed(p)) {
            _target = p;
            _nextTargetRegion = (index + 1) % order.length;
            return;
          }
        }
      }
    }
    // Deterministic fallback prevents unlucky random sampling from losing a valid board.
    for (var y = 1; y < 30; y++) {
      for (var x = 1; x < 30; x++) {
        final p = Point(x / 30, y / 30);
        if (allowed(p)) {
          _target = p;
          return;
        }
      }
    }
    _lose('No clear reachable target. Align with more arm space visible',
        now: _lastNow!);
  }

  void _advance(int now) {
    if (_phase != ReachTapPhase.playing || _activeAt == null) return;
    _activeMicros = min(_roundMicros, _activeMicros + max(0, now - _activeAt!));
    _activeAt = now;
    if (_activeMicros == _roundMicros) {
      _phase = ReachTapPhase.finished;
      _target = null;
      _clearDwell();
      _feedback = 'Round complete';
    }
  }

  void tick(int now) {
    if (!_clock(now) ||
        _phase == ReachTapPhase.paused ||
        _phase == ReachTapPhase.trackingLost ||
        _phase == ReachTapPhase.finished) {
      return;
    }
    _expireRecovery(now);
    if (_lastCapture != null && now - _lastCapture! > _freshMicros) {
      _interrupt('Fresh camera frames lost', now,
          boundary: _lastCapture! + _freshMicros);
      return;
    }
    _advance(now);
  }

  void unavailable(int now) {
    if (!_clock(now)) return;
    _interrupt('Show both hands to continue automatically', now);
  }

  void pause(int now) {
    if (_phase == ReachTapPhase.finished) return;
    // Explicit user/lifecycle pause always wins, including during acquisition
    // or after a clock gap. Validate the clock without advancing active time.
    // An invalid backward clock remains rejected by a later Resume.
    _clock(now);
    _phase = ReachTapPhase.paused;
    _recoveryStarted = null;
    _clearReturn();
    _activeAt = null;
    _target = null;
    _leftHand = null;
    _rightHand = null;
    _clearDwell();
    _feedback = 'Paused';
  }

  void resume(int now) {
    if (!_clock(now) ||
        (_phase != ReachTapPhase.paused &&
            _phase != ReachTapPhase.trackingLost)) {
      return;
    }
    _phase = ReachTapPhase.calibrating;
    _resetAlignment();
    _captureFloor = max(_captureFloor, now);
  }

  void _resetAlignment() {
    _lastCapture = null;
    _lastSampleNow = null;
    _recoveryStarted = null;
    _clearReturn();
    _anchor = null;
    _previous = null;
    _activeAt = null;
    _hitAt = null;
    _alignedMicros = 0;
    _readyMicros = 0;
    _countdownMicros = 0;
    _targetRadius = .09;
    _nextTargetRegion = 0;
    _cursorRadius = .035;
    _leftHand = null;
    _rightHand = null;
    _target = null;
    _clearDwell();
    _feedback = 'Stand still with shoulders, hips and both hands visible';
  }

  void restart(int now) {
    _lastNow = now;
    _captureFloor = max(0, now);
    _phase = ReachTapPhase.calibrating;
    _hits = 0;
    _activeMicros = 0;
    _resetAlignment();
  }
}
