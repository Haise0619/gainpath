import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:path_provider/path_provider.dart';
import '../../features/workout/domain/real_workout_sync.dart';
import '../../infrastructure/local/file_real_workout_sync_store.dart';

Future<RealWorkoutSyncStore> createRealWorkoutSyncStore(
        SessionScope scope) async =>
    FileRealWorkoutSyncStore(
        directory: await getApplicationSupportDirectory(), scope: scope);
