import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_mobile/features/workout/domain/tutorial_player.dart';
import 'package:gainpath_mobile/features/workout/domain/guided_timed_progress.dart';
import 'package:gainpath_mobile/features/workout/application/guided_timed_workout_controller.dart';

class Player extends TutorialPlayer {
  @override
  bool ready = false;
  @override
  bool playing = false;
  @override
  bool buffering = false;
  bool looping = false;
  @override
  String? error;
  bool released = false, failPlay = false;
  Completer<void>? initialization;
  @override
  Duration get duration => const Duration(seconds: 10);
  @override
  Duration get position => Duration.zero;
  @override
  double get aspectRatio => 1;
  @override
  Future<void> initialize() async {
    await initialization?.future;
    ready = true;
  }

  @override
  Future<void> setLooping(bool value) async {
    looping = value;
  }

  @override
  Future<void> play() async {
    playing = !failPlay;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    playing = false;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration position) async {}
  @override
  Widget buildVideo() => const SizedBox();
  void buffer() {
    buffering = true;
    notifyListeners();
  }

  @override
  void dispose() {
    released = true;
    super.dispose();
  }
}

void main() {
  late Player player;
  late GuidedTimedWorkoutController c;
  late int micros;
  late bool scope, failSave;
  late List<GuidedTimedProgress> saved;
  setUp(() {
    micros = 0;
    scope = true;
    failSave = false;
    saved = [];
    player = Player();
    c = GuidedTimedWorkoutController(
        progress: GuidedTimedProgress(
            runId: 'run',
            entryId: 'entry',
            entryIndex: 0,
            exerciseId: 'exercise',
            prescription:
                TimedPrescription(sets: 3, durationSeconds: 45, restSeconds: 0),
            mediaIdentity: 'video@1',
            updatedAt: DateTime.utc(2026)),
        player: player,
        activeScope: () => scope,
        persist: (p) async {
          if (failSave) throw StateError('disk');
          saved.add(p);
        },
        monotonicNow: () => Duration(microseconds: micros),
        utcNow: () => DateTime.utc(2026).add(Duration(microseconds: micros)));
  });
  tearDown(() => c.dispose());
  test('three bounded sets loop and require explicit next even zero rest',
      () async {
    await c.initialize();
    await c.start();
    expect(player.looping, true);
    for (var n = 1; n <= 3; n++) {
      micros += 90000000;
      await c.tick();
      expect(c.progress.completedSets, n);
      await c.tick();
      expect(c.progress.completedSets, n);
      if (n < 3) await c.startNextSet();
    }
    expect(c.progress.totalActiveMicroseconds, 135000000);
    expect(c.progress.phase, GuidedTimedPhase.completed);
    final count = saved.length;
    await c.tick();
    expect(saved.length, count);
  });
  test('manual rest and pause never credit work', () async {
    await c.initialize();
    await c.start();
    micros += 10000000;
    await c.rest();
    expect(c.progress.completedSets, 0);
    micros += 90000000;
    await c.tick();
    expect(c.progress.totalActiveMicroseconds, 10000000);
    await c.resumeCurrentSet();
    micros += 1000000;
    await c.pause();
    micros += 90000000;
    await c.tick();
    expect(c.progress.totalActiveMicroseconds, 11000000);
    await c.resume();
    micros += 34000000;
    await c.tick();
    expect(c.progress.completedSets, 1);
  });
  test('buffering freezes synchronously and requires explicit resume',
      () async {
    await c.initialize();
    await c.start();
    micros = 10000000;
    await c.tick();
    player.buffer();
    await Future<void>.delayed(Duration.zero);
    micros = 100000000;
    await c.tick();
    expect(c.progress.totalActiveMicroseconds, 10000000);
    player.buffering = false;
    await c.resume();
    micros += 35000000;
    await c.tick();
    expect(c.progress.completedSets, 1);
  });
  test('save failure pauses and retry keeps exactly same run and credit',
      () async {
    await c.initialize();
    await c.start();
    failSave = true;
    micros = 45000000;
    await expectLater(c.tick(), throwsStateError);
    expect(c.progress.completedSets, 1);
    expect(c.progress.phase, GuidedTimedPhase.interrupted);
    failSave = false;
    await c.resume();
    expect(c.progress.runId, 'run');
    expect(c.progress.completedSets, 1);
  });
  test('account revocation disposes without writing', () async {
    await c.initialize();
    await c.start();
    final count = saved.length;
    scope = false;
    await c.tick();
    expect(player.released, true);
    expect(saved.length, count);
  });
  test('failed playback cannot start timer', () async {
    await c.initialize();
    player.failPlay = true;
    await c.start();
    micros = 90000000;
    await c.tick();
    expect(c.progress.totalActiveMicroseconds, 0);
  });
  test('initialize timeout and stale completion never start', () async {
    c.dispose();
    player = Player()..initialization = Completer<void>();
    c = GuidedTimedWorkoutController(
        progress: GuidedTimedProgress(
            runId: 'run',
            entryId: 'entry',
            entryIndex: 0,
            exerciseId: 'exercise',
            prescription:
                TimedPrescription(sets: 1, durationSeconds: 45, restSeconds: 0),
            mediaIdentity: 'v',
            updatedAt: DateTime.utc(2026)),
        player: player,
        activeScope: () => scope,
        persist: (_) async {},
        initializationTimeout: const Duration(milliseconds: 1));
    await c.initialize();
    expect(c.progress.phase, GuidedTimedPhase.interrupted);
    player.initialization!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(c.progress.phase, GuidedTimedPhase.interrupted);
  });
  test('rest command at a delayed deadline cannot manually credit a set',
      () async {
    await c.initialize();
    await c.start();
    micros = 90000000;
    await c.rest();
    expect(c.progress.completedSets, 0);
    expect(c.progress.restKind, GuidedTimedRestKind.midSet);
  });
  test(
      'final persisted snapshot is completed and failed final retry is idempotent',
      () async {
    await c.initialize();
    await c.start();
    for (var i = 0; i < 2; i++) {
      micros += 45000000;
      await c.tick();
      await c.startNextSet();
    }
    failSave = true;
    micros += 45000000;
    await expectLater(c.tick(), throwsStateError);
    expect(c.progress.completedSets, 3);
    failSave = false;
    await c.resume();
    expect(saved.last.phase, GuidedTimedPhase.completed);
    expect(c.progress.totalActiveMicroseconds, 135000000);
  });
  test('reopened between-set rest stays rest until explicit next set',
      () async {
    await c.initialize();
    await c.start();
    micros = 45000000;
    await c.tick();
    final snapshot = c.progress;
    c.dispose();
    player = Player();
    c = GuidedTimedWorkoutController(
        progress: snapshot,
        player: player,
        activeScope: () => true,
        persist: (_) async {},
        monotonicNow: () => Duration(microseconds: micros),
        utcNow: () => DateTime.utc(2026).add(Duration(microseconds: micros)));
    await c.initialize();
    await c.resume();
    expect(c.progress.phase, GuidedTimedPhase.resting);
    micros += 45000000;
    await c.tick();
    expect(c.progress.completedSets, 1);
  });
  test('snapshots every five active seconds and interruption boundaries',
      () async {
    await c.initialize();
    await c.start();
    final initial = saved.length;
    micros = 4999999;
    await c.tick();
    expect(saved.length, initial);
    micros = 5000000;
    await c.tick();
    expect(saved.length, initial + 1);
    await c.interrupt('background');
    expect(saved.length, initial + 2);
    micros = 60000000;
    await c.tick();
    expect(c.progress.totalActiveMicroseconds, 5000000);
  });
}
