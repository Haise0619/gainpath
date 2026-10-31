import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/domain/program_enrollment.dart';
import 'package:gainpath_mobile/infrastructure/local/file_program_enrollment_store.dart';
import 'package:gainpath_domain/workout.dart';
import 'workout_program_controller_test.dart' show programFixture;

void main() {
  test(
      'account journal persists with revision conflicts and organization isolation',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('gainpath-program-store-');
    addTearDown(() => directory.delete(recursive: true));
    final scope = SessionScope(userId: 'member', organizationId: 'gym');
    final store =
        FileProgramEnrollmentStore(directory: directory, scope: scope);
    final program = programFixture();
    final next =
        ProgramJournal(revision: 1, activeId: 'enrollment', enrollments: [
      ProgramEnrollment(
          id: 'enrollment',
          program: program,
          schedule: ProgramSchedule.create(
              program, DateTime.utc(2026, 11, 2), {1, 3, 5}))
    ]);
    await store.save(next, expectedRevision: 0);
    final reopened =
        FileProgramEnrollmentStore(directory: directory, scope: scope);
    expect((await reopened.load()).active!.program.version, 1);
    await expectLater(
        reopened.save(next, expectedRevision: 0), throwsStateError);
    final other = FileProgramEnrollmentStore(
        directory: directory,
        scope: SessionScope(userId: 'member', organizationId: 'other'));
    expect((await other.load()).enrollments, isEmpty);
  });
}
