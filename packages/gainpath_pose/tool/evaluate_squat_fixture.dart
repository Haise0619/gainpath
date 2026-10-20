import 'dart:convert';
import 'dart:io';
import 'squat_fixture_evaluator.dart';

/// Local validation command. Does not write fixtures, activity or reports.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
        'Usage: dart run tool/evaluate_squat_fixture.dart <fixture.json>');
    exitCode = 64;
    return;
  }
  RandomAccessFile? file;
  try {
    file = await File(arguments.single).open();
    final length = await file.length();
    if (length > maximumFixtureBytes) {
      throw const FormatException('Fixture size limit.');
    }
    final bytes = await file.read(length + 1);
    if (bytes.length != length) {
      throw const FormatException('Fixture changed during read.');
    }
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map<String, Object?>) {
      throw const FormatException('Fixture object required.');
    }
    final report = evaluateSquatFixture(SquatFixture.fromJson(json));
    stdout.writeln(jsonEncode(report));
    if (report['countMatch'] != true) exitCode = 2;
  } on FileSystemException {
    stderr.writeln('Could not read squat fixture.');
    exitCode = 66;
  } on FormatException {
    stderr.writeln('Invalid squat fixture.');
    exitCode = 65;
  } finally {
    await file?.close();
  }
}
