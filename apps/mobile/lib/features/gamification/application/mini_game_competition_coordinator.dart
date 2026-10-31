import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:gainpath_domain/gamification.dart';
import 'mini_game_round_coordinator.dart';

/// Optional discrete-event reporting, independent of local saving and rewards.
class MiniGameCompetitionCoordinator extends ChangeNotifier {
  MiniGameCompetitionCoordinator(
      {required this.repository, required this.timing, required this.gameId}) {
    if (!competitiveGameIds.contains(gameId) ||
        timing.repository.scope != repository.scope) {
      throw ArgumentError('Invalid competition scope or game.');
    }
    timing.addListener(_timingChanged);
  }
  final MiniGameCompetitionRepository repository;
  final MiniGameRoundCoordinator timing;
  final String gameId;
  MiniGameCompetitionPreference? preference;
  MiniGameAcceptedScore? receipt;
  bool loadingPreference = false,
      preferenceFailed = false,
      submitting = false,
      submissionFailed = false;
  bool _disposed = false,
      _started = false,
      _eligible = false,
      _finished = false,
      _badEvents = false;
  int _generation = 0, _preferenceGeneration = 0;
  final _events = <MiniGameScoreEvent>[];
  Future<void>? _submission;
  bool get current =>
      !_disposed && repository.current && timing.repository.current;
  bool get enabled =>
      current && preference?.enabled == true && !loadingPreference;
  bool get roundParticipating => current && _started && _eligible;
  bool get roundFinished => _finished;
  bool get canRetry =>
      current &&
      roundParticipating &&
      _finished &&
      !_badEvents &&
      !submitting &&
      receipt == null;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void acceptPreference(MiniGameCompetitionPreference value) {
    if (!current || value.scope != repository.scope) return;
    preference = value;
    preferenceFailed = false;
    if (!value.enabled) {
      _eligible = false;
      receipt = null;
    }
    _notify();
  }

  Future<void> loadPreference() async {
    if (!current || loadingPreference) return;
    final generation = ++_preferenceGeneration;
    loadingPreference = true;
    preferenceFailed = false;
    _notify();
    try {
      final value =
          await repository.preference().timeout(const Duration(seconds: 12));
      if (!current || generation != _preferenceGeneration) return;
      if (value.scope != repository.scope) {
        throw const FormatException('Unowned preference');
      }
      preference = value;
    } catch (_) {
      if (current && generation == _preferenceGeneration) {
        preference = null;
        preferenceFailed = true;
      }
    } finally {
      if (!_disposed && generation == _preferenceGeneration) {
        loadingPreference = false;
        _notify();
      }
    }
  }

  Future<void> setEnabled(bool value) async {
    if (!current || loadingPreference || (_started && !_finished)) return;
    final generation = ++_preferenceGeneration;
    loadingPreference = true;
    preferenceFailed = false;
    _notify();
    try {
      final result = await repository
          .setPreference(enabled: value)
          .timeout(const Duration(seconds: 12));
      if (!current || generation != _preferenceGeneration) return;
      if (result.scope != repository.scope || result.enabled != value) {
        throw const FormatException('Unconfirmed preference');
      }
      preference = result;
      if (!value) {
        _eligible = false;
        receipt = null;
      }
    } catch (_) {
      if (current && generation == _preferenceGeneration) {
        preferenceFailed = true;
      }
    } finally {
      if (!_disposed && generation == _preferenceGeneration) {
        loadingPreference = false;
        _notify();
      }
    }
  }

  void start() {
    if (!current || _started) return;
    _started = true;
    _eligible = enabled;
    if (_eligible) timing.start();
    _notify();
  }

  void observe({required int activeMillis, required bool playing}) {
    if (!roundParticipating || _finished) return;
    timing.observe(activeMillis: activeMillis, playing: playing);
  }

  void event(String type, int activeMillis) {
    if (!roundParticipating || _finished || _badEvents) return;
    final allowed =
        gameId == 'reach-tap-v1' ? const {'hit'} : const {'catch', 'obstacle'};
    if (!allowed.contains(type) ||
        activeMillis < 0 ||
        activeMillis > 40000 ||
        _events.length >= 400 ||
        (_events.isNotEmpty && activeMillis < _events.last.activeMillis)) {
      _badEvents = true;
      submissionFailed = true;
      _notify();
      return;
    }
    _events.add(MiniGameScoreEvent(
        sequence: _events.length + 1, activeMillis: activeMillis, type: type));
  }

  void finish() {
    if (!roundParticipating || _finished) return;
    _finished = true;
    if (!_badEvents) {
      timing.finish();
      _timingChanged();
    }
    _notify();
  }

  void _timingChanged() {
    if (!current ||
        !_finished ||
        !_eligible ||
        _badEvents ||
        receipt != null ||
        submitting ||
        submissionFailed) {
      return;
    }
    if (timing.completedRound != null) {
      unawaited(_submit());
    }
    _notify();
  }

  Future<void> _submit() {
    if (_submission != null) return _submission!;
    final round = timing.completedRound;
    if (!current ||
        !_finished ||
        !_eligible ||
        _badEvents ||
        round == null ||
        receipt != null) {
      return Future.value();
    }
    if (round.scope != repository.scope || round.gameId != gameId) {
      _badEvents = true;
      submissionFailed = true;
      _notify();
      return Future.value();
    }
    final generation = _generation,
        events = List<MiniGameScoreEvent>.unmodifiable(_events);
    submitting = true;
    submissionFailed = false;
    _notify();
    final operation = () async {
      try {
        final result = await repository
            .submit(
                gameId: gameId,
                attemptId: round.attemptId,
                challengeToken: round.challengeToken,
                events: events)
            .timeout(const Duration(seconds: 12));
        if (!current || generation != _generation) return;
        if (result.scope != repository.scope ||
            result.gameId != gameId ||
            result.attemptId != round.attemptId) {
          throw const FormatException('Unowned game result');
        }
        receipt = result;
      } catch (_) {
        if (current && generation == _generation) submissionFailed = true;
      } finally {
        if (!_disposed && generation == _generation) {
          submitting = false;
          _submission = null;
          _notify();
        }
      }
    }();
    _submission = operation;
    return operation;
  }

  Future<void> retry() async {
    if (!current || submitting || _badEvents) return;
    if (timing.canRetry) {
      timing.retry();
      return;
    }
    submissionFailed = false;
    await _submit();
  }

  /// Timing reset is game-owned because participation rewards can share it.
  void reset() {
    _generation++;
    _started = _eligible = _finished = _badEvents = false;
    _events.clear();
    receipt = null;
    submitting = submissionFailed = false;
    _submission = null;
    _notify();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _preferenceGeneration++;
    timing.removeListener(_timingChanged);
    super.dispose();
  }
}
