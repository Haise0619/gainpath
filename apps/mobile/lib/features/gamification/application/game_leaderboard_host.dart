import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AppRole;
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../../infrastructure/firebase/firebase_mini_game_competition_repository.dart';
import '../../../navigation/session_host.dart';
import '../presentation/member/game_leaderboard_screen.dart';

/// Builds a ranking repository for this captured, verified Member session only.
class GameLeaderboardHost extends StatelessWidget {
  const GameLeaderboardHost({super.key, this.gameId = 'move-catch-v1'});
  final String gameId;
  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc?>();
    final session = auth?.state.session;
    if (auth == null ||
        session == null ||
        !AuthRolePolicy.canEnter(auth.state, allowed: const {AppRole.member})) {
      return Scaffold(
          appBar: AppBar(title: const Text('Game rankings')),
          body: const Center(
              child: Text('Game rankings unavailable for this session.')));
    }
    return CoachSessionHost(
        session: session,
        builder: (_, current) => GameLeaderboardScreen(
            repository: FirebaseMiniGameCompetitionRepository(
                scope: session.scope, isCurrent: current),
            gameId: gameId));
  }
}
