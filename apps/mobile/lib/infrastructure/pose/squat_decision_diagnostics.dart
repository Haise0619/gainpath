import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

const squatDecisionDiagnosticsEnabled =
    !kReleaseMode && bool.fromEnvironment('GAINPATH_SQUAT_DECISIONS');
const squatWorldComparisonEnabled = squatDecisionDiagnosticsEnabled &&
    bool.fromEnvironment('GAINPATH_SQUAT_3D_COMPARE');

SquatDiagnosticRecorder? createSquatDiagnosticRecorder() =>
    squatDecisionDiagnosticsEnabled
        ? SquatDiagnosticRecorder(
            compareWorldAngles: squatWorldComparisonEnabled)
        : null;

/// Best-effort terminal summaries only. Telemetry failure cannot interrupt a rep.
int emitSquatDecisionRecords(
    SquatDiagnosticRecorder? recorder, int afterSequence) {
  if (!squatDecisionDiagnosticsEnabled ||
      recorder == null ||
      recorder.totalRecords <= afterSequence) {
    return afterSequence;
  }
  for (final record in recorder.records) {
    if (record.sequence <= afterSequence) continue;
    afterSequence = record.sequence;
    try {
      debugPrint('REAL_SQUAT_DECISION ${jsonEncode(record.toJson())}');
    } catch (_) {
      // Retained bounded summaries remain inspectable; never change decisions.
    }
  }
  return afterSequence;
}

void emitSquatComparisonSummary(SquatDiagnosticRecorder? recorder) {
  if (!squatWorldComparisonEnabled ||
      recorder == null ||
      !recorder.compareWorldAngles) {
    return;
  }
  try {
    debugPrint(
        'REAL_SQUAT_COMPARISON_SUMMARY ${jsonEncode(recorder.sessionSummary())}');
  } catch (_) {
    // Diagnostic reporting never blocks cleanup or durable result saving.
  }
}
