import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/infrastructure/pose/blazepose_contract.dart';
import 'package:gainpath_mobile/infrastructure/pose/blazepose_gpu.dart';
import 'package:gainpath_mobile/infrastructure/pose/pose_backend_agreement.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('gainpath/blazepose_gpu');
  final calls = <String>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'invoke') {
        return {
          'ownerThread': 17,
          'nativeMicros': 100,
          'copyMicros': 20,
          'outputs': [
            Uint8List(195 * 4),
            Uint8List(4),
            Uint8List(64 * 64 * 39 * 4),
            Uint8List(117 * 4)
          ]
        };
      }
      return null;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  test('automatic acceleration falls back after unsupported GPU is cleaned up',
      () async {
    final result =
        await BlazePoseGpuSession.createPreferred('optional', ['d', 'l']);
    expect(result, isNull);
    expect(calls, ['create', 'close']);
  });

  test('explicit GPU diagnostic still fails rather than reporting CPU as GPU',
      () async {
    await expectLater(
        BlazePoseGpuSession.createPreferred('required', ['d', 'l'],
            requireGpu: true),
        throwsStateError);
    expect(calls, ['create', 'close']);
  });

  test(
      'automatic acceleration retains the verified native session when available',
      () async {
    Map<String, Object> spec(PoseTensorSpec tensor) =>
        {'name': tensor.name, 'shape': tensor.shape, 'type': tensor.type};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method != 'create') return null;
      return {
        'backend': 'opencl_required',
        'ownerThread': 17,
        'models': [
          for (final contract in [
            BlazePoseModelContract.detector,
            BlazePoseModelContract.landmark
          ])
            {
              'inputs': [spec(contract.input)],
              'outputs': contract.outputs.map(spec).toList()
            },
        ]
      };
    });
    final session =
        await BlazePoseGpuSession.createPreferred('available', ['d', 'l']);
    expect(session, isNotNull);
    expect(session!.ownerThread, 17);
    await session.close();
    expect(calls, ['create', 'close']);
  });

  test('native inventory validates every output including unused segmentation',
      () {
    Map<String, Object> spec(PoseTensorSpec s) =>
        {'name': s.name, 'shape': s.shape, 'type': s.type};
    const c = BlazePoseModelContract.landmark;
    validateGpuInventory(c, {
      'inputs': [spec(c.input)],
      'outputs': c.outputs.map(spec).toList()
    });
    expect(
        () => validateGpuInventory(c, {
              'inputs': [spec(c.input)],
              'outputs': c.outputs.take(4).map(spec).toList()
            }),
        throwsStateError);
  });
  test('bounded agreement packets survive Android log truncation limits', () {
    final value = {
      'framePairs': 12,
      'complete': true,
      'tensorMaxAbsoluteDifference': {
        for (var n = 0; n < 6; n++) 'tensor_$n': .000640869140625
      },
      'padding': List.filled(600, 'scalar').join()
    };
    final lines = gpuAgreementLogRecords('pose-123', value);
    expect(lines.every((s) => s.length <= 700), true);
    final packets =
        lines.map((s) => jsonDecode(s.split(' ').last) as Map).toList();
    final joined = packets.map((p) => p['base64'] as String).join();
    expect(jsonDecode(utf8.decode(base64Decode(joined))), value);
    expect(packets.every((p) => p['parts'] == lines.length), true);
  });
  test('bounded adapter checks byte count and rejects invocation after close',
      () async {
    final gpu = BlazePoseGpuSession('test', ownerThread: 17);
    await expectLater(gpu.invoke(1, Float32List(1)), throwsArgumentError);
    expect(calls, isEmpty);
    final result = await gpu.invoke(1, Float32List(256 * 256 * 3));
    expect(result.outputs[3]!.length, 64 * 64 * 39);
    expect(result.nativeMicros, 100);
    await gpu.close();
    await gpu.close();
    expect(calls, ['invoke', 'close']);
    await expectLater(
        gpu.invoke(1, Float32List(256 * 256 * 3)), throwsStateError);
  });
  test('adapter rejects changed owner thread and truncated output', () async {
    final gpu = BlazePoseGpuSession('test', ownerThread: 19);
    await expectLater(
        gpu.invoke(1, Float32List(256 * 256 * 3)), throwsStateError);
  });
  test('busy call is rejected and closing cannot resurrect a late result',
      () async {
    final reply = Completer<Map<String, Object>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'invoke') return reply.future;
      return null;
    });
    final gpu = BlazePoseGpuSession('late', ownerThread: 17);
    final active = gpu.invoke(0, Float32List(224 * 224 * 3));
    await expectLater(
        gpu.invoke(0, Float32List(224 * 224 * 3)), throwsStateError);
    await gpu.close();
    reply.complete({
      'ownerThread': 17,
      'nativeMicros': 1,
      'copyMicros': 1,
      'outputs': [Uint8List(2254 * 12 * 4), Uint8List(2254 * 4)]
    });
    await active;
    await expectLater(
        gpu.invoke(0, Float32List(224 * 224 * 3)), throwsStateError);
    expect(calls, ['invoke', 'close']);
  });
  test('malformed output and initialization inventory cleanly fail', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'create') {
        return {'backend': 'opencl_required', 'ownerThread': 17, 'models': []};
      }
      if (call.method == 'invoke') {
        return {
          'ownerThread': 17,
          'nativeMicros': 1,
          'copyMicros': 1,
          'outputs': [Uint8List(1), Uint8List(4), Uint8List(4), Uint8List(4)]
        };
      }
      return null;
    });
    await expectLater(
        BlazePoseGpuSession.create('bad', ['d', 'l']), throwsStateError);
    expect(calls, ['create', 'close']);
    await expectLater(
        BlazePoseGpuSession('bad', ownerThread: 17)
            .invoke(1, Float32List(256 * 256 * 3)),
        throwsStateError);
  });
  PoseFrame frame(int timestamp, double x, double visibility) => PoseFrame(
          capturedAtMicros: timestamp,
          detectorId: 'fixture',
          modelVersion: 'same',
          imageWidth: 1000,
          imageHeight: 500,
          posePresence: .9,
          landmarks: {
            PoseLandmark.leftElbow: PosePoint(
                x: x, y: .5, z: 0, visibility: visibility, presence: 1)
          });
  test(
      'agreement uses matched timestamps and pixel units; boundary flips censored',
      () {
    final agreement = PoseBackendAgreement(limit: 2);
    agreement.observeFrames(frame(1, .5, .4999), frame(1, .5005, .5001));
    final s = agreement.snapshot;
    expect(s['maxImagePixelDistance'], closeTo(.5, 1e-9));
    expect(s['acceptanceFlips'], 1);
    expect(s['boundaryAcceptanceFlips'], 1);
    expect(() => agreement.observeFrames(frame(2, .5, 1), frame(3, .5, 1)),
        throwsArgumentError);
    agreement.observeFrames(frame(2, .5, 1), frame(2, .502, 1));
    expect(agreement.snapshot['withinProvisionalLimits'], false);
    expect(agreement.complete, true);
    agreement.observeFrames(frame(4, .5, 1), frame(4, .7, 1));
    expect(agreement.snapshot['framePairs'], 2);
  });
  test(
      'nonfinite consumed tensors fail agreement without saving tensor streams',
      () {
    final a = PoseBackendAgreement();
    a.observeTensor('landmark0', Float32List.fromList([1, 2]),
        Float32List.fromList([1, double.nan]));
    expect(a.snapshot['nonfiniteValues'], 1);
    expect(a.snapshot['withinProvisionalLimits'], false);
    expect(a.snapshot.toString(), isNot(contains('NaN')));
  });
}
