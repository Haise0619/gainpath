// Offline Step 2O screening only. Synthetic coordinates remain in RAM. This
// executable prints aggregates and crossing brackets; it has no camera, workout,
// persistence, upload or production configuration dependencies.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:gainpath_pose/gainpath_pose.dart';
import '../test/support/pose_joint_trajectory.dart';

const _joints = [PoseLandmark.leftElbow, PoseLandmark.leftWrist];
const _configs = [
  (name: 'control', beta: .3, cutoff: 1.0),
  (name: 'priorBeta06', beta: .6, cutoff: 1.0),
  (name: 'beta12', beta: 1.2, cutoff: 1.0),
  (name: 'cutoff15', beta: .3, cutoff: 1.5),
];

void _check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

// Integer capture timestamps, including +/-3% synthetic cadence variation.
List<int> _times(double fps, {double duration = 24}) {
  final result = <int>[];
  var time = 1000000, index = 0;
  while (time <= 1000000 + duration * 1e6) {
    result.add(time);
    time += (1e6 / fps * [1.0, .97, 1.03][index++ % 3]).round();
  }
  return result;
}

double _seconds(int time) => (time - 1000000) / 1e6;
double _progress(double t) => switch (t) {
      < 3 => 0,
      < 6 => (t - 3) / 3,
      < 8 => 1,
      < 11 => 1 - (t - 8) / 3,
      < 13 => 0,
      < 13.6 => (t - 13) / .6,
      < 16 => 1,
      < 16.6 => 1 - (t - 16) / .6,
      _ => 0,
    };

PoseFrame _frame(int time, double progress,
        {double noiseX = 0, double noiseY = 0}) =>
    PoseFrame(
      capturedAtMicros: time,
      detectorId: 'offline-only',
      modelVersion: 'synthetic-step2o',
      imageWidth: 480,
      imageHeight: 720,
      posePresence: .9,
      landmarks: {
        PoseLandmark.leftShoulder:
            const PosePoint(x: .4, y: .35, z: 0, visibility: .9, presence: .95),
        PoseLandmark.leftElbow: PosePoint(
            x: .5 + noiseX / 480,
            y: .70 - .55 * progress + noiseY / 720,
            z: 0,
            visibility: .9,
            presence: .95),
        PoseLandmark.leftWrist: PosePoint(
            x: .6 + noiseX / 480,
            y: .85 - .75 * progress + noiseY / 720,
            z: 0,
            visibility: .9,
            presence: .95),
      },
    );

List<PoseFrame> _filter(List<PoseFrame> raw, double beta, double cutoff) {
  final filter = PoseFrameFilter(beta: beta, minCutoff: cutoff);
  final result = raw.map(filter.filter).toList();
  for (var i = 0; i < raw.length; i++) {
    _check(
        result[i].capturedAtMicros == raw[i].capturedAtMicros &&
            result[i].imageWidth == raw[i].imageWidth &&
            result[i].imageHeight == raw[i].imageHeight &&
            result[i].detectorId == raw[i].detectorId &&
            result[i].modelVersion == raw[i].modelVersion &&
            result[i].posePresence == raw[i].posePresence &&
            result[i].landmarks.length == raw[i].landmarks.length,
        'Frame identity changed');
    for (final joint in _joints) {
      final r = raw[i].landmarks[joint]!, f = result[i].landmarks[joint]!;
      _check(
          f.visibility == r.visibility &&
              f.presence == r.presence &&
              [f.x, f.y, f.z].every((v) => v.isFinite),
          'Confidence/finite contract changed');
    }
  }
  return result;
}

Map<String, double> _distribution(List<double> values) {
  final sorted = values.toList()..sort();
  _check(sorted.isNotEmpty && sorted.every((v) => v.isFinite), 'Invalid stats');
  return {
    'mean': sorted.reduce((a, b) => a + b) / sorted.length,
    'rms': math.sqrt(sorted.fold(0.0, (s, v) => s + v * v) / sorted.length),
    'p50': sorted[((sorted.length - 1) * .5).ceil()],
    'p95': sorted[((sorted.length - 1) * .95).ceil()],
    'max': sorted.last,
  };
}

List<Map<String, Object>> _crossings(
    List<PoseFrame> frames, PoseLandmark joint) {
  final result = <Map<String, Object>>[];
  for (var i = 1; i < frames.length; i++) {
    final a = frames[i - 1].landmarks[joint]!.y - .35;
    final b = frames[i].landmarks[joint]!.y - .35;
    if (a > 0 && b <= 0 || a < 0 && b >= 0) {
      result.add({
        'direction': a > 0 ? 'raise' : 'lower',
        'bracketMicros': [
          frames[i - 1].capturedAtMicros,
          frames[i].capturedAtMicros
        ],
      });
    }
  }
  return result;
}

