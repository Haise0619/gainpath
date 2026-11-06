import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AppRole, SessionScope;
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../features/workout/application/guided_timed_workout_controller.dart';
import '../../features/workout/domain/guided_timed_progress.dart';
import '../../features/workout/domain/published_routine_view.dart';
import '../../features/workout/domain/tutorial_player.dart';
import '../../features/workout/presentation/member/guided_timed_workout_screen.dart';
import '../../infrastructure/media/video_tutorial_player.dart';
import '../../navigation/membership_access_gate.dart';

enum GuidedTimedWorkoutOutcome { saved, skipped, completed }

class GuidedTimedWorkoutRoute extends StatefulWidget {
  const GuidedTimedWorkoutRoute(
      {super.key,
      required this.scope,
      required this.routine,
      required this.exerciseIndex,
      required this.progress,
      required this.persist,
      this.playerFactory = VideoTutorialPlayer.new});
  final SessionScope scope;
  final PublishedRoutine routine;
  final int exerciseIndex;
  final GuidedTimedProgress progress;
  final Future<void> Function(GuidedTimedProgress) persist;
  final TutorialPlayerFactory playerFactory;
  @override
  State<GuidedTimedWorkoutRoute> createState() =>
      _GuidedTimedWorkoutRouteState();
}

class _GuidedTimedWorkoutRouteState extends State<GuidedTimedWorkoutRoute>
    with WidgetsBindingObserver {
  final _clock = Stopwatch()..start();
  GuidedTimedWorkoutController? _controller;
  StreamSubscription<AuthState>? _auth;
  Timer? _ticker;
  bool _revoked = false;
  bool _authorized = false,
      _opened = false,
      _exiting = false,
      _foreground = true;
  String? _error;
  bool _allowed(AuthState state) =>
      state.session?.scope == widget.scope &&
      AuthRolePolicy.canEnter(state, allowed: const {AppRole.member});
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    final auth = context.read<AuthBloc>();
    _authorized = _allowed(auth.state);
    _auth = auth.stream.listen((state) {
      final allowed = !_revoked && _allowed(state);
      if (!allowed) {
        _revoked = true;
        _ticker?.cancel();
        _controller?.dispose();
      }
      if (mounted) setState(() => _authorized = allowed);
    });
    if (_authorized) _open(auth);
  }

  void _open(AuthBloc auth) {
    try {
      if (widget.exerciseIndex < 0 ||
          widget.exerciseIndex >= widget.routine.exercises.length) {
        throw const FormatException();
      }
      final e = widget.routine.exercises[widget.exerciseIndex],
          p = widget.progress;
      final url = e.videoUrl,
          revision = e.mediaRevision,
          generation = e.mediaGeneration;
      if (url == null ||
          revision == null ||
          generation == null ||
          p.entryIndex != widget.exerciseIndex ||
          p.entryId != e.entryId ||
          p.exerciseId != e.exerciseId ||
          p.mediaIdentity !=
              guidedTimedMediaIdentity(
                  videoUrl: url,
                  mediaRevision: revision,
                  mediaGeneration: generation) ||
          jsonEncode(p.prescription.toJson()) !=
              jsonEncode(e.prescription.toJson())) {
        throw const FormatException();
      }
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw const FormatException();
      }
      final player = widget.playerFactory(uri);
      _controller = GuidedTimedWorkoutController(
          progress: p,
          player: player,
          activeScope: () => mounted && _authorized && _allowed(auth.state),
          persist: widget.persist,
          monotonicNow: () => _clock.elapsed);
      _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (_foreground && _authorized) {
          if (ModalRoute.of(context)?.isCurrent == false) {
            if (_controller!.progress.phase == GuidedTimedPhase.working ||
                _controller!.progress.phase == GuidedTimedPhase.resting)
              unawaited(_controller!
                  .interrupt('route obscured')
                  .catchError((Object _) {}));
          } else {
            unawaited(_controller!.tick().catchError((Object _) {}));
          }
        }
      });
      unawaited(_controller!.initialize().catchError((Object _) {}));
    } catch (_) {
      _error =
          'This timed workout is unavailable. Return to the routine and try again.';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && _authorized) {
      unawaited(_controller?.interrupt('background').catchError((Object _) {}));
    }
  }

  Future<void> _leave(GuidedTimedWorkoutOutcome outcome) async {
    if (_exiting || !_authorized || !mounted) return;
    _exiting = true;
    try {
      await _controller!.saveAndExit();
      if (!mounted || !_authorized) return;
      Navigator.of(context).pop(outcome);
    } finally {
      _exiting = false;
    }
  }

  Future<void> _back() async {
    if (_exiting || !_authorized) return;
    if (_controller!.progress.phase == GuidedTimedPhase.completed) {
      Navigator.pop(context, GuidedTimedWorkoutOutcome.completed);
      return;
    }
    await _controller!.pause();
    if (!mounted || !_authorized) return;
    final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Workout paused'),
                content: const Text(
                    'Keep this progress and return to your routine, or continue the workout.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, 'continue'),
                      child: const Text('Continue workout')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, 'skip'),
                      child: const Text('Skip exercise')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, 'save'),
                      child: const Text('Save progress & exit'))
                ]));
    if (!mounted || !_authorized) return;
    if (choice == 'save') await _leave(GuidedTimedWorkoutOutcome.saved);
    if (choice == 'skip') await _leave(GuidedTimedWorkoutOutcome.skipped);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    unawaited(_auth?.cancel());
    _controller?.dispose();
    _clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_authorized) {
      return const Scaffold(
          body: Center(
              child: Text(
                  'This workout is no longer available for this account.')));
    }
    if (_error != null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Timed workout')),
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(24), child: Text(_error!))));
    }
    final c = _controller;
    if (c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return MembershipAccessGate(
        enabled: membershipAccessEnforcementEnabled,
        feature: MembershipAccessFeature.exercise,
        resourceId: widget.progress.exerciseId,
        child: GuidedTimedWorkoutScreen(
            controller: c,
            exerciseName: widget.routine.exercises[widget.exerciseIndex].name,
            onBack: _back,
            onSkip: () => _leave(GuidedTimedWorkoutOutcome.skipped),
            onCompleted: () {
              if (_authorized &&
                  c.progress.phase == GuidedTimedPhase.completed) {
                Navigator.of(context).pop(GuidedTimedWorkoutOutcome.completed);
              }
            }));
  }
}
