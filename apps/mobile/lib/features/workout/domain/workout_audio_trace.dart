import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Local debug timing only. Clock domains stay explicit: Dart elapsed time and
/// Android elapsedRealtime must never be subtracted directly from each other.
class WorkoutAudioTrace {
  WorkoutAudioTrace({int Function()? clockMicros, this.onRecord})
      : _clock = clockMicros ?? (Stopwatch()..start()).elapsedMicrosecondsValue;

  static const enabled =
      !kReleaseMode && bool.fromEnvironment('GAINPATH_WORKOUT_AUDIO_TRACE');
  final int Function() _clock;
  final void Function(Map<String, Object?>)? onRecord;
  final _records = Queue<Map<String, Object?>>();
  List<Map<String, Object?>> get records => List.unmodifiable(_records);

  void record(String stage,
      {String? requestId,
      String? cueId,
      String? reason,
      int? observedAtMicros,
      int? nativeElapsedMicros}) {
    if (kReleaseMode) return;
    final row = Map<String, Object?>.unmodifiable({
      'stage': stage,
      'dartElapsedMicros': _clock(),
      if (requestId != null) 'requestId': requestId,
      if (cueId != null) 'cueId': cueId,
      if (reason != null) 'reason': reason,
      if (observedAtMicros != null) 'observedAtMicros': observedAtMicros,
      if (nativeElapsedMicros != null)
        'nativeElapsedMicros': nativeElapsedMicros,
    });
    if (_records.length >= 256) _records.removeFirst();
    _records.add(row);
    onRecord?.call(row);
  }
}

extension on Stopwatch {
  int elapsedMicrosecondsValue() => elapsedMicroseconds;
}
