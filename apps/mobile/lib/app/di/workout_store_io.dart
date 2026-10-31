import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:path_provider/path_provider.dart';
import '../../features/workout/domain/workout_contracts.dart';
import '../../infrastructure/local/file_workout_session_store.dart';
import '../../features/workout/domain/workout_audio_port.dart';
import '../../infrastructure/local/file_workout_voice_preferences.dart';
import '../../features/workout/domain/routine_journey.dart';
import '../../infrastructure/local/file_routine_journey_store.dart';
import 'workout_local_save_notifications.dart';

Future<RoutineJourneyStore> createRoutineJourneyStore(
        SessionScope scope) async =>
    FileRoutineJourneyStore(
        directory: await getApplicationSupportDirectory(),
        scope: scope,
        onSaved: () => notifyWorkoutLocalSave(scope));

Future<WorkoutSessionStore> createWorkoutStore(SessionScope scope) async =>
    FileWorkoutSessionStore(
        directory: await getApplicationSupportDirectory(),
        scope: scope,
        onSaved: () => notifyWorkoutLocalSave(scope));

Future<WorkoutVoicePreferences> createWorkoutVoicePreferences(
        SessionScope scope) async =>
    FileWorkoutVoicePreferences(
        directory: await getApplicationSupportDirectory(), scope: scope);
