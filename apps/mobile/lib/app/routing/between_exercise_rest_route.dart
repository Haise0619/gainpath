import 'dart:async';
import 'package:flutter/material.dart';
import '../../features/workout/application/between_exercise_rest_controller.dart';
import '../../features/workout/domain/published_routine_view.dart';
import '../../features/workout/presentation/member/between_exercise_rest_screen.dart';

enum BetweenExerciseRestOutcome { advance, returnToRoutine }

/// Only push after the prior exercise result has been durably reconciled.
class BetweenExerciseRestRoute extends StatefulWidget {
  const BetweenExerciseRestRoute(
      {super.key,
      required this.previousExercise,
      required this.upcomingExercise,
      required this.organizationId,
      required this.restSeconds,
      required this.canAdvance,
      this.prescribed = false});
  final String previousExercise, organizationId;
  final PublishedRoutineExercise upcomingExercise;
  final int restSeconds;
  final bool prescribed;
  final bool Function() canAdvance;
  @override
  State<BetweenExerciseRestRoute> createState() =>
      _BetweenExerciseRestRouteState();
}

class _BetweenExerciseRestRouteState extends State<BetweenExerciseRestRoute>
    with WidgetsBindingObserver {
  final _clock = Stopwatch()..start();
  late final BetweenExerciseRestController _controller;
  Timer? _ticker;
  bool _foreground = true, _returned = false, _contextValid = true;
  bool get _allowed =>
      mounted &&
      !_returned &&
      _contextValid &&
      _foreground &&
      widget.canAdvance() &&
      ModalRoute.of(context)?.isCurrent == true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = BetweenExerciseRestController(
        duration: Duration(seconds: widget.restSeconds.clamp(0, 3600)),
        monotonicNow: () => _clock.elapsed,
        canAdvance: () => _allowed,
        onReady: () async {
          if (_allowed) _return(BetweenExerciseRestOutcome.advance);
        });
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_contextValid && !widget.canAdvance()) {
        setState(() => _contextValid = false);
      }
      if (!_allowed) {
        _controller.interrupt();
      } else {
        unawaited(_controller.tick());
      }
    });
  }

  void _return(BetweenExerciseRestOutcome outcome) {
    if (_returned || !mounted) return;
    _returned = true;
    _ticker?.cancel();
    _controller.cancel();
    Navigator.pop(context, outcome);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _controller.interrupt();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _controller.dispose();
    _clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _return(BetweenExerciseRestOutcome.returnToRoutine);
      },
      child: BetweenExerciseRestScreen(
          controller: _controller,
          previousExercise: widget.previousExercise,
          upcomingExercise: widget.upcomingExercise,
          organizationId: widget.organizationId,
          prescribed: widget.prescribed,
          canContinue: _contextValid,
          onViewRoutine: () =>
              _return(BetweenExerciseRestOutcome.returnToRoutine)));
}
