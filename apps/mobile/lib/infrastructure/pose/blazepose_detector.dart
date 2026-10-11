import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'blazepose_contract.dart';
import 'blazepose_gpu.dart';
import 'pose_backend_agreement.dart';
import 'blazepose_assets.dart';
import 'blazepose_decode.dart';
import 'blazepose_geometry.dart';
import 'pose_render_diagnostics.dart';
import 'pose_quality_diagnostics.dart';

/// Persistent background ingestion/inference worker. Assets are verified before
/// native execution; only bounded frame work is sent by the application scheduler.
class BlazePoseDetector
    implements ManagedPoseDetector, PoseDetectorDiagnostics {
  BlazePoseDetector._(this.quality);
  final PoseQualityDiagnostics? quality;
  final _messages = ReceivePort();
  final _errors = ReceivePort();
  final _exit = ReceivePort();
  final _ready = Completer<SendPort>();
  final _closed = Completer<void>();
  final _requests = <int, Completer<Object?>>{};
  Isolate? _worker;
  SendPort? _commands;
  String? _gpuSessionId;
  Map<String, Object> _gpuDiagnostics = {};
  bool _agreementPrinted = false;
  bool _closing = false;
  bool _failed = false;
  int _nextId = 0;
  int nativeInferenceMicros = 0, pipelineMicros = 0, measuredFrames = 0;
  Map<String, Object?> _renderDecoder = {};
  double get averageInferenceMillis =>
      measuredFrames == 0 ? 0 : nativeInferenceMicros / measuredFrames / 1000;
  double get averagePipelineMillis =>
      measuredFrames == 0 ? 0 : pipelineMicros / measuredFrames / 1000;
  @override
  Map<String, Object> get diagnostics => {
        if (poseRenderDebugEnabled) 'renderDecoder': _renderDecoder,
        'modelVersion': BlazePoseModelContract.version,
        'inferenceBackend':
            poseGpuDebugEnabled ? 'opencl_required' : 'cpu_2_threads',
        if (poseGpuDebugEnabled)
          'gpuOwnerThread': _gpuDiagnostics['ownerThread'] ?? 0,
        'runtimeTensorContractVerified': true,
        'averageInferenceMillis': averageInferenceMillis,
        'averagePipelineMillis': averagePipelineMillis,
        'measuredFrames': measuredFrames,
      };

  static Future<BlazePoseDetector> create(
      {PoseQualityDiagnostics? quality}) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Real pose preview currently requires Android.');
    }
    final detector = BlazePoseDetector._(quality);
    detector._messages.listen(detector._onMessage);
    detector._errors
        .listen((_) => detector._fail(StateError('BlazePose worker failed.')));
    detector._exit.listen((_) {
      if (!detector._closing) {
        detector._fail(StateError('BlazePose worker exited.'));
      }
    });
    try {
      final assets = <String>[];
      final support = await getApplicationSupportDirectory();
      final models = Directory('${support.path}/pose_models');
      for (final contract in [
        BlazePoseModelContract.detector,
        BlazePoseModelContract.landmark
      ]) {
        final file = await prepareBlazePoseAsset(contract, models, () async {
          final data = await rootBundle.load(contract.assetPath);
          return data.buffer
              .asUint8List(data.offsetInBytes, data.lengthInBytes);
        });
        assets.add(file.path);
      }
      if (poseGpuDebugEnabled) {
        detector._gpuSessionId =
            'pose-${DateTime.now().microsecondsSinceEpoch}';
      }
      detector._worker = await Isolate.spawn(
          _blazePoseWorker,
          (
            detector._messages.sendPort,
            assets,
            detector._gpuSessionId,
            RootIsolateToken.instance
          ),
          onError: detector._errors.sendPort,
          onExit: detector._exit.sendPort);
      detector._commands =
          await detector._ready.future.timeout(const Duration(seconds: 30));
      return detector;
    } catch (_) {
      try {
        if (detector._gpuSessionId != null) {
          await BlazePoseGpuSession.closeId(detector._gpuSessionId!);
        }
      } finally {
        detector._worker?.kill(priority: Isolate.immediate);
        detector._messages.close();
        detector._errors.close();
        detector._exit.close();
      }
      rethrow;
    }
  }

  void _fail(Object error) {
    _failed = true;
    if (_gpuSessionId != null) {
      unawaited(BlazePoseGpuSession.closeId(_gpuSessionId!)
          .catchError((Object _) {}));
    }
    if (!_ready.isCompleted) _ready.completeError(error);
    for (final pending in _requests.values) {
      if (!pending.isCompleted) pending.completeError(error);
    }
    _requests.clear();
    if (_closing && !_closed.isCompleted) _closed.complete();
  }

  void _onMessage(dynamic message) {
    final values = message as List;
    if (values[0] == 'ready') {
      if (values.length > 2) {
        _gpuDiagnostics = Map<String, Object>.from(values[2] as Map);
      }
      _ready.complete(values[1] as SendPort);
      return;
    }
    if (values[0] == 'failure') {
      _fail(StateError(values[1] as String));
      return;
    }
    if (values[0] == 'closed') {
      if (!_closed.isCompleted) _closed.complete();
      return;
    }
    final pending = _requests.remove(values[1] as int);
    if (pending == null) return;
    if (values[0] == 'error') {
      pending.completeError(StateError(values[2] as String));
      if (_gpuSessionId != null) _fail(StateError(values[2] as String));
    } else {
      if (values.length > 3) {
        nativeInferenceMicros += values[3] as int;
        pipelineMicros += values[4] as int;
        measuredFrames++;
        if (values.length > 7 && values[7] != null) {
          _gpuDiagnostics['sameInputAgreement'] = values[7];
          final agreement = Map<String, Object>.from(values[7] as Map);
          if (!_agreementPrinted && agreement['cpuShadowClosed'] == true) {
            _agreementPrinted = true;
            for (final line
                in gpuAgreementLogRecords(_gpuSessionId!, agreement)) {
              debugPrint(line);
            }
          }
        }
        if (values.length > 5) {
          _renderDecoder = Map<String, Object?>.from(values[5] as Map);
        }
        if (values.length > 6) {
          quality?.workerFrame(Map<String, Object?>.from(values[6] as Map));
        }
      }
      pending.complete(values[2]);
    }
  }

  Future<Object?> _request(String kind, [PoseInput? input]) {
    if (_closing || _failed || _commands == null) {
      throw StateError('Pose detector is closed.');
    }
    // Defense in depth: do not permit a second native invocation to queue.
    if (_requests.isNotEmpty) {
      throw StateError('Pose detector already has an active command.');
    }
    final id = _nextId++;
    final pending = Completer<Object?>();
    _requests[id] = pending;
    _commands!.send([kind, id, input]);
    return pending.future;
  }

  @override
  Future<PoseFrame> detect(PoseInput input) async {
    if (input.image == null) {
      throw ArgumentError('BlazePose requires a camera image snapshot.');
    }
    return await _request('frame', input) as PoseFrame;
  }

  @override
  Future<void> reset() async {
    await _request('reset');
  }

  @override
  Future<void> close() async {
    if (_closing) {
      await _closed.future;
      return;
    }
    _closing = true;
    if (_requests.isNotEmpty) {
      await Future.wait(_requests.values
          .map((r) => r.future.catchError((_) => null))
          .toList());
    }
    _commands?.send(['close']);
    if (_failed && !_closed.isCompleted) _closed.complete();
    try {
      await _closed.future.timeout(const Duration(seconds: 10));
    } finally {
      try {
        if (_gpuSessionId != null) {
          await BlazePoseGpuSession.closeId(_gpuSessionId!);
        }
      } finally {
        _worker?.kill(priority: Isolate.immediate);
        _messages.close();
        _errors.close();
        _exit.close();
        if (!_closed.isCompleted) _closed.complete();
      }
    }
  }
}

