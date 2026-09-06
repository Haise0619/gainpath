import 'package:gainpath/features/workout/domain/entities/exercise.dart';
import 'package:gainpath/features/workout/domain/entities/workout_record.dart';

/// Data access contract for the workout feature. Implemented in-memory for the
/// prototype; a Firebase implementation will sit behind the same interface.
abstract class WorkoutRepository {
  List<Exercise> get routine;
  List<String> get voiceCues;
  List<WorkoutRecord> get history;
  int get heightCm;
}
