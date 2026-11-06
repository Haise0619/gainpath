import 'dart:convert';
import 'dart:io';
import 'floor_push_up_fixture_evaluator.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
        'Usage: dart run packages/gainpath_pose/tool/evaluate_floor_push_up_fixture.dart <fixture.json>');
    exitCode = 64;
    return;
  }
  RandomAccessFile? file;
  try {
    file = await File(arguments.single).open();
    final length = await file.length();
    if (length > maximumFloorFixtureBytes) throw const FormatException();
    final bytes = await file.read(length + 1);
    if (bytes.length != length) throw const FormatException();
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map<String, Object?>) throw const FormatException();
    final report = evaluateFloorPushUpFixture(json);
    stdout.writeln(jsonEncode(report));
    if (report['matchesReference'] != true) exitCode = 2;
  } on FileSystemException {
    stderr.writeln('Could not read floor push-up fixture.');
    exitCode = 66;
  } on FormatException {
    stderr.writeln('Invalid floor push-up fixture.');
    exitCode = 65;
  } finally {
    await file?.close();
  }
}
