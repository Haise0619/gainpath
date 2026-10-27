import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/gamification/domain/move_and_catch.dart';
import 'package:gainpath_mobile/features/gamification/domain/move_catch_ports.dart';
import 'package:gainpath_mobile/features/gamification/application/move_and_catch_controller.dart';

class Camera extends MoveCatchCamera {
  int starts = 0, pauses = 0, resumes = 0, closes = 0;
  @override
  bool tracking = false;
  @override
  String? error;
  void Function(MoveCatchTorsoSample)? callback;
  @override
  Future<void> start(void Function(MoveCatchTorsoSample) f) async {
    starts++;
    callback = f;
    tracking = true;
  }

  @override
  Future<void> pause() async {
    pauses++;
    tracking = false;
  }

  @override
  Future<void> resume() async {
    resumes++;
    tracking = true;
  }

  @override
  Future<void> close() async {
    closes++;
    tracking = false;
  }

  void sample(int now) => callback?.call(MoveCatchTorsoSample(
      centerX: .5, shoulderWidth: .3, capturedAtMicros: now));
}

class Best implements MoveCatchBestScoreStore {
  int writes = 0;
  Completer<void>? pending;
  @override
  Future<int> load(SessionScope s) async => 30;
  @override
  Future<int> record(SessionScope s, int score,
      {required bool Function() isCurrent}) async {
    await pending?.future;
    if (!isCurrent()) throw StateError('stale');
    writes++;
    return score > 30 ? score : 30;
  }
}

void main() {
  final scope = SessionScope(userId: 'one', organizationId: 'org');
  late SessionScope? current;
  late Camera camera;
  late Best best;
  late MoveAndCatchController game;
  late int now;
  setUp(() {
    now = 0;
    current = scope;
    camera = Camera();
    best = Best();
    game = MoveAndCatchController(
        scope: scope,
        activeScope: () => current,
        camera: camera,
        bestScores: best,
        engine: MoveCatchEngine(durationMicros: 500000),
        clockMicros: () => now,
        autoTick: false);
  });
  tearDown(() => game.dispose());
  void steps(int count) {
    for (var i = 0; i < count; i++) {
      now += 50000;
      camera.sample(now);
      game.tick();
    }
  }

  Future<void> play() async {
    await game.startCamera(consented: true);
    steps(30);
    game.startRound();
    steps(60);
    expect(game.engine.phase, MoveCatchPhase.playing);
  }

  test('leaving a completed round waits for its local result save', () async {
    await play();
    best.pending = Completer<void>();
    steps(10);
    expect(game.engine.phase, MoveCatchPhase.finished);
    final leaving = game.finishAndClose();
    await Future<void>.delayed(Duration.zero);
    expect(camera.closes, 0);
    best.pending!.complete();
    await leaving;
    expect(best.writes, 1);
    expect(camera.closes, 1);
    expect(game.current, isFalse);
  });
  test('repeated replay taps during save restart the camera only once',
      () async {
    await play();
    best.pending = Completer<void>();
    steps(10);
    final first = game.restart(), second = game.restart();
    await Future<void>.delayed(Duration.zero);
    best.pending!.complete();
    await Future.wait([first, second]);
    expect(camera.resumes, 1);
    expect(best.writes, 1);
    expect(game.engine.phase, MoveCatchPhase.calibrating);
  });

  test(
      'camera waits for explicit consent; background requires manual fresh resume',
      () async {
    await game.startCamera(consented: false);
    expect(camera.starts, 0);
    await play();
    steps(2);
    final left = game.engine.remainingSeconds;
    await game.background();
    now += 1000000;
    game.tick();
    expect(game.engine.remainingSeconds, left);
    game.foreground();
    expect(game.engine.phase, MoveCatchPhase.paused);
    await game.resume();
    expect(camera.resumes, 1);
    steps(1);
    expect(game.engine.phase, MoveCatchPhase.countdown);
    expect(game.engine.remainingSeconds, left);
  });
  test('account change permanently closes camera and rejects later samples',
      () async {
    await play();
    current = null;
    game.tick();
    await Future<void>.delayed(Duration.zero);
    expect(camera.closes, 1);
    current = scope;
    camera.sample(now + 50000);
    expect(game.current, isFalse);
    expect(best.writes, 0);
  });
  test(
      'finished round saves once and replay waits for old save before recalibration',
      () async {
    await play();
    best.pending = Completer<void>();
    steps(10);
    expect(game.engine.phase, MoveCatchPhase.finished);
    final replay = game.restart();
    await Future<void>.delayed(Duration.zero);
    expect(game.engine.phase, MoveCatchPhase.finished);
    best.pending!.complete();
    await replay;
    expect(best.writes, 1);
    expect(game.engine.phase, MoveCatchPhase.calibrating);
    expect(game.bestScore, 30);
    expect(game.bestSaved, isFalse);
  });
  test('pending best save cannot publish a result after account changes',
      () async {
    await play();
    best.pending = Completer<void>();
    steps(10);
    await Future<void>.delayed(Duration.zero);
    current = null;
    best.pending!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(best.writes, 0);
    expect(game.bestSaved, isFalse);
  });
}
