import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/application/workout_preferences_controller.dart';

Future<WorkoutPreferencesController> createWorkoutPreferences(
        SessionScope scope) =>
    Future.error(UnsupportedError(
        'Durable workout preferences require the mobile app.'));
