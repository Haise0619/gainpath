import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, MemberPreferences;
import 'package:gainpath_pose/gainpath_pose.dart';
import '../domain/workout_contracts.dart';
import '../domain/real_workout_contract.dart';
import '../domain/workout_audio_port.dart';
import 'pose_preview_controller.dart';
import 'squat_processing_controller.dart';
import 'workout_audio_controller.dart';
import '../../../infrastructure/pose/real_squat_performance.dart';

enum RealSquatSessionPhase { idle, active, saving, saveFailed, saved, closed }

/// Owns one local camera session. It never constructs an upload submission.
class RealSquatSessionController extends ChangeNotifier {
  RealSquatSessionController(
      {required this.scope,
      required this.activeScope,
      required PoseCameraSource camera,
      required Future<ManagedPoseDetector> Function() detectorFactory,
      required WorkoutAudioPort audioPort,
      required this.repository,
      required this.clockMicros,
      required this.sessionId,
      required this.exerciseId,
      required this.publishedRoutineId,
      required this.detectorId,
      required this.detectorVersion,
      this.onSaved,
      RealSquatPerformance? performance,
      this.provenance = WorkoutProvenance.realCamera}) {
    if (repository.scope != scope) {
      throw ArgumentError('Session repository scope mismatch');
    }
    if (provenance != WorkoutProvenance.realCamera &&
        provenance != WorkoutProvenance.recordedFixture) {
      throw ArgumentError(
          'Measured session requires explicit input provenance');
    }
    processing = SquatProcessingController(
        scope: scope,
        activeScope: activeScope,
        audio: WorkoutAudioController(port: audioPort),
        clockMicros: clockMicros,
        performance: performance,
        sideViewConfirmed: true,
        uprightCameraConfirmed: true);
    preview = PosePreviewController(
        scope: scope,
        activeScope: activeScope,
        camera: camera,
        detectorFactory: detectorFactory,
        clockMicros: clockMicros,
        onRefined: _consume,
        performance: performance,
        onGeometryInvalidated: _geometryInvalidated);
    processing.addListener(_analysisChanged);
    preview.addListener(_cameraChanged);
  }
  final SessionScope scope;
  final SessionScope? Function() activeScope;
  final WorkoutRepository repository;
  final int Function() clockMicros;
  final String sessionId,
      exerciseId,
      publishedRoutineId,
      detectorId,
      detectorVersion;
  final WorkoutProvenance provenance;
  final Future<void> Function(WorkoutSessionSummary)? onSaved;
  late final PosePreviewController preview;
  late final SquatProcessingController processing;
  RealSquatSessionPhase phase = RealSquatSessionPhase.idle;
  SquatUpdate? latest;
  WorkoutSessionSummary? summary;
  String? _error;
  String? get errorMessage => _error ?? preview.errorMessage;
  bool get isPaused => processing.isPaused;
  bool get voiceEnabled => processing.audio.voiceEnabled;
  bool get _active =>
      !_disposed &&
      phase != RealSquatSessionPhase.closed &&
      activeScope() == scope;
  bool _disposed = false,
      _foreground = true,
      _startDeferred = false,
      _hasFrame = false,
      _modelChanged = false,
      _voiceOverridden = false;
  DateTime? _startedAt;
  int? _startedMicros;
  int _lastAttempt = 0;
  final _deviations = <String, WorkoutDeviationAggregate>{};
  Future<WorkoutSessionSummary?>? _saving;
  Future<void>? _closing;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start(
      {required bool consented,
      required bool setupConfirmed,
      bool? foreground}) async {
    if (!_active ||
        !consented ||
        !setupConfirmed ||
        phase != RealSquatSessionPhase.idle) {
      return;
    }
    _startedAt = DateTime.now().toUtc();
    _startedMicros = clockMicros();
    phase = RealSquatSessionPhase.active;
    _foreground = foreground ?? _foreground;
    if (!_foreground) {
      _startDeferred = true;
      processing.setForeground(false);
      _notify();
      return;
    }
    await preview.start(consented: true);
  }

  void _consume(PoseFrame frame) {
    if (!_active || phase != RealSquatSessionPhase.active) return;
    if (frame.detectorId != detectorId ||
        frame.modelVersion != detectorVersion) {
      _modelChanged = true;
      _error = 'Pose model changed. End this session and start again.';
      unawaited(pause());
      return;
    }
    _hasFrame = true;
    processing.consumeRefined(frame);
  }

  void _analysisChanged() {
    if (!_active || phase != RealSquatSessionPhase.active) return;
    final update = processing.update;
    if (update != null) {
      latest = update;
      final attempt = update.completedAttempt;
      if (attempt != null && attempt.number > _lastAttempt) {
        _lastAttempt = attempt.number;
        for (final deviation in attempt.deviations) {
          final old = _deviations[deviation.kind.name];
          _deviations[deviation.kind.name] = WorkoutDeviationAggregate(
              count: (old?.count ?? 0) + 1,
              maximumDegrees:
                  old == null || deviation.degrees > old.maximumDegrees
                      ? deviation.degrees
                      : old.maximumDegrees);
        }
      }
    }
    _notify();
  }

  void _geometryInvalidated() {
    if (!_active || phase != RealSquatSessionPhase.active) return;
    final wasPaused = isPaused;
    processing.pause();
    if (!wasPaused) processing.resume();
  }

  void _cameraChanged() {
    if (!_active) {
      unawaited(close());
      return;
    }
    if (preview.phase == PosePreviewPhase.failure) processing.pause();
    _notify();
  }

