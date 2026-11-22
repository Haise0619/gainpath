import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/analytics/data/local_member_progress_repository.dart';
import 'package:gainpath_mobile/features/analytics/domain/local_member_progress_repository.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/real_workout_sync.dart';

/// Use the real scoped read model without accessing the host filesystem.
Future<LocalMemberProgressRepository> inMemoryMemberProgress(
        SessionScope scope, SessionScope? Function() activeScope) async =>
    StoredLocalMemberProgressRepository(
        scope: scope,
        workoutStore: InMemoryWorkoutSessionStore(scope: scope),
        syncStore: MemoryRealWorkoutSyncStore(scope: scope),
        activeScope: activeScope);
