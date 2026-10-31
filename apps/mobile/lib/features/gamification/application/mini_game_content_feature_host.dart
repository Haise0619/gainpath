import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AppRole;
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../../infrastructure/firebase/firebase_mini_game_content_reader.dart';
import '../../../navigation/session_host.dart';
import '../domain/move_catch_ports.dart';
import '../../../infrastructure/local/move_catch_best_scores.dart';
import '../../../infrastructure/firebase/firebase_mini_game_reward_status_reader.dart';
import '../../../infrastructure/firebase/firebase_mini_game_participation_repository.dart';
import '../../../infrastructure/local/reach_tap_history.dart';
import '../domain/reach_tap_ports.dart';
import '../domain/reach_tap_participation_repository.dart';

class MiniGameContentFeatureHost extends StatelessWidget {
  const MiniGameContentFeatureHost({super.key, required this.builder});
  final Widget Function(MiniGameContentReader, MoveCatchBestScoreStore,
      MiniGameRewardStatusReader, MiniGameParticipationRepository?) builder;
  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>();
    final session = auth.state.session;
    if (session == null ||
        !AuthRolePolicy.canEnter(auth.state, allowed: const {AppRole.member})) {
      return const Scaffold(
          body:
              Center(child: Text('Mini-games unavailable for this session.')));
    }
    return CoachSessionHost(
        session: session,
        builder: (_, current) =>
            RepositoryProvider<ReachTapParticipationRepository>(
                create: (_) => ReachTapParticipationRepository(
                    FirebaseMiniGameParticipationRepository.enabled
                        ? FirebaseMiniGameParticipationRepository(
                            scope: session.scope,
                            isCurrent: current,
                            gameId: MiniGameContent.reachTapId)
                        : null),
                child: RepositoryProvider<ReachTapHistoryStore>(
                    create: (_) => LocalReachTapHistory(),
                    child: builder(
                        FirebaseMiniGameContentReader(
                            scope: session.scope, isCurrent: current),
                        LocalMoveCatchBestScores(),
                        FirebaseMiniGameRewardStatusReader(
                            scope: session.scope, isCurrent: current),
                        FirebaseMiniGameParticipationRepository.enabled
                            ? FirebaseMiniGameParticipationRepository(
                                scope: session.scope, isCurrent: current)
                            : null))));
  }
}
