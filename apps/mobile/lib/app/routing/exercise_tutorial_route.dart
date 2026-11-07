import 'dart:async';
import '../../features/workout/presentation/workout_presentation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AppRole, SessionScope;
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../features/workout/domain/published_routine_view.dart';
import '../../features/workout/domain/exercise_tracker_dispatcher.dart';
import '../../features/workout/domain/tutorial_player.dart';
import '../../features/workout/presentation/member/published_exercise_tutorial_screen.dart';
import '../../infrastructure/media/video_tutorial_player.dart';

enum ExerciseTutorialOutcome { startExercise }

class ExerciseTutorialRoute extends StatefulWidget {
  const ExerciseTutorialRoute(
      {super.key,
      required this.scope,
      required this.exercise,
      this.allowStart = false,
      this.playerFactory = VideoTutorialPlayer.new});
  final bool allowStart;
  final SessionScope scope;
  final PublishedRoutineExercise exercise;
  final TutorialPlayerFactory playerFactory;
  @override
  State<ExerciseTutorialRoute> createState() => _ExerciseTutorialRouteState();
}

class _ExerciseTutorialRouteState extends State<ExerciseTutorialRoute> {
  final _authorized = ValueNotifier(false);
  StreamSubscription<AuthState>? _subscription;
  bool _allowed(AuthState state) =>
      state.session?.scope == widget.scope &&
      AuthRolePolicy.canEnter(state, allowed: const {AppRole.member});
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscription != null) return;
    final auth = context.read<AuthBloc>();
    _authorized.value = _allowed(auth.state);
    _subscription =
        auth.stream.listen((state) => _authorized.value = _allowed(state));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _authorized.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracking = const ExerciseTrackerDispatcher().resolve(
        organizationId: widget.scope.organizationId,
        exerciseId: widget.exercise.exerciseId);
    return PublishedExerciseTutorialScreen(
      exercise: widget.exercise,
      presentation: ExercisePresentation.forExercise(widget.exercise,
          organizationId: widget.scope.organizationId),
      onStart: widget.allowStart
          ? () {
              if (_authorized.value) {
                Navigator.pop(context, ExerciseTutorialOutcome.startExercise);
              }
            }
          : null,
      playerFactory: widget.playerFactory,
      perArmTargets: tracking.tracker == ExerciseTracker.sideViewCurl,
      targetLabel: switch (tracking.tracker) {
        ExerciseTracker.sideViewRow => 'Reps per selected arm per set',
        ExerciseTracker.sideViewReverseLunge => 'Reps per selected leg per set',
        _ => null,
      },
      trackingLabel: tracking.capability.displayLabel,
      trackingDescription: tracking.description,
      authorized: _authorized,
    );
  }
}
