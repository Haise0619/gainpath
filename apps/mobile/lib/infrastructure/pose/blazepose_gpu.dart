import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'blazepose_contract.dart';

const poseGpuDebugEnabled =
    !kReleaseMode && bool.fromEnvironment('GAINPATH_POSE_GPU');
const poseGpuCompareEnabled =
    poseGpuDebugEnabled && bool.fromEnvironment('GAINPATH_POSE_GPU_COMPARE');
const _channel = MethodChannel('gainpath/blazepose_gpu');

/// One report per bounded comparison. Small ASCII packets avoid the observed
/// Android/Flutter log-line truncation; payload contains scalar aggregates only.
List<String> gpuAgreementLogRecords(String session, Map<String, Object> value) {
  final data = base64Encode(utf8.encode(jsonEncode(value)));
  final count = (data.length / 400).ceil();
  return List.generate(count, (part) {
    final end = (part + 1) * 400 < data.length ? (part + 1) * 400 : data.length;
    return 'POSE_GPU_AGREEMENT ${jsonEncode({
          'session': session,
          'part': part,
          'parts': count,
          'base64': data.substring(part * 400, end)
        })}';
  });
}

void validateGpuInventory(BlazePoseModelContract contract, Map inventory) {
  PoseTensorSpec spec(dynamic item) {
    final s = item as Map;
    return PoseTensorSpec(s['name'] as String,
        List<int>.from(s['shape'] as List), s['type'] as String);
  }

  final inputs = inventory['inputs'] as List;
  if (inputs.length != 1) throw StateError('GPU input inventory mismatch');
  contract.validate(
      spec(inputs.single), (inventory['outputs'] as List).map(spec).toList());
}

class GpuPoseOutputs {
  GpuPoseOutputs(
      this.outputs, this.nativeMicros, this.copyMicros, this.roundTripMicros);
  final Map<int, Float32List> outputs;
  final int nativeMicros, copyMicros, roundTripMicros;
}

/// Transport only. Android owns both interpreters on one OS thread. Input and
/// consumed output bytes exist only for this invocation; no recording API.
class BlazePoseGpuSession {
  BlazePoseGpuSession(this.id, {required this.ownerThread});
  final String id;
  final int ownerThread;
  Future<void>? _closed;
  bool _active = false;

  static Future<BlazePoseGpuSession> create(
      String id, List<String> paths) async {
    try {
      final info = await _channel.invokeMapMethod<String, Object?>(
          'create', {'session': id, 'paths': paths});
      if (info == null || info['backend'] != 'opencl_required') {
        throw StateError('GPU backend not verified');
      }
      final models = info['models'] as List;
      if (models.length != 2) throw StateError('GPU model inventory mismatch');
      validateGpuInventory(BlazePoseModelContract.detector, models[0] as Map);
      validateGpuInventory(BlazePoseModelContract.landmark, models[1] as Map);
      return BlazePoseGpuSession(id, ownerThread: info['ownerThread'] as int);
    } catch (_) {
      await closeId(id);
      rethrow;
    }
  }

  static Future<void> closeId(String id) =>
      _channel.invokeMethod<void>('close', {'session': id});

  Future<void> close() => _closed ??= closeId(id);

  Future<GpuPoseOutputs> invoke(int model, Float32List tensor) async {
    if (_closed != null || _active) {
      throw StateError('GPU session closed or busy');
    }
    if (model != 0 && model != 1) throw ArgumentError('GPU model index');
    final contract = model == 0
        ? BlazePoseModelContract.detector
        : BlazePoseModelContract.landmark;
    final count = contract.input.shape.reduce((a, b) => a * b);
    if (tensor.length != count) throw ArgumentError('GPU input element count');
    _active = true;
    final timer = Stopwatch()..start();
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('invoke', {
        'session': id,
        'model': model,
        'input': tensor.buffer
            .asUint8List(tensor.offsetInBytes, tensor.lengthInBytes)
      });
      if (result == null || result['ownerThread'] != ownerThread) {
        throw StateError('GPU invocation owner mismatch');
      }
      final indices = model == 0 ? [0, 1] : [0, 1, 3, 4];
      final bytes = result['outputs'] as List;
      if (bytes.length != indices.length) throw StateError('GPU output count');
      final outputs = <int, Float32List>{};
      for (var i = 0; i < indices.length; i++) {
        final data = bytes[i] as Uint8List, index = indices[i];
        final expected =
            contract.outputs[index].shape.reduce((a, b) => a * b) * 4;
        if (data.length != expected) throw StateError('GPU output byte count');
        // Codec byte views need not have four-byte aligned offsets.
        outputs[index] = Uint8List.fromList(data).buffer.asFloat32List();
      }
      return GpuPoseOutputs(outputs, result['nativeMicros'] as int,
          result['copyMicros'] as int, timer.elapsedMicroseconds);
    } finally {
      _active = false;
    }
  }
}
