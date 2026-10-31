import 'dart:async';
import 'dart:math';
import 'support/reach_tap_fixture.dart' as fixture;
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/gamification/domain/reach_tap.dart';
import 'package:gainpath_mobile/features/gamification/domain/reach_tap_camera.dart';
import 'package:gainpath_mobile/features/gamification/domain/reach_tap_ports.dart';
import 'package:gainpath_mobile/features/gamification/application/reach_tap_controller.dart';

class TapCamera extends ReachTapCamera {
  int starts = 0, pauses = 0, resumes = 0, closes = 0;
  void Function(ReachTapSample?)? receive;
  @override
  bool tracking = true;
  @override
  String? error;
  @override
  Future<void> start(void Function(ReachTapSample?) onSample) async {
    starts++;
    receive = onSample;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> resume() async {
    resumes++;
  }

  @override
  Future<void> close() async {
    closes++;
  }

  void fail() {
    error = 'Camera interrupted';
    notifyListeners();
  }
}

class TapHistory implements ReachTapHistoryStore {
  final rows = <ReachTapRound>[];
  bool fail = false;
  Completer<ReachTapHistory>? pending;
  Completer<ReachTapHistory>? pendingLoad;
  @override
  Future<ReachTapHistory> load(SessionScope scope) async =>
      pendingLoad == null ? ReachTapHistory() : await pendingLoad!.future;
  @override
  Future<ReachTapHistory> record(SessionScope scope, ReachTapRound round,
      {required bool Function() isCurrent}) async {
    if (fail) throw StateError('disk');
    final wait = pending;
    if (wait != null) await wait.future;
    if (!isCurrent()) throw StateError('account');
    if (!rows.any((r) => r.id == round.id)) rows.add(round);
    return ReachTapHistory(
        rounds: rows,
        bestScore:
            rows.map((r) => r.score).fold<int>(0, (a, b) => a > b ? a : b));
  }
}

void main() {
  final scope = SessionScope(userId: 'a', organizationId: 'gym');
  test('consent, background and account isolation guard camera and scores',
      () async {
    SessionScope? active = scope;
    var now = 0;
    final camera = TapCamera(), history = TapHistory();
    final c = ReachTapController(
        scope: scope,
        activeScope: () => active,
        camera: camera,
        history: history,
        clockMicros: () => now,
        autoTick: false);
    addTearDown(c.dispose);
    await c.startCamera(consented: false);
    expect(camera.starts, 0);
    await c.startCamera(consented: true);
    expect(camera.starts, 1);
    await c.background();
    expect(camera.pauses, 1);
    await c.resume();
    expect(camera.resumes, 0);
    c.foreground();
    await c.resume();
    expect(camera.resumes, 1);
    active = null;
    now += 100000;
    c.tick();
    await Future<void>.delayed(Duration.zero);
    expect(c.current, false);
    expect(camera.closes, 1);
    expect(history.rows, isEmpty);
  });
  test('camera failure pauses immediately and cannot generate game score',
      () async {
    final camera = TapCamera();
    final c = ReachTapController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        history: TapHistory(),
        clockMicros: () => 100000,
        autoTick: false);
    addTearDown(c.dispose);
    await c.startCamera(consented: true);
    camera.fail();
    c.tick();
    expect(c.error, isNotNull);
    expect(c.engine.score, 0);
    expect(c.engine.phase, isNot(ReachTapPhase.playing));
  });
  test(
      'automatic alignment, confirmed hits, save retry and replay keep one completed round',
      () async {
    var now = 1000000;
    final camera = TapCamera(), history = TapHistory()..fail = true;
    final c = ReachTapController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        history: history,
        clockMicros: () => now,
        autoTick: false,
        engine: ReachTapEngine(random: Random(4)),
        newId: () => 'stable-round');
    addTearDown(c.dispose);
    await c.startCamera(consented: true);
    // Camera opening/no-body observations precede a normal hands-free alignment.
    camera.receive!(null);
    for (var i = 0; i < 130 && c.engine.phase != ReachTapPhase.playing; i++) {
      now += 50000;
      camera.receive!(fixture.reachTapSample(now));
      c.tick();
    }
    expect(c.engine.phase, ReachTapPhase.playing);
    final target = c.engine.target!;
    for (var i = 0; i < 12 && c.engine.hits == 0; i++) {
      now += 50000;
      camera.receive!(fixture.reachTapSample(now, leftHand: target));
      c.tick();
    }
    expect(c.engine.score, 10);
    for (var i = 0; i < 900 && c.engine.phase != ReachTapPhase.finished; i++) {
      now += 50000;
      camera.receive!(fixture.reachTapSample(now));
      c.tick();
    }
    await Future<void>.delayed(Duration.zero);
    expect(c.engine.activeMicros, 40000000);
    expect(c.saveFailed, true);
    expect(history.rows, isEmpty);
    history.fail = false;
    await Future.wait([c.retrySave(), c.retrySave()]);
    expect(history.rows, hasLength(1));
    expect(history.rows.single.id, 'stable-round');
    expect(c.bestScore, 10);
    await c.restart();
    expect(c.engine.score, 0);
    expect(c.engine.hits, 0);
    expect(c.engine.phase, ReachTapPhase.calibrating);
    expect(history.rows, hasLength(1));
    expect(c.bestScore, 10);
  });
  test(
      'unavailable hand recovers hands-free while manual pause remains deliberate',
      () async {
    var now = 1000000;
    final camera = TapCamera();
    final c = ReachTapController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        history: TapHistory(),
        clockMicros: () => now,
        autoTick: false);
    addTearDown(c.dispose);
    await c.startCamera(consented: true);
    for (var i = 0; i < 130 && c.engine.phase != ReachTapPhase.playing; i++) {
      now += 50000;
      camera.receive!(fixture.reachTapSample(now));
      c.tick();
    }
    expect(c.engine.phase, ReachTapPhase.playing);
    final active = c.engine.activeMicros;
    camera.receive!(null);
    for (var i = 0; i < 9; i++) {
      now += 50000;
      camera.receive!(fixture.reachTapSample(now));
      c.tick();
    }
    expect(c.engine.phase, ReachTapPhase.playing);
    expect(c.engine.activeMicros, active);
    expect(c.engine.score, 0);
    expect(camera.resumes, 0);
    await c.pause();
    final paused = c.engine.activeMicros;
    now += 5000000;
    camera.receive!(fixture.reachTapSample(now));
    c.tick();
    expect(c.engine.activeMicros, paused);
    expect(c.engine.phase, ReachTapPhase.paused);
  });
  test('pending completed save is suppressed after account change', () async {
    SessionScope? active = scope;
    var now = 1000000;
    final camera = TapCamera(),
        history = TapHistory()..pending = Completer<ReachTapHistory>();
    final c = ReachTapController(
        scope: scope,
        activeScope: () => active,
        camera: camera,
        history: history,
        clockMicros: () => now,
        autoTick: false);
    addTearDown(c.dispose);
    await c.startCamera(consented: true);
    for (var i = 0; i < 1100 && c.engine.phase != ReachTapPhase.finished; i++) {
      now += 50000;
      camera.receive!(fixture.reachTapSample(now));
      c.tick();
    }
    await Future<void>.delayed(Duration.zero);
    expect(c.saving, true);
    active = null;
    c.tick();
    history.pending!.complete(ReachTapHistory());
    await Future<void>.delayed(Duration.zero);
    expect(history.rows, isEmpty);
    expect(c.current, false);
    expect(c.saved, false);
  });

  test('background while local history opens requires only one explicit Resume',
      () async {
    var now = 1000000;
    final camera = TapCamera(),
        history = TapHistory()..pendingLoad = Completer<ReachTapHistory>();
    final c = ReachTapController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        history: history,
        clockMicros: () => now,
        autoTick: false);
    addTearDown(c.dispose);
    final opening = c.startCamera(consented: true);
    await Future<void>.delayed(Duration.zero);
    await c.background();
    history.pendingLoad!.complete(ReachTapHistory());
    await opening;
    expect(camera.starts, 0);
    c.foreground();
    await c.resume();
    expect(camera.starts, 1);
    for (var i = 0; i < 130 && c.engine.phase != ReachTapPhase.playing; i++) {
      now += 50000;
      camera.receive!(fixture.reachTapSample(now));
      c.tick();
    }
    expect(c.engine.phase, ReachTapPhase.playing);
  });
}
