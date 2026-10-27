import 'package:flutter/material.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/domain/workout_contracts.dart';
import '../../features/workout/domain/real_workout_sync.dart';
import '../../features/workout/domain/routine_journey.dart';
import '../di/workout_store_factory.dart';
import '../di/real_workout_sync_store_factory.dart';
import '../di/local_member_progress_factory.dart';
import 'member_progress_route.dart';

/// Existing workout-preparation history entry uses the same read-only mapper
/// and durable upload-state labels as Home and Progress.
class SavedSquatSessionsRoute extends StatelessWidget {
  const SavedSquatSessionsRoute(
      {super.key,
      required this.scope,
      this.storeFactory = createWorkoutStore,
      this.syncStoreFactory = createRealWorkoutSyncStore,
      this.routineStoreFactory = createRoutineJourneyStore});
  final SessionScope scope;
  final Future<WorkoutSessionStore> Function(SessionScope) storeFactory;
  final Future<RealWorkoutSyncStore> Function(SessionScope) syncStoreFactory;
  final Future<RoutineJourneyStore> Function(SessionScope) routineStoreFactory;
  @override
  Widget build(BuildContext context) => MemberProgressRoute(
      scope: scope,
      view: MemberProgressView.history,
      repositoryFactory: (scope, active) => createLocalMemberProgressRepository(
          scope, active,
          storeFactory: storeFactory,
          syncStoreFactory: syncStoreFactory,
          routineStoreFactory: routineStoreFactory));
}
