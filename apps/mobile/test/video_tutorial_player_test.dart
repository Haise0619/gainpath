import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/infrastructure/media/video_tutorial_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class FixturePlatform extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>.broadcast();
  String? source;
  int plays = 0, pauses = 0, releases = 0;
  Duration position = Duration.zero;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    source = options.dataSource.uri;
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    scheduleMicrotask(() => events.add(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 37),
        size: const Size(640, 360))));
    return events.stream;
  }

  @override
  Future<void> play(int playerId) async {
    plays++;
  }

  @override
  Future<void> pause(int playerId) async {
    pauses++;
  }

  @override
  Future<void> seekTo(int playerId, Duration value) async {
    position = value;
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> dispose(int playerId) async {
    releases++;
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const Text('Native fixture view');
}

void main() {
  testWidgets(
      'real adapter carries exact URL, duration, controls and native release',
      (tester) async {
    final original = VideoPlayerPlatform.instance;
    final platform = FixturePlatform();
    VideoPlayerPlatform.instance = platform;
    final uri = Uri.parse('https://media.example.test/exact.mp4?token=fixture');
    final player = VideoTutorialPlayer(uri);
    await tester.runAsync(player.initialize);
    expect(platform.source, uri.toString());
    expect(player.ready, true);
    expect(player.duration, const Duration(seconds: 37));
    expect(player.aspectRatio, closeTo(16 / 9, 0.001));
    expect(player.playing, false);
    await tester.pumpWidget(MaterialApp(home: player.buildVideo()));
    expect(find.text('Native fixture view'), findsOneWidget);
    await player.play();
    expect(platform.plays, 1);
    await player.seek(const Duration(seconds: 12));
    expect(player.position, const Duration(seconds: 12));
    await player.pause();
    expect(player.playing, false);
    platform.events
        .addError(PlatformException(code: 'decoder', message: 'private token'));
    await tester.pump();
    expect(player.error, 'Playback failed');
    await tester.pumpWidget(const SizedBox());
    player.dispose();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(platform.releases, 1);
    await platform.events.close();
    VideoPlayerPlatform.instance = original;
  });
}
