import 'package:flutter/widgets.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/domain/published_routine_view.dart';
import '../../features/workout/presentation/member/workout_prep_screen.dart';
import '../../navigation/workout_navigation.dart';
import 'pose_preview_route.dart';
import 'real_squat_route.dart';
import 'saved_squat_sessions_route.dart';

/// App-owned destinations for the published workout preparation flow.
class WorkoutPrepRoute extends StatelessWidget {
  const WorkoutPrepRoute({
    super.key,
    this.live = true,
    this.publishedRoutine,
    this.routineLoadFailed = false,
  });

  final PublishedRoutine? publishedRoutine;
  final bool live;
  final bool routineLoadFailed;

  @override
  Widget build(BuildContext context) => WorkoutPrepScreen(
      live: live,
      publishedRoutine: publishedRoutine,
      routineLoadFailed: routineLoadFailed,
      routes: const WorkoutPrepRoutes(
          realSessionBuilder: _realSession,
          savedSessionsBuilder: _savedSessions,
          posePreviewBuilder: _posePreview));
}

Widget _realSession(BuildContext context, RealWorkoutLaunch launch) =>
    RealSquatRoute(
        scope: launch.scope,
        routineId: launch.routineId,
        exercise: launch.exercise,
        consented: launch.consented,
        setupConfirmed: launch.setupConfirmed,
        requestServerUpload: launch.requestServerUpload);

Widget _savedSessions(BuildContext context, SessionScope scope) =>
    SavedSquatSessionsRoute(scope: scope);

Widget _posePreview(BuildContext context) => const PosePreviewRoute();
