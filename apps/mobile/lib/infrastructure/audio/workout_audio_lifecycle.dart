import 'package:flutter/widgets.dart';

import '../../features/workout/application/workout_audio_controller.dart';

/// Optional Flutter lifecycle binding. Its owner closes the session/controller
/// on logout/disposal; removing this observer alone does not close shared audio.
class WorkoutAudioLifecycle with WidgetsBindingObserver {
  WorkoutAudioLifecycle(this.controller) {
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null) didChangeAppLifecycleState(state);
  }

  final WorkoutAudioController controller;
  bool _disposed = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_disposed) {
      controller.setForeground(state == AppLifecycleState.resumed);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
  }
}
