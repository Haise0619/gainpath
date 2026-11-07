import 'package:flutter/foundation.dart';

enum BetweenExerciseRestPhase { resting, paused, preparing, failed, cancelled }

/// A foreground-only convenience countdown. Never writes workout evidence.
class BetweenExerciseRestController extends ChangeNotifier {
  BetweenExerciseRestController(
      {required Duration duration,
      required this.monotonicNow,
      required this.canAdvance,
      required this.onReady})
      : _remaining = duration < Duration.zero ? Duration.zero : duration {
    _last = monotonicNow();
  }
  final Duration Function() monotonicNow;
  final bool Function() canAdvance;
  final Future<void> Function() onReady;
  Duration _remaining;
  late Duration _last;
  bool _disposed = false, _advancing = false;
  BetweenExerciseRestPhase phase = BetweenExerciseRestPhase.resting;
  int get remainingSeconds => (_remaining.inMicroseconds / 1000000).ceil();
  bool get paused => phase == BetweenExerciseRestPhase.paused;
  void _account() {
    final now = monotonicNow();
    final elapsed = now - _last;
    _last = now;
    if (elapsed > Duration.zero) {
      _remaining -= elapsed;
      if (_remaining < Duration.zero) _remaining = Duration.zero;
    }
  }

  void pause() {
    if (_disposed || phase != BetweenExerciseRestPhase.resting) return;
    _account();
    phase = BetweenExerciseRestPhase.paused;
    notifyListeners();
  }

  void interrupt() => pause();
  void resume() {
    if (_disposed ||
        !canAdvance() ||
        (phase != BetweenExerciseRestPhase.paused &&
            phase != BetweenExerciseRestPhase.failed)) {
      return;
    }
    _last = monotonicNow();
    phase = BetweenExerciseRestPhase.resting;
    notifyListeners();
  }

  Future<void> tick() async {
    if (_disposed || phase != BetweenExerciseRestPhase.resting) return;
    if (!canAdvance()) {
      interrupt();
      return;
    }
    final before = remainingSeconds;
    _account();
    if (before != remainingSeconds) notifyListeners();
    if (_remaining == Duration.zero) await _advance();
  }

  Future<void> skip() async {
    if (_disposed ||
        (phase != BetweenExerciseRestPhase.resting &&
            phase != BetweenExerciseRestPhase.paused &&
            phase != BetweenExerciseRestPhase.failed)) {
      return;
    }
    if (!canAdvance()) {
      interrupt();
      return;
    }
    await _advance();
  }

  Future<void> _advance() async {
    if (_disposed || _advancing || !canAdvance()) return;
    _advancing = true;
    phase = BetweenExerciseRestPhase.preparing;
    notifyListeners();
    try {
      await onReady();
    } catch (_) {
      if (!_disposed) {
        _advancing = false;
        phase = BetweenExerciseRestPhase.failed;
        notifyListeners();
      }
    }
  }

  void cancel() {
    if (_disposed) return;
    phase = BetweenExerciseRestPhase.cancelled;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
