import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/app/di/workout_backup_factory.dart';

void main() {
  test(
      'ordinary main builds expose optional workout backup after backend release',
      () {
    expect(workoutCloudBackupEnabled, isTrue,
        reason:
            'A normal Android Studio main.dart run must allow members to opt in without extra build arguments.');
  });
}
