import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, MemberPreferences;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/real_squat_session_controller.dart';
import 'package:gainpath_mobile/features/workout/application/pose_preview_controller.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'squat_processing_controller_test.dart' as fixtures;

class Camera implements PoseCameraSource {
  void Function(PoseInput)? receive;
  int starts = 0, stops = 0;
  bool failStop = false;
  @override
  Future<void> start(void Function(PoseInput) callback) async {
    starts++;
    receive = callback;
  }

  @override
  void invalidate() {}
  @override
  Future<void> stop() async {
    stops++;
    receive = null;
    if (failStop) throw StateError('camera disposal failed');
  }
}

class Detector implements ManagedPoseDetector {
  double angle = 175;
  int closes = 0;
  @override
  Future<PoseFrame> detect(PoseInput input) async =>
      fixtures.frame(input.timestampMicros, angle);
  @override
  Future<void> reset() async {}
  @override
  Future<void> close() async {
    closes++;
  }
}

class FailingStore extends InMemoryWorkoutSessionStore {
  FailingStore({required super.scope});
  bool fail = true;
  int writes = 0;
  Completer<void>? pending;
  @override
  Future<void> write(List<WorkoutSessionRecord> records) async {
    writes++;
    await pending?.future;
    if (fail) throw StateError('disk full');
    await super.write(records);
  }
}

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  late Camera camera;
  late Detector detector;
  late fixtures.AudioSink audio;
  late FailingStore store;
  late RealSquatSessionController session;
  SessionScope? active;
  var now = 0;
  void setup({Future<void> Function(WorkoutSessionSummary)? onSaved}) {
    now = 0;
    active = scope;
    camera = Camera();
    detector = Detector();
    audio = fixtures.AudioSink();
    store = FailingStore(scope: scope);
    session = RealSquatSessionController(
        scope: scope,
        activeScope: () => active,
        camera: camera,
        detectorFactory: () async => detector,
        audioPort: audio,
        repository: WorkoutSessionRepository(
            scope: scope,
            store: store,
            uploadGateway: UnavailableWorkoutUploadGateway(),
            activeScope: () => active),
        clockMicros: () => now,
        sessionId: 'stable-id',
        exerciseId: 'F3b8xIr8ynBDd3gEICKX',
        publishedRoutineId: 'published',
        detectorId: 'fixture',
        detectorVersion: '1',
        onSaved: onSaved,
        provenance: WorkoutProvenance.recordedFixture);
  }

  testWidgets('closing from freshness publication cannot resurrect a save',
      (tester) async {
    setup();
    store.fail = false;
    await session.start(consented: true, setupConfirmed: true);
    now = 100000;
    camera.receive!(PoseInput(timestampMicros: now));
    await tester.pump();
    void listener() {
      session.removeListener(listener);
      session.close();
    }

    session.addListener(listener);
    now = 1000000;
    expect(await session.endAndSave(), isNull);
    expect(session.phase, RealSquatSessionPhase.closed);
    expect(session.summary, isNull);
    expect(store.writes, 0);
    await session.close();
    session.dispose();
  });
  testWidgets(
      'upload enqueue handoff follows durable local save and cannot undo it',
      (tester) async {
    var handoffs = 0;
    setup(onSaved: (summary) async {
      expect((await store.read()).single.summary.sessionId, summary.sessionId);
      handoffs++;
      throw StateError('sync metadata disk failure');
    });
    store.fail = false;
    await session.start(consented: true, setupConfirmed: true);
    now = 100000;
    camera.receive!(PoseInput(timestampMicros: now));
    await tester.pump();
    expect(await session.endAndSave(), isNotNull);
    expect(handoffs, 1);
    expect(session.phase, RealSquatSessionPhase.saved);
    expect(store.writes, 1);
    await session.close();
    session.dispose();
  });

  testWidgets('requires consent and setup before opening camera',
      (tester) async {
    setup();
    await session.start(consented: false, setupConfirmed: true);
    await session.start(consented: true, setupConfirmed: false);
    expect(camera.starts, 0);
    await session.start(consented: true, setupConfirmed: true);
    expect(camera.starts, 1);
    final closing = session.close();
    await tester.pump();
    await closing;
    session.dispose();
  });
  testWidgets('background startup waits for foreground before opening hardware',
      (tester) async {
    setup();
    await session.start(
        consented: true, setupConfirmed: true, foreground: false);
    expect(camera.starts, 0);
    expect(session.isPaused, true);
    await session.setForeground(false);
    expect(camera.starts, 0);
    await session.setForeground(true);
    expect(camera.starts, 1);
    await session.close();
    session.dispose();
  });
  testWidgets(
      'camera disposal failure preserves frozen result and retry saves it',
      (tester) async {
    setup();
    await session.start(consented: true, setupConfirmed: true);
    now = 100000;
    camera.receive!(PoseInput(timestampMicros: now));
    await tester.pump();
    camera.failStop = true;
    await session.setForeground(false);
    expect(session.errorMessage, contains('shutdown failed'));
    await session.pause();
    expect(session.errorMessage, contains('shutdown failed'));
    expect(await session.endAndSave(), isNull);
    final frozen = session.summary!;
    store.fail = false;
    expect(await session.endAndSave(), same(frozen));
    expect(store.writes, 2);
    expect(session.phase, RealSquatSessionPhase.saved);
    await session.close();
    session.dispose();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'end freezes one measured result and retry preserves its identity',
      (tester) async {
    setup();
    await session.start(consented: true, setupConfirmed: true);
    Future<void> send(double angle) async {
      now += 100000;
      detector.angle = angle;
      camera.receive!(PoseInput(timestampMicros: now));
      await tester.pump();
    }

    for (var i = 0; i < 12; i++) {
      await send(175);
    }
    for (var i = 1; i <= 20; i++) {
      await send(175.0 - i * 5);
    }
    for (var i = 0; i < 8; i++) {
      await send(75);
    }
    for (var i = 1; i <= 20; i++) {
      await send(75.0 + i * 5);
    }
    for (var i = 0; i < 12; i++) {
      await send(175);
    }
    expect(session.latest!.repetitions, 1);
    expect(await session.endAndSave(), isNull);
    expect(session.phase, RealSquatSessionPhase.saveFailed);
    final frozen = session.summary!;
    expect(frozen.repetitions, 1);
    expect(frozen.isEligibleForRealUpload, false);
    expect(detector.closes, 1);
    now += 1000000;
    store.fail = false;
    final a = session.endAndSave(), b = session.endAndSave();
    expect(identical(a, b), true);
    expect(await a, same(frozen));
    expect(await b, same(frozen));
    expect((await store.read()).single.summary, frozen);
    expect(store.writes, 2);
    expect(session.phase, RealSquatSessionPhase.saved);
    await session.close();
    session.dispose();
  });
  testWidgets(
      'account change during save never publishes success to the next account',
      (tester) async {
    setup();
    await session.start(consented: true, setupConfirmed: true);
    now = 100000;
    camera.receive!(PoseInput(timestampMicros: now));
    await tester.pump();
    now = 1000000;
    store.fail = false;
    store.pending = Completer<void>();
    final saving = session.endAndSave();
    await tester.pump();
    active = SessionScope(userId: 'other', organizationId: 'gainpath');
    session.accountChanged();
    store.pending!.complete();
    expect(await saving, isNull);
    expect(session.phase, RealSquatSessionPhase.closed);
    expect(session.summary, isNull);
    await session.close();
    session.dispose();
  });
  testWidgets('manual pause survives background and resumes with recalibration',
      (tester) async {
    setup();
    await session.start(consented: true, setupConfirmed: true);
    await session.pause();
    await session.setForeground(false);
    await session.setForeground(true);
    expect(session.isPaused, true);
    expect(camera.starts, 1);
    await session.resume();
    expect(camera.starts, 2);
    now = 100000;
    camera.receive!(PoseInput(timestampMicros: now));
    await tester.pump();
    expect(session.latest!.needsCalibration, true);
    await session.close();
    session.dispose();
  });
  testWidgets(
      'watchdog notification cannot reenter end before its save is reserved',
      (tester) async {
    setup();
    store.fail = false;
    await session.start(consented: true, setupConfirmed: true);
    now = 100000;
    camera.receive!(PoseInput(timestampMicros: now));
    await tester.pump();
    Future<WorkoutSessionSummary?>? nested;
    void listener() {
      session.removeListener(listener);
      nested = session.endAndSave();
    }

    session.addListener(listener);
    now = 1000000;
    final first = session.endAndSave();
    expect(nested, same(first));
    await first;
    expect(store.writes, 1);
    await session.close();
    session.dispose();
  });
  testWidgets(
      'orientation change discards the active cycle despite identical upright dimensions',
      (tester) async {
    setup();
    await session.start(consented: true, setupConfirmed: true);
    Future<void> send(double angle, int rotation) async {
      now += 100000;
      detector.angle = angle;
      camera.receive!(PoseInput(
          timestampMicros: now,
          image: PoseCameraImage(
              width: 1,
              height: 1,
              rotationDegrees: rotation,
              format: PosePixelFormat.rgb888,
              planes: [
                PoseImagePlane(
                    bytes: Uint8List(3), rowStride: 3, pixelStride: 3)
              ])));
      await tester.pump();
    }

    for (var i = 0; i < 12; i++) {
      await send(175, 0);
    }
    for (var i = 1; i <= 20; i++) {
      await send(175.0 - i * 5, 0);
    }
    expect(session.latest!.needsCalibration, false);
    await send(75, 180);
    expect(session.latest!.needsCalibration, true);
    expect(session.latest!.repetitions, 0);
    await session.close();
    session.dispose();
  });
  testWidgets(
      'late preferences cannot override an explicit session voice choice',
      (tester) async {
    setup();
    await session.start(consented: true, setupConfirmed: true);
    session.setVoiceEnabled(true);
    session.applyPreferences(const MemberPreferences(voiceCoaching: false));
    expect(session.voiceEnabled, true);
    await session.close();
    session.dispose();
  });
  testWidgets('ending without any analyzed frames makes no save claim',
      (tester) async {
    setup();
    await session.start(consented: true, setupConfirmed: true);
    expect(await session.endAndSave(), isNull);
    expect(store.writes, 0);
    expect(session.summary, isNull);
    expect(session.errorMessage, contains('No camera frames'));
    await session.close();
    session.dispose();
  });
}
