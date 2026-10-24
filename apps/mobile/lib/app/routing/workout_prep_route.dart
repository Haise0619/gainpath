import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/membership.dart';
import '../../features/membership/presentation/shared/membership_access_gate.dart';
import '../di/membership_factory.dart';
import '../../features/workout/domain/published_routine_view.dart';
import '../../features/workout/presentation/member/workout_prep_screen.dart';
import '../../navigation/workout_navigation.dart';
import 'pose_preview_route.dart';
import 'real_squat_route.dart';
import 'saved_squat_sessions_route.dart';
import 'exercise_tutorial_route.dart';

/// App-owned destinations for the published workout preparation flow.
class WorkoutPrepRoute extends StatelessWidget {
  const WorkoutPrepRoute({
    super.key,
    this.live = true,
    this.publishedRoutine,
    this.routineLoadFailed = false,
    this.routineStatusMessage,
    this.routineCatalogControls,
    this.onOpenEquipment,
  });

  final PublishedRoutine? publishedRoutine;
  final bool live;
  final bool routineLoadFailed;
  final String? routineStatusMessage;
  final Widget? routineCatalogControls;
  final VoidCallback? onOpenEquipment;

  @override
  Widget build(BuildContext context) {
    final auth = live ? context.read<AuthBloc>() : null;
    final scope = auth?.state.session?.scope;
    return WorkoutPrepScreen(
        live: live,
        onOpenEquipment: onOpenEquipment,
        publishedRoutine: publishedRoutine,
        routineLoadFailed: routineLoadFailed,
        routineStatusMessage: routineStatusMessage,
        routineCatalogControls: routineCatalogControls,
        routes: WorkoutPrepRoutes(
            realSessionBuilder: _realSession,
            savedSessionsBuilder: _savedSessions,
            posePreviewBuilder: _posePreview,
            tutorialBuilder: scope == null
                ? null
                : (_, exercise) => BlocProvider.value(
                    value: auth!,
                    child: ExerciseTutorialRoute(
                        scope: scope, exercise: exercise))));
  }
}

Widget _realSession(BuildContext context, RealWorkoutLaunch launch) =>
    MembershipAccessGate(
        enabled: membershipAccessEnforcementEnabled,
        feature: MembershipAccessFeature.exercise,
        resourceId: launch.exercise.exerciseId,
        child: RealSquatRoute(
            scope: launch.scope,
            routineId: launch.routineId,
            exercise: launch.exercise,
            consented: launch.consented,
            setupConfirmed: launch.setupConfirmed,
            requestServerUpload: launch.requestServerUpload));

Widget _savedSessions(BuildContext context, SessionScope scope) =>
    SavedSquatSessionsRoute(scope: scope);

Widget _posePreview(BuildContext context) => const PosePreviewRoute();
