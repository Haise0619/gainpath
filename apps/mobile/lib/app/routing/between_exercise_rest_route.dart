import 'dart:async';
import 'package:flutter/material.dart';
import '../../features/workout/application/between_exercise_rest_controller.dart';
import '../../features/workout/application/workout_audio_controller.dart';
import '../../features/workout/domain/workout_audio_port.dart';
import '../../features/workout/domain/published_routine_view.dart';
import '../../features/workout/presentation/member/between_exercise_rest_screen.dart';
import '../../infrastructure/audio/android_workout_audio.dart';

enum BetweenExerciseRestOutcome { advance, returnToRoutine }

typedef BetweenExerciseRestVoice = ({
  Future<WorkoutVoiceMode?> Function() loadMode,
  bool Function() canAnnounce,
  Listenable authorization,
});

/// Only push after the prior exercise result has been durably reconciled.
class BetweenExerciseRestRoute extends StatefulWidget {
  const BetweenExerciseRestRoute(
      {super.key,
      required this.previousExercise,
      required this.upcomingExercise,
      required this.organizationId,
      required this.restSeconds,
      required this.canAdvance,
      this.monotonicNow,
      this.voice,
      this.prescribed = false});
  final String previousExercise, organizationId;
  final PublishedRoutineExercise upcomingExercise;
  final int restSeconds;
  final bool prescribed;
  final bool Function() canAdvance;
  final Duration Function()? monotonicNow;
  final BetweenExerciseRestVoice? voice;
  @override
  State<BetweenExerciseRestRoute> createState() =>
      _BetweenExerciseRestRouteState();
}

class _BetweenExerciseRestRouteState extends State<BetweenExerciseRestRoute>
    with WidgetsBindingObserver {
  final _clock = Stopwatch()..start();
  late final _voice = widget.voice;
  late final BetweenExerciseRestController _controller;
  ModalRoute<dynamic>? _route;
  WorkoutAudioController? _audio;
  WorkoutVoiceMode? _voiceMode;
  bool _voiceRequested = false, _voiceInvalidated = false, _announced = false;
  Timer? _ticker;
  bool _foreground = true, _returned = false, _contextValid = true;
  bool get _allowed =>
      mounted &&
      !_returned &&
      _contextValid &&
      _foreground &&
      widget.canAdvance() &&
      _route?.isCurrent == true;
  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _controller = BetweenExerciseRestController(
        duration: Duration(seconds: widget.restSeconds.clamp(3, 3600)),
        monotonicNow: widget.monotonicNow ?? () => _clock.elapsed,
        canAdvance: () => _allowed,
        onReady: () async {
          if (_allowed) _return(BetweenExerciseRestOutcome.advance);
        });
    _controller.addListener(_syncVoice);
    _voice?.authorization.addListener(_syncVoice);
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_contextValid && !widget.canAdvance()) {
        setState(() => _contextValid = false);
      }
      if (!_allowed) {
        _controller.interrupt();
      } else {
        unawaited(_controller.tick());
        _syncVoice(afterTick: true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    _syncVoice();
  }

  Future<void> _loadVoiceMode(BetweenExerciseRestVoice voice) async {
    _voiceRequested = true;
    try {
      _voiceMode = await voice.loadMode();
    } catch (_) {
      // A missing local preference leaves optional voice off.
    }
    _syncVoice();
  }

  void _syncVoice({bool afterTick = false}) {
    final voice = _voice;
    if (voice == null || !mounted || _returned || _voiceInvalidated) return;
    if (!widget.canAdvance() || !voice.canAnnounce()) {
      _voiceInvalidated = true;
      _closeVoice();
      return;
    }
    if (!_allowed || _controller.phase != BetweenExerciseRestPhase.resting) {
      _audio?.cancelTransition();
      return;
    }
    final seconds = _controller.remainingSeconds;
    if (seconds < 3) return;
    if (!_voiceRequested) unawaited(_loadVoiceMode(voice));
    if (_voiceMode != WorkoutVoiceMode.fullCoaching || seconds > 8) return;
    // Allow the offline engine to warm before the final seconds of rest.
    final audio = _audio ??= WorkoutAudioController(
      port: AndroidWorkoutAudio(),
      boundedStarts: true,
    )..setVoiceMode(WorkoutVoiceMode.fullCoaching);
    // An asynchronous preference read cannot submit a cue on an old countdown.
    if (!afterTick || _announced || seconds > 5) return;
    _announced = true;
    audio.announceTransition(
      'next_exercise_preparation',
      'Get ready for ${widget.upcomingExercise.name}.',
      nowMicros: _clock.elapsedMicroseconds,
    );
  }

  void _closeVoice() {
    final audio = _audio;
    _audio = null;
    unawaited(audio?.close());
  }

  void _return(BetweenExerciseRestOutcome outcome) {
    if (_returned || !mounted) return;
    _returned = true;
    _ticker?.cancel();
    _closeVoice();
    _controller.cancel();
    Navigator.pop(context, outcome);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _controller.interrupt();
    _syncVoice();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _voice?.authorization.removeListener(_syncVoice);
    _controller.removeListener(_syncVoice);
    _closeVoice();
    _controller.dispose();
    _clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _returned = true;
          _ticker?.cancel();
          _closeVoice();
        } else {
          _return(BetweenExerciseRestOutcome.returnToRoutine);
        }
      },
      child: BetweenExerciseRestScreen(
          controller: _controller,
          previousExercise: widget.previousExercise,
          upcomingExercise: widget.upcomingExercise,
          organizationId: widget.organizationId,
          prescribed: widget.prescribed,
          preparationOnly: widget.restSeconds < 3,
          canContinue: _contextValid,
          onViewRoutine: () =>
              _return(BetweenExerciseRestOutcome.returnToRoutine)));
}
