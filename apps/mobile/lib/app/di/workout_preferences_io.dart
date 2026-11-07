import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:path_provider/path_provider.dart';
import '../../features/workout/application/workout_preferences_controller.dart';
import '../../infrastructure/local/file_workout_preferences.dart';

final _controllers = <SessionScope, Future<WorkoutPreferencesController>>{};
Future<WorkoutPreferencesController> createWorkoutPreferences(
        SessionScope scope) =>
    _controllers.putIfAbsent(scope, () async {
      final controller = WorkoutPreferencesController(
          scope: scope,
          store: FileWorkoutPreferences(
              directory: await getApplicationSupportDirectory(), scope: scope));
      await controller.load();
      return controller;
    });
