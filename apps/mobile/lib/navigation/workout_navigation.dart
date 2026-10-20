import 'package:flutter/widgets.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../features/workout/domain/published_routine_view.dart';

abstract final class WorkoutNavigation {
  static const guided = '/workout/guided';
}

/// Consent and content identity selected before opening a measured session.
class RealWorkoutLaunch {
  const RealWorkoutLaunch({
    required this.scope,
    required this.routineId,
    required this.exercise,
    required this.consented,
    required this.setupConfirmed,
    required this.requestServerUpload,
  });

  final SessionScope scope;
  final String routineId;
  final PublishedRoutineExercise exercise;
  final bool consented, setupConfirmed, requestServerUpload;
}

/// Destinations supplied by app composition to the preparation screen.
class WorkoutPrepRoutes {
  const WorkoutPrepRoutes({
    this.realSessionBuilder,
    this.savedSessionsBuilder,
    this.posePreviewBuilder,
    this.tutorialBuilder,
  });

  final Widget Function(BuildContext, RealWorkoutLaunch)? realSessionBuilder;
  final Widget Function(BuildContext, SessionScope)? savedSessionsBuilder;
  final WidgetBuilder? posePreviewBuilder;
  final Widget Function(BuildContext, PublishedRoutineExercise)?
      tutorialBuilder;
}
