import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AppRole, SessionScope;
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_domain/gamification.dart';
import '../../features/gamification/application/move_and_catch_controller.dart';
import '../../features/gamification/presentation/member/move_and_catch_view.dart';
import '../../features/gamification/presentation/member/move_catch_exit_guard.dart';
import '../../features/gamification/presentation/member/mini_game_reward_status_panel.dart';
import '../../infrastructure/firebase/firebase_mini_game_reward_status_reader.dart';
import '../../infrastructure/firebase/firebase_mini_game_round_repository.dart';
import '../../features/gamification/application/mini_game_round_coordinator.dart';
import '../../infrastructure/firebase/firebase_mini_game_participation_repository.dart';
import '../../features/gamification/presentation/member/mini_game_participation_panel.dart';
import '../../features/gamification/presentation/member/points_history_screen.dart';
import '../../features/gamification/application/rewards_feature_host.dart';
import '../../infrastructure/local/move_catch_best_scores.dart';
import '../../infrastructure/pose/move_catch_pose_camera.dart';

class MoveAndCatchRoute extends StatefulWidget {
  const MoveAndCatchRoute({super.key, this.content});
  final MiniGameContent? content;
  @override
  State<MoveAndCatchRoute> createState() => _MoveAndCatchRouteState();
}

class _MoveAndCatchRouteState extends State<MoveAndCatchRoute>
    with WidgetsBindingObserver {
  MoveAndCatchController? _game;
  Widget? _viewport;
  MiniGameContent? _content;
  MiniGameRewardStatusReader? _rewards;
  MiniGameParticipationRepository? _participation;
  StreamSubscription<AuthState>? _auth;
  final _clock = Stopwatch()..start();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_game != null) return;
    final auth = context.read<AuthBloc>();
    if (!AuthRolePolicy.canEnter(auth.state, allowed: const {AppRole.member})) {
      return;
    }
    final captured = auth.state.session!;
    final content = widget.content;
    if (content != null &&
        content.organizationId == captured.scope.organizationId &&
        content.gameId == MiniGameContent.supportedId) {
      _content = content;
    }
    SessionScope? activeScope() => identical(auth.state.session, captured) &&
            AuthRolePolicy.canEnter(auth.state, allowed: const {AppRole.member})
        ? captured.scope
        : null;
    final camera = MoveCatchPoseCamera(
        scope: captured.scope,
        activeScope: activeScope,
        clockMicros: () => _clock.elapsedMicroseconds);
    _rewards = FirebaseMiniGameRewardStatusReader(
        scope: captured.scope, isCurrent: () => activeScope() != null);
    if (FirebaseMiniGameParticipationRepository.enabled) {
      _participation = FirebaseMiniGameParticipationRepository(
          scope: captured.scope, isCurrent: () => activeScope() != null);
    }
    _game = MoveAndCatchController(
        scope: captured.scope,
        activeScope: activeScope,
        camera: camera,
        bestScores: LocalMoveCatchBestScores(),
        roundTiming: FirebaseMiniGameRoundRepository.enabled ||
                FirebaseMiniGameParticipationRepository.enabled
            ? MiniGameRoundCoordinator(
                repository: FirebaseMiniGameRoundRepository(
                    scope: captured.scope,
                    isCurrent: () => activeScope() != null))
            : null,
        clockMicros: () => _clock.elapsedMicroseconds);
    _viewport = _CameraViewport(camera: camera);
    _auth = auth.stream.listen((_) {
      if (!_game!.current) {
        unawaited(_game!.close());
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _game?.foreground();
    } else {
      unawaited(_game?.background());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_auth?.cancel());
    _game?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _game == null || !_game!.current
      ? Scaffold(
          appBar: AppBar(title: const Text('Move & Catch')),
          body: const Center(
              child: Text('Sign in as a verified Member to play.')))
      : MoveCatchExitGuard(
          controller: _game!,
          builder: (exit) => MoveAndCatchView(
              controller: _game!,
              viewport: _viewport!,
              content: _content,
              onExit: exit,
              participationStatus: _participation == null
                  ? null
                  : MiniGameParticipationPanel(
                      repository: _participation!,
                      onHistory: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => RewardsFeatureHost(
                                  builder: (repo) =>
                                      PointsHistoryScreen(repository: repo)))),
                      roundTiming: _game!.roundTiming),
              rewardStatus: MiniGameRewardStatusPanel(reader: _rewards!)));
}

class _CameraViewport extends StatelessWidget {
  const _CameraViewport({required this.camera});
  final MoveCatchPoseCamera camera;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: camera,
      builder: (context, _) {
        final controller = camera.source.controller;
        if (controller == null || !controller.value.isInitialized) {
          return const ColoredBox(color: Colors.black);
        }
        return ValueListenableBuilder<CameraValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final raw = value.previewSize;
              if (raw == null) return const ColoredBox(color: Colors.black);
              final landscape = value.deviceOrientation ==
                      DeviceOrientation.landscapeLeft ||
                  value.deviceOrientation == DeviceOrientation.landscapeRight;
              return ClipRect(
                  child: SizedBox.expand(
                      child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                              width: landscape ? raw.width : raw.height,
                              height: landscape ? raw.height : raw.width,
                              child: CameraPreview(controller)))));
            });
      });
}
