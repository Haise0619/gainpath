import 'dart:async';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/application/workout_backup_scheduler.dart';
import 'workout_local_save_notifications.dart';

/// Scoped hints shared by production composition and injected local fixtures.
class WorkoutBackupWakeups {
  WorkoutBackupWakeups(
      {required SessionScope scope,
      required SessionScope? Function() activeScope,
      required WorkoutBackupScheduler scheduler,
      required Stream<void> networkOpportunities}) {
    _saves = workoutLocalSaves.listen((saved) {
      if (saved == scope && activeScope() == scope) scheduler.localChanged();
    });
    _network = networkOpportunities.listen((_) {
      if (activeScope() == scope) scheduler.opportunity();
    }, onError: (Object _) {});
  }
  late final StreamSubscription<SessionScope> _saves;
  late final StreamSubscription<void> _network;
  void dispose() {
    unawaited(_saves.cancel());
    unawaited(_network.cancel());
  }
}
