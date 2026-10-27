import 'dart:async';
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

class ExerciseTutorialRoute extends StatefulWidget {
  const ExerciseTutorialRoute(
      {super.key,
      required this.scope,
      required this.exercise,
      this.playerFactory = VideoTutorialPlayer.new});
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
  Widget build(BuildContext context) => PublishedExerciseTutorialScreen(
      exercise: widget.exercise,
      playerFactory: widget.playerFactory,
      perArmTargets: const ExerciseTrackerDispatcher()
              .resolve(
                  organizationId: widget.scope.organizationId,
                  exerciseId: widget.exercise.exerciseId)
              .tracker ==
          ExerciseTracker.sideViewCurl,
      authorized: _authorized);
}
