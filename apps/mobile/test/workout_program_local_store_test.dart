import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/domain/program_enrollment.dart';
import 'package:gainpath_mobile/infrastructure/local/file_program_enrollment_store.dart';
import 'package:gainpath_domain/workout.dart';
import 'workout_program_controller_test.dart' show programFixture;

void main() {
  test('v2 program journal preserves legacy bytes and detects downgrade drift',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('program-versions-');
    addTearDown(() => directory.delete(recursive: true));
    final scope = SessionScope(userId: 'member', organizationId: 'gym');
    final store =
        FileProgramEnrollmentStore(directory: directory, scope: scope);
    final legacy = programFixture();
    ProgramEnrollment enrollment(String id, WorkoutProgram p) =>
        ProgramEnrollment(
            id: id,
            program: p,
            schedule: ProgramSchedule.create(
                p, DateTime.utc(2026, 11, 2), {1, 3, 5}));
    final old = enrollment('old', legacy);
    await store.save(
        ProgramJournal(revision: 1, activeId: 'old', enrollments: [old]),
        expectedRevision: 0);
    final file = (await directory
            .list(recursive: true)
            .where((f) => f.path.endsWith('journal.json'))
            .toList())
        .single as File;
    final bytes = await file.readAsBytes();
    final json = legacy.toJson()..['schemaVersion'] = 2;
    final newer = WorkoutProgram.fromJson(json);
    await store.save(
        ProgramJournal(
            revision: 2,
            activeId: 'new',
            enrollments: [old, enrollment('new', newer)]),
        expectedRevision: 1);
    expect(await file.readAsBytes(), bytes);
    expect((await store.load()).active!.program.schemaVersion, 2);
    final oldData =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    oldData['journal']['revision'] = 2;
    await file.writeAsString(jsonEncode(oldData));
    await expectLater(store.load(), throwsStateError);
    expect(
        (await directory
                .list(recursive: true)
                .where((f) => f.path.endsWith('journal.json'))
                .toList())
            .length,
        2);
  });
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
