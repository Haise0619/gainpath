import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:path_provider/path_provider.dart';
import '../../features/workout/domain/workout_backup.dart';
import '../../infrastructure/local/file_workout_backup_store.dart';

Future<WorkoutBackupStore> createWorkoutBackupStore(SessionScope scope) async =>
    FileWorkoutBackupStore(
        directory: await getApplicationSupportDirectory(), scope: scope);
