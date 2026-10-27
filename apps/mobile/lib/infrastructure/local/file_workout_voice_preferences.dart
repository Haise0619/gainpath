import 'dart:convert';
import 'dart:io';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/domain/workout_audio_port.dart';

/// App-private audio preference, isolated by organization and signed-in member.
class FileWorkoutVoicePreferences implements WorkoutVoicePreferences {
  FileWorkoutVoicePreferences(
      {required Directory directory, required SessionScope scope})
      : _file = File('${directory.path}/workout-voice-v1/'
            '${_segment(scope.organizationId)}/${_segment(scope.userId)}/mode.txt');
  final File _file;
  Future<void> _pending = Future.value();

  static String _segment(String value) {
    final hex = utf8
        .encode(value)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return [
      for (var i = 0; i < hex.length; i += 100)
        hex.substring(i, i + 100 > hex.length ? hex.length : i + 100)
    ].join('/');
  }

  @override
  Future<WorkoutVoiceMode?> read() async {
    try {
      final name = await _file.readAsString();
      for (final mode in WorkoutVoiceMode.values) {
        if (mode.name == name) return mode;
      }
    } on FileSystemException {
      /* Missing/corrupt preference uses account defaults. */
    }
    return null;
  }

  @override
  Future<void> write(WorkoutVoiceMode mode) {
    final next = _pending.then((_) async {
      await _file.parent.create(recursive: true);
      await _file.writeAsString(mode.name, flush: true);
    });
    _pending = next.catchError((Object _) {});
    return next;
  }
}