void _blazePoseWorker(
    (SendPort, List<String>, String?, RootIsolateToken?) boot) async {
  final replies = boot.$1, commands = ReceivePort();
  Interpreter? detector, landmark;
  BlazePoseGpuSession? gpu;
  final agreement = poseGpuCompareEnabled ? PoseBackendAgreement() : null;
  var detectorPairs = 0, comparisonAttempts = 0;
  int? comparisonWaitStart, firstComparisonInput, lastComparisonInput;
  var compareClosed = false;
  final options = InterpreterOptions()..threads = 2;
  try {
    if (boot.$3 != null) {
      if (boot.$4 == null) throw StateError('Missing root isolate messenger');
      BackgroundIsolateBinaryMessenger.ensureInitialized(boot.$4!);
      gpu = await BlazePoseGpuSession.create(boot.$3!, boot.$2);
    }
    if (gpu == null || poseGpuCompareEnabled) {
      detector = Interpreter.fromFile(File(boot.$2[0]), options: options);
      landmark = Interpreter.fromFile(File(boot.$2[1]), options: options);
      for (final pair in [
        (detector, BlazePoseModelContract.detector),
        (landmark, BlazePoseModelContract.landmark)
      ]) {
        PoseTensorSpec spec(Tensor t) =>
            PoseTensorSpec(t.name, t.shape, t.type.name);
        if (pair.$1.getInputTensors().length != 1) {
          throw StateError('BlazePose requires one input tensor.');
        }
        pair.$2.validate(spec(pair.$1.getInputTensor(0)),
            pair.$1.getOutputTensors().map(spec).toList());
      }
    }
  } catch (error) {
    try {
      await gpu?.close();
    } finally {
      detector?.close();
      landmark?.close();
      commands.close();
      replies.send([
        'failure',
        boot.$3 == null
            ? 'BlazePose native initialization or tensor validation failed.'
            : 'BlazePose OpenCL initialization failed: $error'
      ]);
    }
    return;
  } finally {
    options.delete();
  }
  final detectionInterpreter = detector, landmarkInterpreter = landmark;
  TensorImageTransform? roi;
  (int, int, int)? geometry;
  var roiFrames = 0;
  double? lastDetectorConfidence;
  int? lastDetectorTimestamp;
  replies.send([
    'ready',
    commands.sendPort,
    if (gpu != null)
      {
        'backend': 'opencl_required',
        'ownerThread': gpu.ownerThread,
        'sameInputComparisonEnabled': poseGpuCompareEnabled
      }
  ]);
  commands.listen((dynamic message) async {
    final values = message as List;
    if (values[0] == 'close') {
      await gpu?.close();
      if (!compareClosed) {
        detectionInterpreter?.close();
        landmarkInterpreter?.close();
      }
      commands.close();
      replies.send(['closed']);
      return;
    }
    final id = values[1] as int;
    if (values[0] == 'reset') {
      roi = null;
      geometry = null;
      roiFrames = 0;
      lastDetectorConfidence = null;
      lastDetectorTimestamp = null;
      replies.send(['result', id, null]);
      return;
    }
    final input = values[2] as PoseInput;
    final total = Stopwatch()..start();
    var nativeMicros = 0;
    final timings = <String, int>{};
    T measured<T>(String name, T Function() action) {
      if (!poseQualityDebugEnabled) return action();
      final timer = Stopwatch()..start();
      final result = action();
      timings.update(name, (v) => v + timer.elapsedMicroseconds,
          ifAbsent: () => timer.elapsedMicroseconds);
      return result;
    }

    try {
      final image = input.image!;
      final currentGeometry =
          (image.width, image.height, image.rotationDegrees);
      if (currentGeometry != geometry) {
        roi = null;
        geometry = currentGeometry;
        roiFrames = 0;
      }
      final width = image.uprightWidth, height = image.uprightHeight;
      Float32List invoke(Interpreter interpreter, Float32List tensor, int index,
          String stage) {
        measured(
            'tensorIoMicros',
            () => interpreter.getInputTensor(0).data =
                tensor.buffer.asUint8List());
        final timer = Stopwatch()..start();
        interpreter.invoke();
        final elapsed = timer.elapsedMicroseconds;
        nativeMicros += elapsed;
        if (poseQualityDebugEnabled) {
          timings['${stage}InferenceMicros'] = elapsed;
        }
        return measured(
            'tensorIoMicros',
            () => Float32List.fromList(interpreter
                .getOutputTensor(index)
                .data
                .buffer
                .asFloat32List()));
      }

      comparisonWaitStart ??= input.timestampMicros;
      final comparing = agreement != null &&
          !compareClosed &&
          input.timestampMicros - comparisonWaitStart! >= 5000000;
      if (comparing) {
        comparisonAttempts++;
        firstComparisonInput ??= input.timestampMicros;
        lastComparisonInput = input.timestampMicros;
      }
      GpuPoseOutputs? detectorGpuOutputs, landmarkGpuOutputs;
      final cpuOutputs = <int, Float32List>{};
      Future<Float32List> invokeGpu(
          int model, Float32List tensor, String stage) async {
        final result = await gpu!.invoke(model, tensor);
        if (model == 0) {
          detectorGpuOutputs = result;
        } else {
          landmarkGpuOutputs = result;
        }
        nativeMicros += result.nativeMicros;
        timings['${stage}InferenceMicros'] = result.nativeMicros;
        timings.update('gpuNativeCopyMicros', (v) => v + result.copyMicros,
            ifAbsent: () => result.copyMicros);
        timings.update('gpuRoundTripMicros', (v) => v + result.roundTripMicros,
            ifAbsent: () => result.roundTripMicros);
        timings.update(
            'gpuTransportAndQueueMicros',
            (v) =>
                v +
                result.roundTripMicros -
                result.nativeMicros -
                result.copyMicros,
            ifAbsent: () =>
                result.roundTripMicros -
                result.nativeMicros -
                result.copyMicros);
        if (comparing) {
          final shadow =
              model == 0 ? detectionInterpreter! : landmarkInterpreter!;
          final shadowTimer = Stopwatch()..start();
          shadow.getInputTensor(0).data = tensor.buffer.asUint8List();
          shadow.invoke();
          cpuOutputs.clear();
          for (final index in result.outputs.keys) {
            final value = Float32List.fromList(
                shadow.getOutputTensor(index).data.buffer.asFloat32List());
            cpuOutputs[index] = value;
            agreement.observeTensor(
                '${stage}_$index', value, result.outputs[index]!);
          }
          timings.update('cpuShadowComparisonMicros',
              (v) => v + shadowTimer.elapsedMicroseconds,
              ifAbsent: () => shadowTimer.elapsedMicroseconds);
        }
        return result.outputs[0]!;
      }

      final detectorRan = roi == null || roiFrames >= 15;
      final detectionTrace = <String, Object?>{};
      if (detectorRan) {
        final transform = TensorImageTransform.fullFrame(width, height);
        final tensor = measured(
            'detectorPreprocessMicros',
            () => preprocessImage(image, transform, 224,
                minimum: -1, maximum: 1));
        final boxes = gpu == null
            ? invoke(detectionInterpreter!, tensor, 0, 'detector')
            : await invokeGpu(0, tensor, 'detector');
        final decodeTimer = Stopwatch()..start();
        final scores = detectorGpuOutputs?.outputs[1] ??
            Float32List.fromList(detectionInterpreter!
                .getOutputTensor(1)
                .data
                .buffer
                .asFloat32List());
        roi = decodePoseDetection(boxes, scores, transform,
            diagnostics: poseQualityDebugEnabled ? detectionTrace : null);
        if (comparing) {
          agreement.observeRoi(
              decodePoseDetection(cpuOutputs[0]!, cpuOutputs[1]!, transform),
              roi);
          detectorPairs++;
        }
        if (poseQualityDebugEnabled) {
          timings['detectorDecodeRoiMicros'] = decodeTimer.elapsedMicroseconds;
        }
        lastDetectorConfidence =
            detectionTrace['maxPersonConfidence'] as double?;
        lastDetectorTimestamp = input.timestampMicros;
        roiFrames = 0;
      }
      PoseFrame frame;
      String outcome = 'pose', nextRoiState = 'unavailable';
      Map<String, Object?> renderTrace = {
        'rawTensorLandmarkCount': 0,
        'rawAnatomicalLandmarkCount': 0,
        'projectedImageCount': 0
      };
      if (roi == null) {
        outcome = detectionTrace['outcome'] as String? ?? 'roi_unavailable';
        frame = PoseFrame(
            capturedAtMicros: input.timestampMicros,
            detectorId: 'blazepose-tflite',
            modelVersion: BlazePoseModelContract.version,
            imageWidth: width,
            imageHeight: height,
            posePresence: 0,
            landmarks: {});
      } else {
        final usedRoi = roi!;
        final tensor = measured(
            'landmarkPreprocessMicros',
            () => preprocessImage(image, usedRoi, 256,
                minimum: 0, maximum: 1, border: PoseImageBorder.replicate));
        final raw = gpu == null
            ? invoke(landmarkInterpreter!, tensor, 0, 'landmark')
            : await invokeGpu(1, tensor, 'landmark');
        final postTimer = Stopwatch()..start();
        Float32List output(int n) =>
            landmarkGpuOutputs?.outputs[n] ??
            Float32List.fromList(landmarkInterpreter!
                .getOutputTensor(n)
                .data
                .buffer
                .asFloat32List());
        final presence = output(1)[0];
        final heatmap = output(3);
        frame = decodeBlazePoseLandmarks(
            raw: raw,
            world: output(4),
            posePresence: presence,
            heatmap: heatmap,
            roi: usedRoi,
            imageWidth: width,
            imageHeight: height,
            timestampMicros: input.timestampMicros);
        // Only auxiliary alignment points 33/34 drive the next ROI; not the
        // displayed/filtered skeleton. Re-detect periodically and after loss.
        roi = presence >= 0.5
            ? roiFromAuxiliaryLandmarks(raw, heatmap, usedRoi)
            : null;
        if (comparing) {
          final cpuFrame = decodeBlazePoseLandmarks(
              raw: cpuOutputs[0]!,
              world: cpuOutputs[4]!,
              posePresence: cpuOutputs[1]![0],
              heatmap: cpuOutputs[3]!,
              roi: usedRoi,
              imageWidth: width,
              imageHeight: height,
              timestampMicros: input.timestampMicros);
          agreement.observeRoi(
              cpuOutputs[1]![0] >= .5
                  ? roiFromAuxiliaryLandmarks(
                      cpuOutputs[0]!, cpuOutputs[3]!, usedRoi)
                  : null,
              roi);
          agreement.observeFrames(cpuFrame, frame);
        }
        roiFrames++;
        if (poseQualityDebugEnabled) {
          timings['landmarkPostprocessMicros'] = postTimer.elapsedMicroseconds;
          outcome = presence < .5
              ? 'low_landmark_pose_presence'
              : frame.landmarks.isEmpty
                  ? 'nonfinite_landmarks'
                  : 'pose';
          nextRoiState = presence < .5
              ? 'reset_low_pose_presence'
              : roi == null
                  ? 'invalid_auxiliary_roi'
                  : 'tracked_auxiliary_roi';
        }
        if (poseRenderDebugEnabled || poseQualityDebugEnabled) {
          renderTrace = measured('diagnosticTraceMicros',
              () => blazePoseRenderingSummary(raw, frame, usedRoi));
        }
      }
      if ((agreement?.complete == true || comparisonAttempts >= 24) &&
          !compareClosed) {
        detectionInterpreter?.close();
        landmarkInterpreter?.close();
        compareClosed = true;
      }
      if (poseQualityDebugEnabled) {
        timings['preprocessingMicros'] =
            (timings['detectorPreprocessMicros'] ?? 0) +
                (timings['landmarkPreprocessMicros'] ?? 0);
        timings['totalNativeMicros'] = nativeMicros;
        timings['workerPipelineMicros'] = total.elapsedMicroseconds;
      }
      replies.send([
        'result',
        id,
        frame,
        nativeMicros,
        total.elapsedMicroseconds,
        if (poseRenderDebugEnabled || poseQualityDebugEnabled || gpu != null)
          renderTrace,
        if (poseQualityDebugEnabled || gpu != null)
          {
            'frameTimestampMicros': input.timestampMicros,
            'detectorRan': detectorRan,
            'roiSource': detectorRan ? 'detector' : 'tracked_roi',
            'detectorPersonConfidence':
                detectorRan ? lastDetectorConfidence : null,
            'lastDetectorConfidence': lastDetectorConfidence,
            'lastDetectorTimestampMicros': lastDetectorTimestamp,
            'posePresence': frame.posePresence,
            'outcome': outcome,
            'nextRoiState': nextRoiState,
            'landmarkCount': frame.landmarks.length,
            'timings': timings,
            'projection': renderTrace,
            if (gpu != null) 'backend': 'opencl_required',
            if (gpu != null) 'sameInputComparisonActive': comparing
          },
        if (gpu != null)
          {
            if (agreement != null) ...agreement.snapshot,
            'detectorTensorPairs': detectorPairs,
            'cpuShadowClosed': compareClosed,
            'comparisonAttempts': comparisonAttempts,
            'attemptLimit': 24,
            'initialWaitMicros': 5000000,
            'comparisonActive': comparing,
            'firstComparisonInputMicros': firstComparisonInput ?? 0,
            'lastComparisonInputMicros': lastComparisonInput ?? 0
          }
      ]);
    } catch (error) {
      roi = null;
      if (gpu != null) {
        try {
          await gpu.close();
        } finally {
          if (!compareClosed) {
            try {
              detectionInterpreter?.close();
            } finally {
              landmarkInterpreter?.close();
              compareClosed = true;
            }
          }
        }
      }
      replies.send([
        'error',
        id,
        gpu == null
            ? 'BlazePose camera frame processing failed.'
            : 'BlazePose GPU frame failed: $error'
      ]);
    }
  });
}
