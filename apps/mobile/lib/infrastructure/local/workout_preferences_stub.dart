import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/application/workout_preferences_controller.dart';
import '../../features/workout/domain/workout_audio_port.dart';

Future<WorkoutPreferencesController> createWorkoutPreferences(
        SessionScope scope) =>
    Future.error(UnsupportedError(
        'Durable workout preferences require the mobile app.'));

Future<WorkoutVoicePreferences> createWorkoutVoicePreferences(
        SessionScope scope) =>
    Future.error(
        UnsupportedError('Local workout preferences require the mobile app.'));
