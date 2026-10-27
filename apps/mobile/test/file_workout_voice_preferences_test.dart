import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/infrastructure/local/file_workout_voice_preferences.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_audio_port.dart';

void main() {
  test(
      'voice mode survives reopening, stays account-scoped and last selection wins',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('gainpath-voice-test-');
    try {
      final scope = SessionScope(userId: 'member', organizationId: 'org');
      final store =
          FileWorkoutVoicePreferences(directory: directory, scope: scope);
      await Future.wait([
        store.write(WorkoutVoiceMode.fullCoaching),
        store.write(WorkoutVoiceMode.alertsOnly)
      ]);
      expect(
          await FileWorkoutVoicePreferences(directory: directory, scope: scope)
              .read(),
          WorkoutVoiceMode.alertsOnly);
      expect(
          await FileWorkoutVoicePreferences(
                  directory: directory,
                  scope: SessionScope(userId: 'Member', organizationId: 'org'))
              .read(),
          isNull);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
