import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:path_provider/path_provider.dart';
import '../../features/workout/domain/workout_contracts.dart';
import '../../infrastructure/local/file_workout_session_store.dart';

Future<WorkoutSessionStore> createWorkoutStore(SessionScope scope) async =>
    FileWorkoutSessionStore(
        directory: await getApplicationSupportDirectory(), scope: scope);
