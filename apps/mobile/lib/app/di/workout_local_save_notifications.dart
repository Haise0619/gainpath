import 'dart:async';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

/// A local-only wakeup. No subscriber means no work and no Firebase creation.
final _workoutLocalSaves = StreamController<SessionScope>.broadcast();
Stream<SessionScope> get workoutLocalSaves => _workoutLocalSaves.stream;

void notifyWorkoutLocalSave(SessionScope scope) {
  _workoutLocalSaves.add(scope);
}
