import 'dart:async';
import 'workout_backup_coordinator.dart';

/// Foreground opportunities drain the durable local stores; notifications are
/// hints only, so a restart can rediscover work without an in-memory queue.
class WorkoutBackupScheduler {
  WorkoutBackupScheduler(
      {required this.coordinator,
      this.debounce = const Duration(milliseconds: 300),
      this.retryDelays = const [
        Duration(seconds: 5),
        Duration(seconds: 15),
        Duration(seconds: 45)
      ]}) {
    coordinator.addListener(_changed);
    _enabled = coordinator.state.enabled;
  }
  final WorkoutBackupCoordinator coordinator;
  final Duration debounce;
  final List<Duration> retryDelays;
  Timer? _timer;
  bool _disposed = false,
      _foreground = true,
      _running = false,
      _dirty = false,
      _enabled = false;
  int _retries = 0;

  /// Called after a successful local commit. Never waits for the network.
  void localChanged() => opportunity();

  /// Launch, resume and connectivity recovery may offer another bounded pass.
  void opportunity() {
    if (_disposed || !coordinator.authorized) return;
    _dirty = true;
    if (!_running && _timer == null) {
      _retries = 0;
      _schedule(debounce);
    }
  }

  void setForeground(bool value) {
    if (_disposed || _foreground == value) return;
    _foreground = value;
    if (!value) {
      _timer?.cancel();
      _timer = null;
    } else {
      opportunity();
    }
  }

  void _changed() {
    if (_disposed) return;
    final enabled = coordinator.state.enabled;
    if (!coordinator.authorized || !enabled) {
      _timer?.cancel();
      _timer = null;
    } else if (!_enabled && !_running) {
      opportunity();
    } else if (_dirty && !_running && !coordinator.busy && _timer == null) {
      _schedule(debounce);
    }
    _enabled = enabled;
  }

  void _schedule(Duration delay) {
    if (_disposed || !_foreground || !coordinator.authorized) return;
    _timer ??= Timer(delay, () {
      _timer = null;
      unawaited(_drain());
    });
  }

  Future<void> _drain() async {
    if (_disposed || !_foreground || _running || !coordinator.authorized) {
      return;
    }
    if (coordinator.busy) return; // Completion notification drains dirty work.
    _running = true;
    _dirty = false;
    var failed = false;
    try {
      await coordinator.load();
      if (_disposed ||
          !_foreground ||
          !coordinator.authorized ||
          !coordinator.state.enabled) {
        return;
      }
      await coordinator.sync();
      failed = coordinator.state.lastError != null;
    } catch (_) {
      // Local metadata/storage failures must not escape into save/report flows.
      failed = true;
    } finally {
      _running = false;
      if (!_disposed &&
          _foreground &&
          coordinator.authorized &&
          (coordinator.state.enabled || failed)) {
        if (failed) {
          if (_retries < retryDelays.length) _schedule(retryDelays[_retries++]);
        } else if (_dirty) {
          _schedule(debounce);
        }
      }
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    coordinator.removeListener(_changed);
  }
}