  void applyPreferences(MemberPreferences preferences) {
    if (!_voiceOverridden && _active && phase == RealSquatSessionPhase.active) {
      processing.applyPreferences(preferences);
    }
  }

  void setVoiceEnabled(bool enabled) {
    _voiceOverridden = true;
    if (_active && phase == RealSquatSessionPhase.active) {
      processing.setVoiceEnabled(enabled);
    }
    _notify();
  }

  Future<void> pause() async {
    if (!_active || phase != RealSquatSessionPhase.active) return;
    processing.pause();
    try {
      await preview.pause();
    } catch (_) {
      if (_active) {
        _error =
            'Camera shutdown failed. Counting is paused; save or discard the session.';
        _notify();
      }
    }
  }

  Future<void> resume() async {
    if (!_active || phase != RealSquatSessionPhase.active || _modelChanged) {
      return;
    }
    _error = null;
    processing.resume();
    await preview.resume();
  }

  Future<void> setForeground(bool foreground) async {
    _foreground = foreground;
    if (!_active || phase != RealSquatSessionPhase.active) return;
    processing.setForeground(foreground);
    if (_startDeferred) {
      if (foreground) {
        _startDeferred = false;
        await preview.start(consented: true);
      }
      return;
    }
    if (foreground) {
      await preview.foreground();
    } else {
      try {
        await preview.background();
      } catch (_) {
        if (_active) {
          _error =
              'Camera shutdown failed. Counting is paused; save or discard the session.';
          _notify();
        }
      }
    }
  }

  void accountChanged() {
    if (activeScope() != scope) unawaited(close());
  }

  Future<WorkoutSessionSummary?> endAndSave() {
    if (_saving != null) return _saving!;
    if (!_active || phase == RealSquatSessionPhase.idle) {
      return Future.value(null);
    }
    if (phase == RealSquatSessionPhase.saved) return Future.value(summary);
    if (!_hasFrame) {
      _error =
          'No camera frames were analyzed. Retry the camera or discard this session.';
      _notify();
      return Future.value(null);
    }
    // Reserve before freshness publication: observers can request end again.
    final completion = Completer<WorkoutSessionSummary?>();
    final pending = _saving = completion.future;
    try {
      if (summary == null) {
        processing.checkFreshness();
        if (!_active) {
          _saving = null;
          completion.complete(null);
          return pending;
        }
        final value = latest;
        final elapsed = clockMicros() - _startedMicros!;
        summary = WorkoutSessionSummary(
            sessionId: sessionId,
            userId: scope.userId,
            organizationId: scope.organizationId,
            exerciseId: exerciseId,
            repetitions: value?.repetitions ?? 0,
            accuracy: value?.formScorePercent?.round() ?? 0,
            startedAt: _startedAt!,
            endedAt: _startedAt!
                .add(Duration(microseconds: elapsed > 0 ? elapsed : 1)),
            provenance: provenance,
            poseMetrics: WorkoutPoseMetrics(
                partialRepetitions: value?.partialRepetitions ?? 0,
                trackedDurationMicros: value?.trackedDurationMicros ?? 0,
                rejectedDurationMicros: value?.rejectedDurationMicros ?? 0,
                formScorePercent: value?.formScorePercent,
                scoringVersion: SquatRuleSet.version,
                detectorId: detectorId,
                detectorVersion: detectorVersion,
                cameraView: 'side',
                consentVersion: workoutConsentVersion,
                consentedAt: _startedAt!,
                publishedRoutineId: publishedRoutineId,
                deviations: _deviations));
      }
      phase = RealSquatSessionPhase.saving;
      _error = null;
      unawaited(
          _save().then(completion.complete, onError: completion.completeError));
      _notify();
    } catch (_) {
      _saving = null;
      if (_active) {
        phase = RealSquatSessionPhase.saveFailed;
        _error =
            'Could not prepare this result. Discard the session and start again.';
      }
      completion.complete(null);
      _notify();
    }
    return pending;
  }

  Future<WorkoutSessionSummary?> _save() async {
    // Yield so the caller stores _saving before any completion or notification.
    await Future<void>.value();
    try {
      await processing.close();
      // Input is invalidated synchronously by close. A hardware disposal error
      // must not discard the already frozen measured result.
      await preview.close().catchError((Object _) {});
      if (!_active) return null;
      final frozen = summary!;
      await repository.saveLocal(frozen);
      if (!_active) return null;
      try {
        await onSaved?.call(frozen);
      } catch (_) {
        _error =
            'The local result is saved. Upload queuing needs retry from saved sessions.';
      }
      if (!_active) return null;
      phase = RealSquatSessionPhase.saved;
      return frozen;
    } catch (_) {
      if (_active) {
        phase = RealSquatSessionPhase.saveFailed;
        _error =
            'Could not save on this device. Retry to save the same result.';
      }
      return null;
    } finally {
      _saving = null;
      _notify();
    }
  }

  Future<void> close() {
    if (_closing != null) return _closing!;
    phase = RealSquatSessionPhase.closed;
    latest = null;
    summary = null;
    processing.removeListener(_analysisChanged);
    preview.removeListener(_cameraChanged);
    _closing = Future.wait([
      processing.close().catchError((Object _) {}),
      preview.close().catchError((Object _) {})
    ]).then((_) {});
    _notify();
    return _closing!;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(close());
    processing.dispose();
    preview.dispose();
    super.dispose();
  }
}
