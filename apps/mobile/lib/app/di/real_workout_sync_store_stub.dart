import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/domain/real_workout_sync.dart';

Future<RealWorkoutSyncStore> createRealWorkoutSyncStore(SessionScope scope) =>
    Future.error(
        UnsupportedError('Durable workout sync requires the installed app.'));
