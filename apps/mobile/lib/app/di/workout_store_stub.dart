import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/domain/workout_contracts.dart';

Future<WorkoutSessionStore> createWorkoutStore(SessionScope scope) =>
    Future.error(UnsupportedError(
        'Durable workouts require the Android or desktop app.'));