// Interval subtraction uses both endpoint uncertainties, without interpolation.
List<double> responseBracket(List<int> input, List<int> output) =>
    [(output[0] - input[1]) / 1000, (output[1] - input[0]) / 1000];

Map<String, Object> _motion(List<PoseFrame> raw, List<PoseFrame> filtered) {
  final result = <String, Object>{};
  for (final joint in _joints) {
    final errors = [
      for (var i = 0; i < raw.length; i++)
        (raw[i].landmarks[joint]!.y - filtered[i].landmarks[joint]!.y).abs() *
            720
    ];
    final phases = <String, Object>{};
    for (final phase in [
      ('slowRaise', 3.0, 6.0),
      ('slowLower', 8.0, 11.0),
      ('fastRaise', 13.0, 13.6),
      ('fastLower', 16.0, 16.6)
    ]) {
      phases[phase.$1] = _distribution([
        for (var i = 0; i < raw.length; i++)
          if (_seconds(raw[i].capturedAtMicros) > phase.$2 &&
              _seconds(raw[i].capturedAtMicros) <= phase.$3)
            errors[i]
      ]);
    }
    final rCross = _crossings(raw, joint), fCross = _crossings(filtered, joint);
    _check(rCross.length == 4 && fCross.length == 4,
        'Censored synthetic crossing');
    final crossings = <Map<String, Object>>[];
    for (var i = 0; i < 4; i++) {
      _check(rCross[i]['direction'] == fCross[i]['direction'],
          'Unmatched crossing');
      final r = rCross[i]['bracketMicros']! as List<int>;
      final f = fCross[i]['bracketMicros']! as List<int>;
      crossings.add({
        'event': ['slowRaise', 'slowLower', 'fastRaise', 'fastLower'][i],
        'refinedInputBracketMicros': r,
        'filteredInputBracketMicros': f,
        'refinedToFilteredResponseBracketMs': responseBracket(r, f),
      });
    }
    final settling = <Map<String, Object>>[];
    for (final hold in [(6.0, 8.0), (11.0, 13.0), (13.6, 16.0), (16.6, 20.0)]) {
      final indices = [
        for (var i = 0; i < raw.length; i++)
          if (_seconds(raw[i].capturedAtMicros) >= hold.$1 &&
              _seconds(raw[i].capturedAtMicros) < hold.$2)
            i
      ];
      final stable = indices.firstWhere((i) =>
          errors[i] < 1 &&
          indices.where((k) => k >= i).every((k) => errors[k] < 1));
      _check(errors[indices.last] < .02, 'Unsettled clean hold');
      settling.add({
        'holdStartSeconds': hold.$1,
        'sustainedBelow1PixelBracketMs': [
          math.max(
              0, (_seconds(raw[stable - 1].capturedAtMicros) - hold.$1) * 1000),
          (_seconds(raw[stable].capturedAtMicros) - hold.$1) * 1000,
        ],
        'finalErrorPixels': errors[indices.last],
      });
    }
    result[joint.name] = {
      'displacementImagePixels': phases,
      'crossings': crossings,
      'cleanHoldSettling': settling
    };
  }
  return result;
}

Map<String, Object> _noise(List<PoseFrame> raw, List<PoseFrame> filtered) {
  // Deviations from the known stationary truth, not F-R displacement or body drift.
  final r = <double>[], f = <double>[];
  for (var i = 0; i < raw.length; i++) {
    if (_seconds(raw[i].capturedAtMicros) < 4) continue;
    for (final pair in [('raw', raw, r), ('filtered', filtered, f)]) {
      final p = pair.$2[i].landmarks[PoseLandmark.leftElbow]!;
      pair.$3.add(math.sqrt(
          math.pow((p.x - .5) * 480, 2) + math.pow((p.y - .70) * 720, 2)));
    }
  }
  return {
    'rawRadialDeviationImagePixels': _distribution(r),
    'filteredRadialDeviationImagePixels': _distribution(f)
  };
}

Map<String, Object> _spike(
    List<int> times, double amplitude, double beta, double cutoff) {
  // One invented, accepted high-confidence prediction excursion. This is not
  // a phone observation and is separate from stationary RMS-noise screening.
  final spike = times.indexWhere((t) => _seconds(t) >= 8);
  final raw = [
    for (var i = 0; i < times.length; i++)
      _frame(times[i], 0, noiseY: i == spike ? amplitude : 0)
  ];
  final filtered = _filter(raw, beta, cutoff);
  final errors = [
    for (final f in filtered)
      (f.landmarks[PoseLandmark.leftElbow]!.y - .70).abs() * 720
  ];
  final stable = [for (var i = spike + 1; i < times.length; i++) i].firstWhere(
      (i) => errors[i] < 1 && errors.skip(i).every((error) => error < 1));
  return {
    'inventedRawSpikePixels': amplitude,
    'filteredPeakErrorPixels': errors.reduce(math.max),
    'returnInputTimestampMicros': times[spike + 1],
    'returnToSustainedBelow1PixelBracketMs': [
      (times[stable - 1] - times[spike + 1]) / 1000,
      (times[stable] - times[spike + 1]) / 1000,
    ],
  };
}

