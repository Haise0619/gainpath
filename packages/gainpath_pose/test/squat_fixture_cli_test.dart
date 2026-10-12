import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'support/squat_fixture_sample.dart';

void main() {
  late Directory directory;
  setUp(() =>
      directory = Directory.systemTemp.createTempSync('gainpath-fixture-'));
  tearDown(() => directory.deleteSync(recursive: true));
  Future<ProcessResult> run(List<String> arguments) => Process.run(
      Platform.resolvedExecutable,
      ['run', 'tool/evaluate_squat_fixture.dart', ...arguments]);
  test(
      'CLI produces aggregate-only JSON and nonzero exit for mismatched labels',
      () async {
    final input = File('${directory.path}/fixture.json');
    await input.writeAsString(jsonEncode(fixtureDocument()));
    final result = await run([input.path]);
    expect(result.exitCode, 0);
    final report = jsonDecode(result.stdout as String) as Map;
    expect(report['countMatch'], true);
    expect(report['serverEligible'], false);
    expect(result.stdout.toString(), isNot(contains('leftShoulder')));
    await input.writeAsString(jsonEncode(fixtureDocument(expectedFull: 3)));
    final mismatch = await run([input.path]);
    expect(mismatch.exitCode, 2);
    expect((jsonDecode(mismatch.stdout as String) as Map)['countMatch'], false);
  });
  test(
      'malformed, oversized, missing and wrong-argument input fails with bounded diagnostics',
      () async {
    final input = File('${directory.path}/secret-body-data.json');
    await input.writeAsString('{"private-data":');
    final bad = await run([input.path]);
    expect(bad.exitCode, 65);
    expect(bad.stdout, '');
    expect(bad.stderr.toString(), isNot(contains('private-data')));
    expect(bad.stderr.toString(), isNot(contains(input.path)));
    await input.writeAsString(
        '${jsonEncode(fixtureDocument())}${' ' * (16 * 1024 * 1024)}');
    expect((await run([input.path])).exitCode, 65);
    expect((await run(['${directory.path}/missing.json'])).exitCode, 66);
    expect((await run([])).exitCode, 64);
  });
}
