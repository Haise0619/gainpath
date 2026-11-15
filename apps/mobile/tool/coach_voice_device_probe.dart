// Explicit local device probe only; normal main.dart never imports this file.
// Build: flutter build apk --debug --target-platform android-arm64
//   --target tool/coach_voice_device_probe.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/infrastructure/audio/android_workout_audio.dart';
import 'package:gainpath_mobile/features/workout/domain/coach_voice_catalog.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_audio_trace.dart';

void main() {
  if (kReleaseMode) throw StateError('Debug device probe only');
  runApp(const MaterialApp(home: Probe()));
}

class Probe extends StatefulWidget {
  const Probe({super.key});
  @override
  State<Probe> createState() => _ProbeState();
}

class _ProbeState extends State<Probe> with WidgetsBindingObserver {
  final rows = <Map<String, Object?>>[];
  AndroidWorkoutAudio newPort() =>
      AndroidWorkoutAudio(trace: WorkoutAudioTrace(onRecord: (row) {
        debugPrint('COACH_VOICE_TRACE ${jsonEncode(row)}');
      }));
  AndroidWorkoutAudio? _port;
  bool _running = false, _done = false;
  String status = 'Preparing offline coach playback';
  void report(String name, Object? value) {
    final row = <String, Object?>{'check': name, 'result': value};
    rows.add(row);
    debugPrint('COACH_VOICE_PROBE ${jsonEncode(row)}');
    if (mounted) setState(() => status = '$name: $value');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(run()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_done && !_running) {
      unawaited(run());
    }
  }

  CueRequest cue(String id, {String? text}) => CueRequest(
      id: id,
      text: text ?? coachVoiceCatalog[id]!.text,
      priority: CuePriority.encouragement);
  Future<void> run() async {
    if (_running) return;
    _running = true;
    final port = _port = newPort();
    await Future<void>.delayed(const Duration(seconds: 2));
    try {
      final ready = await port.prepare();
      report('prepare', ready);
      if (!ready) {
        report('waiting_for_foreground', true);
        return;
      }
      // Exercise both PCM numbers and compressed phrases on actual Android.
      for (final id in [
        'ready_v1',
        'number_001',
        'number_012',
        'number_030',
        'squat_depth_v1',
        'encourage_rep_v2',
        'rest_begin_v1',
        'next_exercise_v1',
        'workout_complete_v1'
      ]) {
        report(
            id,
            (await port.playCurrent(cue(id),
                    requestId: id,
                    remainingStartTime: const Duration(milliseconds: 250)))
                .name);
      }
      // Cold offline fallback initialization may outlive a rep's start budget.
      // This explicit dynamic-text check gives preparation its own window.
      report('dynamic31',
          (await port.play(cue('number_dynamic', text: '31'))).name);
      report(
          'missing_asset',
          (await port.play(
                  cue('probe_missing_asset', text: 'Offline fallback ready.')))
              .name);
      final obsolete = port.playCurrent(cue('number_002'),
          requestId: 'rapid-old',
          remainingStartTime: const Duration(milliseconds: 250));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await port.stop();
      final latest = port.playCurrent(cue('number_003'),
          requestId: 'rapid-new',
          remainingStartTime: const Duration(milliseconds: 250));
      report('rapid_old', (await obsolete).name);
      report('rapid_new', (await latest).name);
      final interrupted = port.play(cue('next_exercise_v1'));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await port.stop();
      report('pause_cancel', (await interrupted).name);
      report(
          'expired',
          (await port.playCurrent(cue('number_004'),
                  requestId: 'expired', remainingStartTime: Duration.zero))
              .name);
      await port.close();
      report('after_close', (await port.play(cue('number_005'))).name);
      report('done', true);
      _done = true;
    } catch (error) {
      report('error', '$error');
      await port.close();
    } finally {
      await port.close();
      _running = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_port != null) unawaited(_port!.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: const Color(0xfff7f3ff),
      body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.headphones,
                        color: Color(0xff6d28d9), size: 48),
                    const SizedBox(height: 20),
                    const Text('Offline coach playback check',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(status),
                    const SizedBox(height: 12),
                    const Text(
                        'Local audio only. No camera, account or workout records are opened. The normal app will be restored after this check.'),
                    const SizedBox(height: 16),
                    Expanded(
                        child: ListView(
                            children: rows
                                .map((row) =>
                                    Text('${row['check']}: ${row['result']}'))
                                .toList())),
                  ]))));
}
