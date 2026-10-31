import 'dart:async';
import '../../features/gamification/application/mini_game_competition_coordinator.dart';
import '../../features/gamification/presentation/member/game_competition_privacy.dart';
import '../../features/gamification/presentation/member/game_competition_result_status.dart';
import '../../features/gamification/presentation/member/game_leaderboard_screen.dart';
import '../../infrastructure/firebase/firebase_mini_game_competition_repository.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AppRole, SessionScope;
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_domain/gamification.dart';
import '../../features/gamification/domain/mini_game_launch.dart';
import '../../infrastructure/firebase/firebase_mini_game_participation_repository.dart';
import '../../features/gamification/presentation/member/mini_game_participation_panel.dart';
import '../../features/gamification/presentation/member/points_history_screen.dart';
import '../../features/gamification/application/rewards_feature_host.dart';
import '../../features/gamification/application/reach_tap_controller.dart';
import '../../features/gamification/application/mini_game_round_coordinator.dart';
import '../../infrastructure/firebase/firebase_mini_game_round_repository.dart';
import '../../features/gamification/presentation/member/reach_tap_exit_guard.dart';
import '../../features/gamification/presentation/member/reach_tap_view.dart';
import '../../infrastructure/local/reach_tap_history.dart';
import '../../infrastructure/pose/reach_tap_pose_camera.dart';

class ReachTapRoute extends StatefulWidget {
  const ReachTapRoute({super.key, this.content, this.playAndEarn = false});
  final MiniGameContent? content;
  final bool playAndEarn;
  @override
  State<ReachTapRoute> createState() => _ReachTapRouteState();
}

class _ReachTapRouteState extends State<ReachTapRoute>
    with WidgetsBindingObserver {
  final _clock = Stopwatch()..start();
  ReachTapController? _game;
  MiniGameParticipationRepository? _participation;
  Widget? _viewport;
  StreamSubscription<AuthState>? _auth;
  bool _foreground = true;
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
    SessionScope? activeScope() => identical(auth.state.session, captured) &&
            AuthRolePolicy.canEnter(auth.state, allowed: const {AppRole.member})
        ? captured.scope
        : null;
    final camera = ReachTapPoseCamera(
        scope: captured.scope,
        activeScope: activeScope,
        clockMicros: () => _clock.elapsedMicroseconds);
    final timing = MiniGameRoundCoordinator(
        repository: FirebaseMiniGameRoundRepository(
            scope: captured.scope,
            isCurrent: () => activeScope() != null,
            gameId: 'reach-tap-v1'));
    final competition = MiniGameCompetitionCoordinator(
        repository: FirebaseMiniGameCompetitionRepository(
            scope: captured.scope, isCurrent: () => activeScope() != null),
        timing: timing,
        gameId: 'reach-tap-v1');
    if (FirebaseMiniGameParticipationRepository.enabled) {
      _participation = FirebaseMiniGameParticipationRepository(
          scope: captured.scope,
          isCurrent: () => activeScope() != null,
          gameId: MiniGameContent.reachTapId);
    }
    _game = ReachTapController(
        scope: captured.scope,
        activeScope: activeScope,
        camera: camera,
        competition: competition,
        roundTiming: timing,
        earningAvailable: () async {
          final repo = _participation;
          if (repo == null || !repo.current) return false;
          final result = await repo.overview();
          return repo.current &&
              result.scope == repo.scope &&
              MiniGameLaunchArguments.canEarn(
                  result, MiniGameContent.reachTapId);
        },
        history: LocalReachTapHistory(),
        clockMicros: () => _clock.elapsedMicroseconds);
    _game!.setRoundTimingConsent(widget.playAndEarn);
    if (!_foreground) unawaited(_game!.background());
    _viewport = _ReachTapViewport(camera: camera);
    _auth = auth.stream.listen((_) {
      if (!_game!.current) {
        unawaited(_game!.close());
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
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
    _clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _game;
    if (c == null || !c.current) {
      return const Scaffold(
          body: SafeArea(
              child: Center(
                  child: Text(
                      'Sign in as a verified Member to play Reach & Tap.'))));
    }
    return ReachTapExitGuard(
        controller: c,
        builder: (exit) => ReachTapView(
            controller: c,
            viewport: _viewport!,
            onExit: exit,
            onChangeMode: () => Navigator.of(context).maybePop(),
            participationStatus: !c.roundTimingConsent || _participation == null
                ? null
                : MiniGameParticipationPanel(
                    repository: _participation!,
                    roundTiming: c.roundTiming,
                    onHistory: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => RewardsFeatureHost(
                                builder: (repo) =>
                                    PointsHistoryScreen(repository: repo))))),
            competitionConsent: GameCompetitionPrivacy(
                repository: c.competition!.repository,
                onConfirmed: c.competition!.acceptPreference),
            competitionStatus:
                GameCompetitionResultStatus(coordinator: c.competition!),
            onLeaderboard: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => GameLeaderboardScreen(repository: c.competition!.repository, gameId: 'reach-tap-v1'))),
            content: widget.content));
  }
}

class _ReachTapViewport extends StatelessWidget {
  const _ReachTapViewport({required this.camera});
  final ReachTapPoseCamera camera;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        camera.configureViewport(box.maxWidth, box.maxHeight);
        return ListenableBuilder(
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
                    if (raw == null) {
                      return const ColoredBox(color: Colors.black);
                    }
                    final landscape = value.deviceOrientation ==
                            DeviceOrientation.landscapeLeft ||
                        value.deviceOrientation ==
                            DeviceOrientation.landscapeRight;
                    return ClipRect(
                        child: SizedBox.expand(
                            child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                    width: landscape ? raw.width : raw.height,
                                    height: landscape ? raw.height : raw.width,
                                    child: CameraPreview(controller)))));
                  });
            });
      });
}
