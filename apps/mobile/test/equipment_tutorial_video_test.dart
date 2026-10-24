import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/domain/tutorial_player.dart';
import 'package:gainpath_mobile/features/workout/presentation/shared/equipment_tutorial_video.dart';

class Player extends TutorialPlayer {
  bool initialized = false, isPlaying = false, disposed = false, fail = false;
  Completer<void>? pending;
  Duration at = Duration.zero;
  Duration total = const Duration(seconds: 10);
  @override
  bool get ready => initialized;
  @override
  bool get playing => isPlaying;
  @override
  bool get buffering => false;
  @override
  String? get error => null;
  @override
  Duration get duration => total;
  @override
  Duration get position => at;
  @override
  double get aspectRatio => 16 / 9;
  @override
  Future<void> initialize() async {
    if (fail) throw StateError('private URL');
    if (pending != null) await pending!.future;
    initialized = true;
    notifyListeners();
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration p) async {
    at = p;
    notifyListeners();
  }

  @override
  Widget buildVideo() => const ColoredBox(key: ValueKey('video-first-frame'), color: Colors.black);
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

void main() {
  testWidgets(
      'tutorial previews paused; tap, seek, fullscreen and disposal work',
      (t) async {
    final player = Player();
    int creations = 0;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EquipmentTutorialVideo(
                url: 'https://example.test/video.mp4',
                playerFactory: (_) {
                  creations++;
                  return player;
                }))));
    await t.pumpAndSettle();
    expect(creations, 1);
    expect(player.playing, false);
    await t.tap(find.text('Play tutorial'));
    await t.pumpAndSettle();
    expect(player.playing, true);
    await t.tap(find.byTooltip('Pause tutorial'));
    await t.pump();
    expect(player.playing, false);
    final slider = t.widget<Slider>(find.byType(Slider));
    slider.onChanged!(5000);
    await t.pump();
    expect(player.position, const Duration(seconds: 5));
    expect(t.widget<Slider>(find.byType(Slider)).value, 5000);
    player.at = const Duration(seconds: 2);
    player.notifyListeners();
    await t.pump();
    expect(t.widget<Slider>(find.byType(Slider)).value, 2000);
    await t.tap(find.byTooltip('Fullscreen tutorial'));
    await t.pumpAndSettle();
    expect(find.byTooltip('Exit fullscreen'), findsOneWidget);
    await t.tap(find.byTooltip('Exit fullscreen'));
    await t.pumpAndSettle();
    await t.pumpWidget(const SizedBox());
    expect(player.disposed, true);
  });
  testWidgets('playback failure is sanitized and retry creates a fresh player',
      (t) async {
    final bad = Player()..fail = true;
    final good = Player();
    int creations = 0;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EquipmentTutorialVideo(
                url: 'https://example.test/video.mp4',
                playerFactory: (_) => creations++ == 0 ? bad : good))));
    await t.pumpAndSettle();
    expect(find.textContaining('private URL'), findsNothing);
    expect(bad.disposed, true);
    await t.tap(find.text('Retry tutorial'));
    await t.pumpAndSettle();
    expect(good.playing, true);
  });
  testWidgets('backgrounding during initialization prevents deferred autoplay',
      (t) async {
    final player = Player()..pending = Completer<void>();
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EquipmentTutorialVideo(
                url: 'https://example.test/video.mp4',
                playerFactory: (_) => player))));
    await t.pump();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    player.pending!.complete();
    await t.pumpAndSettle();
    expect(player.playing, false);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
  testWidgets('opening a tutorial prepares a paused first frame preview',
      (t) async {
    final player = Player();
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EquipmentTutorialVideo(
                url: 'https://example.test/video.mp4',
                playerFactory: (_) => player))));
    await t.pumpAndSettle();
    expect(player.initialized, true);
    expect(player.playing, false);
    expect(find.byKey(const ValueKey('video-first-frame')), findsOneWidget);
    expect(find.text('Play tutorial'), findsOneWidget);
  });
  testWidgets(
      'unknown duration never pins progress at the end or enables invalid seeking',
      (t) async {
    final player = Player()
      ..total = Duration.zero
      ..at = const Duration(seconds: 5);
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EquipmentTutorialVideo(
                url: 'https://example.test/video.mp4',
                playerFactory: (_) => player))));
    await t.pumpAndSettle();
    await t.tap(find.text('Play tutorial'));
    await t.pumpAndSettle();
    final slider = t.widget<Slider>(find.byType(Slider));
    expect(slider.value, 0);
    expect(slider.onChanged, isNull);
    expect(find.textContaining('0:05'), findsOneWidget);
  });
}
