import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../domain/published_routine_view.dart';
import '../../domain/tutorial_media.dart';
import '../../domain/tutorial_player.dart';
import 'widgets/exercise_tutorial_image.dart';

/// Published content viewer. Viewing never creates a measured workout record.
class PublishedExerciseTutorialScreen extends StatefulWidget {
  const PublishedExerciseTutorialScreen(
      {super.key,
      required this.exercise,
      required this.playerFactory,
      this.authorized,
      this.perArmTargets = false});
  final bool perArmTargets;
  final PublishedRoutineExercise exercise;
  final TutorialPlayerFactory playerFactory;
  final ValueListenable<bool>? authorized;
  @override
  State<PublishedExerciseTutorialScreen> createState() =>
      _PublishedExerciseTutorialScreenState();
}

class _PublishedExerciseTutorialScreenState
    extends State<PublishedExerciseTutorialScreen> with WidgetsBindingObserver {
  TutorialPlayer? _player;
  Timer? _timeout;
  bool _failed = false, _foreground = true, _busy = false;
  bool get _authorized => widget.authorized?.value ?? true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.authorized?.addListener(_accountChanged);
    _open();
  }

  void _accountChanged() {
    if (!_authorized) {
      _release();
    } else if (_player == null) {
      _open(); // Restored same-scope authorization reloads without autoplay.
    }
    if (mounted) setState(() {});
  }

  void _release() {
    _timeout?.cancel();
    final player = _player;
    _player = null;
    player?.removeListener(_changed);
    player?.dispose();
    _busy = false;
  }

  void _open() {
    _release();
    _failed = false;
    final uri = tutorialMediaUri(widget.exercise.videoUrl);
    if (!_authorized || uri == null) return;
    try {
      final player = widget.playerFactory(uri);
      _player = player;
      player.addListener(_changed);
      _timeout = Timer(const Duration(seconds: 20), () {
        if (mounted && identical(_player, player)) {
          setState(() {
            _failed = true;
            _release();
          });
        }
      });
      unawaited(player.initialize().then((_) {
        if (!mounted || !_authorized || !identical(_player, player)) return;
        _timeout?.cancel();
        if (!player.ready) _failed = true;
        setState(() {});
      }).catchError((Object _) {
        if (!mounted || !identical(_player, player)) return;
        _timeout?.cancel();
        setState(() {
          _failed = true;
          _release();
        });
      }));
    } catch (_) {
      _failed = true;
      _release();
    }
  }

  void _changed() {
    if (!mounted) return;
    if (_player?.error != null) {
      _failed = true;
      final player = _player;
      // ChangeNotifier cannot be disposed inside its notification stack.
      scheduleMicrotask(() {
        if (mounted && identical(_player, player)) {
          setState(_release);
        }
      });
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(PublishedExerciseTutorialScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authorized != widget.authorized) {
      oldWidget.authorized?.removeListener(_accountChanged);
      widget.authorized?.addListener(_accountChanged);
    }
    if (oldWidget.exercise != widget.exercise ||
        oldWidget.playerFactory != widget.playerFactory ||
        oldWidget.authorized != widget.authorized) {
      _open();
    }
  }

  Future<void> _control(Future<void> Function(TutorialPlayer) action) async {
    final player = _player;
    if (player == null ||
        !player.ready ||
        !_authorized ||
        !_foreground ||
        _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action(player).timeout(const Duration(seconds: 20));
      // A native play command may finish after the background pause command.
      if (!_foreground && identical(_player, player)) {
        await player.pause().timeout(const Duration(seconds: 20));
      }
    } catch (_) {
      if (mounted && identical(_player, player)) {
        _failed = true;
        _release();
      }
    } finally {
      if (mounted && identical(_player, player)) {
        setState(() => _busy = false);
      } else if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    final player = _player;
    if (!_foreground && player != null) {
      unawaited(player
          .pause()
          .timeout(const Duration(seconds: 20))
          .catchError((Object _) {
        if (mounted && identical(_player, player)) {
          setState(() {
            _failed = true;
            _release();
          });
        }
      }));
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.authorized?.removeListener(_accountChanged);
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  String _time(Duration value) =>
      '${value.inSeconds ~/ 60}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    if (!_authorized) {
      return const Scaffold(
          body:
              Center(child: Text('Sign in to view this account’s tutorial.')));
    }
    final e = widget.exercise;
    final player = _player;
    final missing = tutorialMediaUri(e.videoUrl) == null;
    final ready = player?.ready ?? false;
    final total = player?.duration.inMilliseconds ?? 0;
    final position = (player?.position.inMilliseconds ?? 0).clamp(0, total);
    final ended = ready && total > 0 && position >= total;
    return Scaffold(
        appBar: AppBar(title: Text(e.name)),
        body: PageBody(children: [
          if (e.imageUrl.isNotEmpty) ...[
            ExerciseTutorialImage(
                url: e.imageUrl, label: '${e.name} cover', isCover: true),
            const SizedBox(height: 12),
          ],
          if (!missing)
            ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: ready &&
                          player!.aspectRatio.isFinite &&
                          player.aspectRatio > 0
                      ? player.aspectRatio
                      : 16 / 10,
                  child: ColoredBox(
                      color: AppColors.ink,
                      child: _failed
                          ? Center(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                  const Text(
                                      'Could not play this tutorial.\nCheck your connection or try again later.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white)),
                                  TextButton(
                                      onPressed: () => setState(_open),
                                      child: const Text('Retry')),
                                ]))
                          : !ready
                              ? const Center(
                                  child: Text('Loading tutorial…',
                                      style: TextStyle(color: Colors.white)))
                              : Stack(alignment: Alignment.center, children: [
                                  player!.buildVideo(),
                                  if (player.buffering)
                                    const CircularProgressIndicator(),
                                ])),
                )),
          if (ready && !_failed) ...[
            Row(children: [
              IconButton(
                  tooltip: ended
                      ? 'Replay tutorial'
                      : player!.playing
                          ? 'Pause tutorial'
                          : 'Play tutorial',
                  icon: Icon(ended
                      ? Icons.replay_rounded
                      : player!.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                  onPressed: _busy || !_foreground
                      ? null
                      : () => _control((p) async {
                            if (p.playing) {
                              await p.pause();
                              return;
                            }
                            if (ended) await p.seek(Duration.zero);
                            if (_authorized &&
                                _foreground &&
                                identical(_player, p)) {
                              await p.play();
                            }
                          })),
              Expanded(
                  child: Slider(
                      value: position.toDouble(),
                      max: total > 0 ? total.toDouble() : 1,
                      onChanged: total > 0 && !_busy && _foreground
                          ? (value) => _control((p) =>
                              p.seek(Duration(milliseconds: value.round())))
                          : null)),
            ]),
            Text(
                '${_time(Duration(milliseconds: position))} / ${_time(player!.duration)}'),
          ],
          const SizedBox(height: 16),
          Text(e.name, style: Theme.of(context).textTheme.titleLarge),
          if (e.category.isNotEmpty) Text(e.category),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            Chip(
                label: Text(e.tutorial.difficulty),
                side: BorderSide.none,
                backgroundColor: AppColors.primaryTint),
            if (e.tutorial.steps.isNotEmpty)
              Chip(
                  label: Text('${e.tutorial.steps.length} tutorial steps'),
                  side: BorderSide.none),
          ]),
          if (e.tutorial.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(e.tutorial.description),
          ],
          if (e.tutorial.equipment.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Eyebrow('Equipment & setup'),
            Text(e.tutorial.equipment),
          ],
          if (missing)
            const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Tutorial video unavailable')),
          if (e.tutorial.steps.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Eyebrow('How to perform'),
            for (var i = 0; i < e.tutorial.steps.length; i++)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Panel(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                  radius: 17,
                                  backgroundColor: AppColors.primaryTint,
                                  child: Text('${i + 1}',
                                      style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold))),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(e.tutorial.steps[i].title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium)),
                            ]),
                        if (e.tutorial.steps[i].imageUrl.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ExerciseTutorialImage(
                              url: e.tutorial.steps[i].imageUrl,
                              label:
                                  'Step ${i + 1}: ${e.tutorial.steps[i].title}'),
                        ],
                        const SizedBox(height: 10),
                        Text(e.tutorial.steps[i].description),
                      ]))),
          ],
          const SizedBox(height: 18),
          const Eyebrow('Published target'),
          Panel(
              child: Column(children: [
            DetailRow('Day', '${e.dayNumber}'),
            DetailRow('Sets', '${e.sets}'),
            DetailRow(
                widget.perArmTargets ? 'Reps per arm per set' : 'Reps per set',
                '${e.reps}')
          ])),
          if (e.cue.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            const Eyebrow('Published cue'),
            Panel(child: Text(e.cue))
          ],
          const SizedBox(height: 16),
          const Text(
              'Watching a tutorial does not record a workout or award points.'),
        ]));
  }
}