void main() {
  _check(
      PoseFrameFilter().beta == .3 &&
          PoseFrameFilter().minCutoff == 1 &&
          OneEuroFilter().dCutoff == 1,
      'Production defaults changed');
  _check(
      responseBracket([100000, 150000], [200000, 250000]).join(',') ==
          '50.0,150.0',
      'Interval subtraction incorrect');
  final legacy = syntheticArmTrajectory();
  final legacyResults = <String, Object>{};
  for (final config in _configs) {
    final filtered = _filter(legacy, config.beta, config.cutoff);
    legacyResults[config.name] = {
      for (final joint in _joints)
        joint.name: {
          for (final phase in [('slowRaise', 11, 30), ('fastRaise', 71, 75)])
            phase.$1: _distribution([
              for (var i = phase.$2; i <= phase.$3; i++)
                (filtered[i].landmarks[joint]!.y -
                            legacy[i].landmarks[joint]!.y)
                        .abs() *
                    720
            ])
        }
    };
  }
  // Fixed shortlist, not a searched optimum. beta .6 is historical context only.
  final runs = <Map<String, Object>>[];
  for (final fps in [19.0, 20.0, 21.0]) {
    final times = _times(fps);
    final motion = [for (final t in times) _frame(t, _progress(_seconds(t)))];
    final noiseInputs = <String, List<PoseFrame>>{};
    for (final amplitude in [1.0, 3.0, 8.0]) {
      for (final kind in ['white', 'slow04Hz', 'fast6Hz']) {
        final random = math.Random(421);
        noiseInputs['${kind}_${amplitude}pxAxisRms'] = [
          for (final t in times)
            _frame(t, 0,
                noiseX: kind == 'white'
                    ? (random.nextDouble() * 2 - 1) * math.sqrt(3) * amplitude
                    : math.sqrt(2) *
                        amplitude *
                        math.sin(2 *
                            math.pi *
                            (kind == 'slow04Hz' ? .4 : 6) *
                            _seconds(t)),
                noiseY: kind == 'white'
                    ? (random.nextDouble() * 2 - 1) * math.sqrt(3) * amplitude
                    : math.sqrt(2) *
                        amplitude *
                        math.cos(2 *
                            math.pi *
                            (kind == 'slow04Hz' ? .4 : 6) *
                            _seconds(t)))
        ];
      }
    }
    final configs = <String, Object>{};
    for (final config in _configs) {
      final constant = [for (final t in times) _frame(t, 0)];
      final dc = _filter(constant, config.beta, config.cutoff);
      _check(
          dc.every((f) =>
              (f.landmarks[PoseLandmark.leftWrist]!.y - .85).abs() < 1e-12),
          'Stationary constant changed');
      configs[config.name] = {
        'parameters': {
          'beta': config.beta,
          'minCutoff': config.cutoff,
          'derivativeCutoff': 1
        },
        'motion': _motion(motion, _filter(motion, config.beta, config.cutoff)),
        'acceptedPredictionSpikeProxies': [
          for (final amplitude in [25.0, 50.0])
            _spike(times, amplitude, config.beta, config.cutoff)
        ],
        'heldNoiseProxies': {
          for (final entry in noiseInputs.entries)
            entry.key: _noise(
                entry.value, _filter(entry.value, config.beta, config.cutoff))
        },
      };
    }
    runs.add({
      'syntheticNominalFps': fps,
      'frames': times.length,
      'configs': configs
    });
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert({
    'scope':
        'Synthetic offline screening; not physical jitter or camera/display latency',
    'coordinates':
        'Upright unmirrored image-normalized x/480, y/720; confidence preserved',
    'inputTiming':
        'Actual integer fixture capture timestamps, +/-3% cadence variation',
    'motion':
        'Same continuous Step 2J trajectory; slow ramp 3s, fast ramp .6s, exact holds',
    'noise':
        'Seed 421 white uniform or .4/6Hz quadrature sinusoid; nominal per-axis RMS 1/3/8px; first 4s excluded',
    'checks':
        'Frozen defaults, interval subtraction, same-frame identity/confidence, finite values, DC preservation, four matched crossings per stage, clean hold convergence',
    'retainedStep2DFixture': {
      'source':
          'test/support/pose_joint_trajectory.dart (synthetic, 95 frames)',
      'frames': legacy.length,
      'configs': legacyResults,
    },
    'runs': runs,
  }));
}
