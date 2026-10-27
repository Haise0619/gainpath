import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/domain/workout_contracts.dart';
import '../../features/workout/domain/workout_audio_port.dart';
import '../../features/workout/domain/routine_journey.dart';

Future<RoutineJourneyStore> createRoutineJourneyStore(SessionScope scope) =>
    Future.error(
        UnsupportedError('Durable routine progress requires the mobile app.'));

Future<WorkoutVoicePreferences> createWorkoutVoicePreferences(
        SessionScope scope) =>
    Future.error(
        UnsupportedError('Local workout preferences require the mobile app.'));

Future<WorkoutSessionStore> createWorkoutStore(SessionScope scope) =>
    Future.error(UnsupportedError(
        'Durable workouts require the Android or desktop app.'));
