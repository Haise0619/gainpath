import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../infrastructure/media/video_tutorial_player.dart';
import '../../domain/tutorial_player.dart';

/// Owns a single decoder across inline and fullscreen views. No autoplay.
class EquipmentTutorialVideo extends StatefulWidget {
  const EquipmentTutorialVideo(
      {super.key, required this.url, this.playerFactory});
  final String url;
  final TutorialPlayerFactory? playerFactory;
  @override
  State<EquipmentTutorialVideo> createState() => _EquipmentTutorialVideoState();
}

class _EquipmentTutorialVideoState extends State<EquipmentTutorialVideo>
    with WidgetsBindingObserver {
  TutorialPlayer? _player;
  String? _error;
  bool _loading = false, _fullscreen = false;
  int _generation = 0;
  bool _foreground = true;
  bool _started = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    unawaited(_start(autoplay: false));
  }

  @override
  void didUpdateWidget(covariant EquipmentTutorialVideo old) {
    super.didUpdateWidget(old);
    if (widget.url != old.url) {
      _release();
      _error = null;
      _loading = false;
      unawaited(_start(autoplay: false));
    }
  }

  void _release() {
    _generation++;
    _player?.dispose();
    _player = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      final player = _player;
      if (player != null) unawaited(_command(player.pause));
    }
  }

  Future<void> _command(Future<void> Function() command) async {
    try {
      await command();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Tutorial could not play. Try again.');
      }
    }
  }

  Future<void> _start({bool autoplay = true}) async {
    if (_loading) return;
    _release();
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
      _started = false;
    });
    try {
      final uri = Uri.parse(widget.url);
      if (uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException();
      }
      final player = (widget.playerFactory ?? VideoTutorialPlayer.new)(uri);
      _player = player;
      await player.initialize().timeout(const Duration(seconds: 25));
      if (!mounted || generation != _generation) return;
      if (!player.ready || player.error != null) {
        throw StateError('Playback unavailable');
      }
      setState(() => _loading = false);
      if (autoplay && _foreground) await _play(player);
    } catch (_) {
      if (!mounted || generation != _generation) return;
      _release();
      setState(() {
        _loading = false;
        _error = 'Tutorial could not play. Check your connection and retry.';
      });
    }
  }

  Future<void> _play(TutorialPlayer player) async {
    if (!_foreground) return;
    setState(() => _started = true);
    await _command(() async {
      if (player.duration > Duration.zero &&
          player.position >= player.duration) {
        await player.seek(Duration.zero);
      }
      await player.play();
      if (!_foreground && identical(_player, player)) await player.pause();
    });
  }

  String _time(Duration duration) {
    final seconds = duration.inSeconds.clamp(0, 864000);
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _openFullscreen() async {
    final player = _player;
    if (player == null) return;
    setState(() => _fullscreen = true);
    try {
      await showDialog<void>(
          context: context,
          useSafeArea: true,
          builder: (context) => Dialog.fullscreen(
              backgroundColor: Colors.black,
              child: SafeArea(
                  child: Column(children: [
                Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                        tooltip: 'Exit fullscreen',
                        color: Colors.white,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close))),
                Expanded(child: Center(child: _view(player, fullscreen: true))),
              ]))));
    } finally {
      if (mounted) setState(() => _fullscreen = false);
    }
  }

  Widget _view(TutorialPlayer player, {bool fullscreen = false}) =>
      AnimatedBuilder(
          animation: player,
          builder: (context, _) {
            if (player.error != null || _error != null) {
              return _failure(fullscreen: fullscreen);
            }
            final duration = player.duration.inMilliseconds.toDouble();
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                  flex: fullscreen ? 1 : 0,
                  child: AspectRatio(
                      aspectRatio:
                          player.aspectRatio.isFinite && player.aspectRatio > 0
                              ? player.aspectRatio
                              : 16 / 9,
                      child: Stack(alignment: Alignment.center, children: [
                        player.buildVideo(),
                        if (player.buffering) const CircularProgressIndicator(),
                        if (!_started)
                          FilledButton.icon(
                              onPressed: () => _play(player),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Play tutorial'))
                      ]))),
              Material(
                  color: Colors.black,
                  child: Row(children: [
                    IconButton(
                        tooltip:
                            player.playing ? 'Pause tutorial' : 'Play tutorial',
                        color: Colors.white,
                        icon: Icon(
                            player.playing ? Icons.pause : Icons.play_arrow),
                        onPressed: () => _command(() async {
                              if (player.playing) {
                                await player.pause();
                              } else {
                                await _play(player);
                              }
                            })),
                    Expanded(
                        child: Slider(
                            semanticFormatterCallback: (v) =>
                                '${(v / 1000).round()} seconds',
                            value: duration > 0
                                ? player.position.inMilliseconds
                                    .toDouble()
                                    .clamp(0, duration)
                                : 0,
                            max: duration > 0 ? duration : 1,
                            onChanged: duration <= 0
                                ? null
                                : (v) => _command(() => player
                                    .seek(Duration(milliseconds: v.round()))))),
                    if (!fullscreen)
                      IconButton(
                          tooltip: 'Fullscreen tutorial',
                          color: Colors.white,
                          onPressed: _openFullscreen,
                          icon: const Icon(Icons.fullscreen)),
                  ])),
              Text(
                  '${_time(player.position)} / ${duration > 0 ? _time(player.duration) : '--:--'}',
                  style: TextStyle(fontSize: 12, color: fullscreen ? Colors.white : null)),
              if (duration <= 0)
                Text('Video duration unavailable. Seeking is disabled.',
                    style: TextStyle(fontSize: 12, color: fullscreen ? Colors.white : null)),
            ]);
          });
  Widget _failure({bool fullscreen = false}) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
            _error ??
                'Tutorial could not play. Check your connection and retry.',
            style: TextStyle(color: fullscreen ? Colors.white : null)),
        TextButton(
            onPressed: () {
              if (fullscreen) Navigator.pop(context);
              _start();
            },
            child: const Text('Retry tutorial')),
      ]));
  @override
  Widget build(BuildContext context) {
    if (_fullscreen) {
      return const AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(child: Text('Playing fullscreen')));
    }
    if (_error != null) return _failure();
    if (_loading) {
      return const AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(child: CircularProgressIndicator()));
    }
    final player = _player;
    if (player != null) return _view(player);
    return AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(
            child: FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play tutorial'))));
  }
}
