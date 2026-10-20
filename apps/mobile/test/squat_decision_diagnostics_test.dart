import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/infrastructure/pose/squat_decision_diagnostics.dart';
import 'package:gainpath_mobile/features/workout/application/squat_processing_controller.dart';
import 'package:gainpath_mobile/features/workout/application/workout_audio_controller.dart';
import 'squat_processing_controller_test.dart' as support;

void main() {
  const expected =
      !kReleaseMode && bool.fromEnvironment('GAINPATH_SQUAT_DECISIONS');
  const expectedWorld =
      expected && bool.fromEnvironment('GAINPATH_SQUAT_3D_COMPARE');
  test('recorder attaches only in explicitly enabled non-release composition',
      () {
    expect(squatDecisionDiagnosticsEnabled, expected);
    expect(squatWorldComparisonEnabled, expectedWorld);
    final created = createSquatDiagnosticRecorder();
    expect(created, expected ? isNotNull : isNull);
    if (created != null) expect(created.compareWorldAngles, expectedWorld);
  });
  testWidgets(
      'terminal reports are scalar and buffers clear on close even when logging fails',
      (tester) async {
    final old = debugPrint;
    final lines = <String>[];
    debugPrint = (String? text, {int? wrapWidth}) {
      if (text != null) lines.add(text);
    };
    final scope =
        SessionScope(userId: 'private-member', organizationId: 'private-org');
    var now = 0;
    final recorder = SquatDiagnosticRecorder(compareWorldAngles: true);
    final c = SquatProcessingController(
        scope: scope,
        activeScope: () => scope,
        clockMicros: () => now,
        audio: WorkoutAudioController(port: support.AudioSink()),
        sideViewConfirmed: true,
        uprightCameraConfirmed: true,
        analyzer: SquatAnalyzer(diagnostics: recorder));
    void step(double a) {
      now += 100000;
      c.consumeRefined(support.frame(now, a));
    }

    void hold(double a, int n) {
      for (var i = 0; i < n; i++) {
        step(a);
      }
    }

    void ramp(double a, double b) {
      for (var i = 1; i <= 20; i++) {
        step(a + (b - a) * i / 20);
      }
    }

    try {
      hold(175, 12);
      ramp(175, 75);
      hold(75, 8);
      ramp(75, 175);
      hold(175, 12);
      expect(c.update!.repetitions, 1);
      final emitted =
          lines.where((s) => s.startsWith('REAL_SQUAT_DECISION ')).toList();
      expect(emitted.length, expected ? 1 : 0);
      if (expected) {
        final event =
            jsonDecode(emitted.single.substring('REAL_SQUAT_DECISION '.length))
                as Map;
        expect(event['outcome'], 'full');
        expect(emitted.single.length, lessThan(3500));
        for (final word in [
          'private-member',
          'private-org',
          'landmarks',
          'worldLandmarks'
        ]) {
          expect(emitted.single, isNot(contains(word)));
        }
      }
      debugPrint = (String? text, {int? wrapWidth}) =>
          throw StateError('test log sink failed');
      ramp(175, 125);
      hold(125, 8);
      ramp(125, 175);
      hold(175, 12);
      expect(c.update!.partialRepetitions, 1);
      await c.close();
      expect(recorder.records, isEmpty);
      c.dispose();
    } finally {
      debugPrint = old;
      await c.close();
      c.dispose();
    }
  });
  testWidgets(
      'world summary survives a no-attempt hold and is suppressed after account change',
      (tester) async {
    final old = debugPrint, lines = <String>[];
    debugPrint = (String? text, {int? wrapWidth}) {
      if (text != null) lines.add(text);
    };
    final scope = SessionScope(userId: 'member', organizationId: 'org');
    SessionScope? active = scope;
    var now = 0;
    final recorder = SquatDiagnosticRecorder(compareWorldAngles: true);
    final c = SquatProcessingController(
        scope: scope,
        activeScope: () => active,
        clockMicros: () => now,
        audio: WorkoutAudioController(port: support.AudioSink()),
        sideViewConfirmed: true,
        uprightCameraConfirmed: true,
        analyzer: SquatAnalyzer(diagnostics: recorder));
    try {
      for (var i = 0; i < 15; i++) {
        now += 100000;
        c.consumeRefined(support.frame(now, 175));
      }
      await c.close();
      final summaries = lines
          .where((s) => s.startsWith('REAL_SQUAT_COMPARISON_SUMMARY '))
          .toList();
      expect(summaries.length, expectedWorld ? 1 : 0);
      if (expectedWorld) {
        final summary = jsonDecode(summaries.single
            .substring('REAL_SQUAT_COMPARISON_SUMMARY '.length)) as Map;
        expect((summary['comparison'] as Map)['matchedFrames'], 15);
        expect(summary['terminalRecords'], 0);
        expect(summaries.single.length, lessThan(3500));
      }
      c.dispose();
      final other = SquatProcessingController(
          scope: scope,
          activeScope: () => active,
          clockMicros: () => now,
          audio: WorkoutAudioController(port: support.AudioSink()),
          sideViewConfirmed: true,
          uprightCameraConfirmed: true,
          analyzer: SquatAnalyzer(
              diagnostics: SquatDiagnosticRecorder(compareWorldAngles: true)));
      now += 100000;
      other.consumeRefined(support.frame(now, 175));
      active = null;
      final before = lines.length;
      await other.close();
      other.dispose();
      expect(lines.length, before);
    } finally {
      debugPrint = old;
      await c.close();
      c.dispose();
    }
  });
}
