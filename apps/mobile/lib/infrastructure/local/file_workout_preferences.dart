import 'dart:convert';
import 'dart:io';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/application/workout_preferences_controller.dart';

class FileWorkoutPreferences implements WorkoutPreferencesStore {
  FileWorkoutPreferences(
      {required Directory directory, required SessionScope scope})
      : _file = File('${directory.path}/workout-preferences-v1/'
            '${_segment(scope.organizationId)}/${_segment(scope.userId)}/preferences.json');
  final File _file;
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
  Future<Map<String, Object?>?> read() async {
    if (!await _file.exists()) return null;
    final value = jsonDecode(await _file.readAsString());
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid preferences');
    }
    return value;
  }

  @override
  Future<void> write(Map<String, Object?> value) async {
    await _file.parent.create(recursive: true);
    final temporary = File('${_file.path}.pending');
    await temporary.writeAsString(jsonEncode(value), flush: true);
    await temporary.rename(_file.path);
  }
}
