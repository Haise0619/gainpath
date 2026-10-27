import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:gainpath_domain/gamification.dart';

enum MiniGameRoundSyncState {
  idle,
  starting,
  recording,
  submitting,
  awaitingVerification,
  unavailable
}

/// Optional timing metadata reporting, independent from local game/pose work.
/// No scores, frames or movement measurements leave the device through this port.
class MiniGameRoundCoordinator extends ChangeNotifier {
  MiniGameRoundCoordinator(
      {required this.repository,
      int Function()? clockMillis,
      String Function()? requestId,
      this.requestTimeout = const Duration(seconds: 12)}) {
    final clock = Stopwatch()..start();
    _clock = clockMillis ?? () => clock.elapsedMilliseconds;
    _requestId = requestId ??
        () {
          final random = Random.secure();
          return List.generate(16,
                  (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
              .join();
        };
  }
  final MiniGameRoundRepository repository;
  final Duration requestTimeout;
  late final int Function() _clock;
  late final String Function() _requestId;
  MiniGameRoundSyncState state = MiniGameRoundSyncState.idle;
  MiniGameRound? _round;
  MiniGameRound? get completedRound =>
      _current && _round?.status == 'awaiting_verification' ? _round : null;
  Future<MiniGameRound> Function()? _pending;
  MiniGameRoundSyncState _pendingState = MiniGameRoundSyncState.starting;
  bool _busy = false, _disposed = false, _wantFinish = false, _playing = false;
  int _generation = 0, _desiredActive = 0, _lastSentAt = 0;
  bool get canRetry =>
      !_disposed &&
      repository.current &&
      !_busy &&
      _pending != null &&
      state == MiniGameRoundSyncState.unavailable;
  bool get _current => !_disposed && repository.current;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void start() {
    if (!_current || state != MiniGameRoundSyncState.idle) return;
    final request = _requestId();
    _run(() => repository.begin(requestId: request),
        MiniGameRoundSyncState.starting);
  }

  void observe({required int activeMillis, required bool playing}) {
    if (!_current ||
        state == MiniGameRoundSyncState.idle ||
        state == MiniGameRoundSyncState.awaitingVerification) {
      return;
    }
    if (activeMillis < 0 ||
        activeMillis > 40000 ||
        activeMillis < _desiredActive) {
      _fail();
      return;
    }
    _desiredActive = activeMillis;
    _playing = playing;
    if (_busy ||
        state == MiniGameRoundSyncState.unavailable ||
        _round == null) {
      return;
    }
    if (_clock() - _lastSentAt >= 2000) _checkpoint();
  }

  void _fail() {
    state = MiniGameRoundSyncState.unavailable;
    _pending = null;
    _notify();
  }

  void _checkpoint() {
    final r = _round;
    if (!_current || _busy || r == null) return;
    final active = _desiredActive,
        playing = _playing || _desiredActive > r.activeMillis;
    if (active - r.activeMillis > 5000) {
      _fail();
      return;
    }
    _run(
        () => repository.checkpoint(
            round: r,
            sequence: r.sequence + 1,
            activeMillis: active,
            playing: playing),
        _wantFinish
            ? MiniGameRoundSyncState.submitting
            : MiniGameRoundSyncState.recording);
  }

  void finish() {
    if (!_current ||
        state == MiniGameRoundSyncState.idle ||
        state == MiniGameRoundSyncState.awaitingVerification) {
      return;
    }
    _wantFinish = true;
    _desiredActive = 40000;
    _playing = true;
    if (!_busy && state != MiniGameRoundSyncState.unavailable) _complete();
  }

  void _complete() {
    final r = _round;
    if (!_current || _busy || r == null) return;
    if (r.activeMillis < 40000) {
      _checkpoint();
      return;
    }
    _run(() => repository.finish(round: r, sequence: r.sequence + 1),
        MiniGameRoundSyncState.submitting);
  }

  void retry() {
    if (!canRetry) return;
    final op = _pending!;
    _run(op, _pendingState);
  }

  void _run(
      Future<MiniGameRound> Function() operation, MiniGameRoundSyncState next) {
    if (!_current || _busy) return;
    final generation = _generation;
    _pending = operation;
    _pendingState = next;
    _busy = true;
    state = next;
    _notify();
    unawaited(() async {
      bool cleaned = false;
      void cleanStale(MiniGameRound r) {
        if (!cleaned && (!_current || generation != _generation)) {
          cleaned = true;
          _abandon(r);
        }
      }

      try {
        final future = operation();
        // Timeout does not cancel an HTTP request. Clean up a late owned
        // begin/checkpoint response if this local round has since been reset.
        unawaited(future.then<void>(cleanStale).catchError((Object _) {}));
        final r = await future.timeout(requestTimeout);
        if (!_current || generation != _generation) {
          cleanStale(r);
          return;
        }
        _round = r;
        _pending = null;
        _lastSentAt = _clock();
        state = r.status == 'awaiting_verification'
            ? MiniGameRoundSyncState.awaitingVerification
            : MiniGameRoundSyncState.recording;
      } catch (_) {
        if (_current && generation == _generation) {
          state = MiniGameRoundSyncState.unavailable;
        }
      } finally {
        if (!_disposed && generation == _generation) {
          _busy = false;
          _notify();
          if (_wantFinish && state == MiniGameRoundSyncState.recording) {
            _complete();
          }
        }
      }
    }());
  }

  void _abandon(MiniGameRound r) {
    if (!repository.current || r.status != 'open') return;
    unawaited(repository
        .abandon(round: r)
        .then<void>((_) {})
        .catchError((Object _) {}));
  }

  void reset() {
    final r = _round;
    _generation++;
    _busy = false;
    _pending = null;
    _round = null;
    _wantFinish = false;
    _desiredActive = 0;
    _playing = false;
    state = MiniGameRoundSyncState.idle;
    if (r != null) _abandon(r);
    _notify();
  }

  @override
  void dispose() {
    if (_disposed) return;
    reset();
    _disposed = true;
    super.dispose();
  }
}
