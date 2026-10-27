import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/domain/workout_backup.dart';

Future<WorkoutBackupStore> createWorkoutBackupStore(SessionScope scope) =>
    Future.error(UnsupportedError('Backup metadata requires the mobile app.'));
