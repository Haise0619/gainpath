import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';
import '../../features/workout/domain/tutorial_player.dart';

class VideoTutorialPlayer extends TutorialPlayer {
  VideoTutorialPlayer(Uri uri)
      : _controller = VideoPlayerController.networkUrl(uri) {
    _controller.addListener(_changed);
  }
  final VideoPlayerController _controller;
  bool _disposed = false;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  bool get ready => _controller.value.isInitialized;
  @override
  bool get playing => _controller.value.isPlaying;
  @override
  bool get buffering => _controller.value.isBuffering;
  @override
  String? get error => _controller.value.hasError ? 'Playback failed' : null;
  @override
  Duration get duration => _controller.value.duration;
  @override
  Duration get position => _controller.value.position;
  @override
  double get aspectRatio => _controller.value.aspectRatio;
  @override
  Future<void> initialize() => _controller.initialize();
  @override
  Future<void> play() => _controller.play();
  @override
  Future<void> pause() => _controller.pause();
  @override
  Future<void> seek(Duration position) => _controller.seekTo(position);
  @override
  Widget buildVideo() => VideoPlayer(_controller);
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _controller.removeListener(_changed);
    // Disposing stops native playback and releases texture/decoder resources.
    unawaited(_controller.dispose().catchError((Object _) {}));
    super.dispose();
  }
}
