import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/application/workout_audio_controller.dart';
import 'package:gainpath_mobile/infrastructure/audio/workout_audio_lifecycle.dart';
import 'workout_audio_controller_test.dart' show FakeAudio, warning;

void main() {
  testWidgets('binding releases on background and preserves manual pause',
      (tester) async {
    final port = FakeAudio();
    final controller = WorkoutAudioController(port: port)
      ..setVoiceEnabled(true);
    final binding = WorkoutAudioLifecycle(controller);
    controller.pause();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    controller.consume([warning], nowMicros: 0, trackingAvailable: true);
    await tester.pump();
    expect(port.played, isEmpty);
    controller.resume();
    controller.consume([warning], nowMicros: 1, trackingAvailable: true);
    await tester.pump();
    expect(port.played, [warning]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(controller.activeCue, isNull);
    binding.dispose();
    binding.dispose();
    await controller.close();
  });
}
