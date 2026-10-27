import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/mini_game_round_coordinator.dart';

class MiniGameParticipationPanel extends StatefulWidget {
  const MiniGameParticipationPanel(
      {super.key, required this.repository, this.roundTiming, this.onHistory});
  final MiniGameParticipationRepository repository;
  final MiniGameRoundCoordinator? roundTiming;
  final VoidCallback? onHistory;
  @override
  State<MiniGameParticipationPanel> createState() =>
      _MiniGameParticipationPanelState();
}

class _MiniGameParticipationPanelState
    extends State<MiniGameParticipationPanel> {
  MiniGameParticipation? _result;
  bool _busy = false, _failed = false;
  int _generation = 0;
  String? _lastAttempt, _retryAttempt;
  MiniGameRoundSyncState? _seenTimingState;
  bool _seenTimingRetry = false;
  @override
  void initState() {
    super.initState();
    widget.roundTiming?.addListener(_onRound);
    _run();
  }

  @override
  void didUpdateWidget(MiniGameParticipationPanel old) {
    super.didUpdateWidget(old);
    if (!identical(old.repository, widget.repository) ||
        !identical(old.roundTiming, widget.roundTiming)) {
      old.roundTiming?.removeListener(_onRound);
      widget.roundTiming?.addListener(_onRound);
      _generation++;
      _result = null;
      _lastAttempt = _retryAttempt = null;
      _busy = _failed = false;
      _run();
    }
  }

  void _onRound() {
    if (!mounted || !widget.repository.current) return;
    final timing = widget.roundTiming;
    if (_seenTimingState != timing?.state ||
        _seenTimingRetry != (timing?.canRetry ?? false)) {
      setState(() {
        _seenTimingState = timing?.state;
        _seenTimingRetry = timing?.canRetry ?? false;
      });
    }
    if (_busy) return;
    final round = widget.roundTiming?.completedRound;
    if (round == null ||
        round.scope != widget.repository.scope ||
        _lastAttempt == round.attemptId) {
      return;
    }
    _lastAttempt = round.attemptId;
    _run(attemptId: round.attemptId);
  }

  Future<void> _run({String? attemptId}) async {
    final repo = widget.repository, generation = ++_generation;
    if (!repo.current) return;
    setState(() {
      _busy = true;
      _failed = false;
      _retryAttempt = attemptId;
    });
    try {
      final r = attemptId == null
          ? await repo.overview()
          : await repo.claim(attemptId);
      if (!mounted || generation != _generation || !repo.current) return;
      if (r.scope != repo.scope) {
        throw const FormatException('Participation session changed.');
      }
      setState(() => _result = r);
    } catch (_) {
      if (mounted && generation == _generation && repo.current) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && generation == _generation && repo.current) {
        setState(() => _busy = false);
        _onRound();
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    widget.roundTiming?.removeListener(_onRound);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
      stream: context.read<AuthBloc?>()?.stream,
      builder: (context, _) {
        if (!widget.repository.current) return const SizedBox.shrink();
        final r = _result, policy = r?.policy, award = r?.award;
        final timing = widget.roundTiming;
        final message = switch (r?.status) {
          'awarded' => '+${award!.points} points earned',
          'already-awarded' =>
            'This round’s ${award!.points} points were already credited.',
          'previously-recorded' => 'This round is already recorded.',
          'game-limit' =>
            'Today’s points earned. Keep playing for your personal best.',
          'daily-limit' =>
            'Daily points limit reached. Keep playing for your personal best.',
          'not-completed' => 'Complete a full round to earn points.',
          'game-disabled' => 'Points are unavailable for this game.',
          _ => r?.active != true
              ? 'Game rewards are not active yet.'
              : policy!.games.single.dailyClaimLimit == 0 ||
                      policy.games.single.points == 0
                  ? 'Points are unavailable for this game.'
                  : r!.claimsToday >= policy.games.single.dailyClaimLimit
                      ? 'Today’s points earned. Keep playing for your personal best.'
                      : r.remainingToday < policy.games.single.points
                          ? 'Daily points limit reached. Keep playing for your personal best.'
                          : 'Complete a round to earn ${policy.games.single.points} points.',
        };
        return Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Mini-game points',
              style: Theme.of(context).textTheme.titleMedium),
          Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(spacing: 16, runSpacing: 8, children: [
            Text('${r?.balance ?? '—'} points balance'),
            Text('${r?.earnedToday ?? '—'} earned today'),
            Text('${r?.remainingToday ?? '—'} remaining today')
          ]),
          const SizedBox(height: 8),
          Text(policy == null
              ? '20 points per round · once per game/day · 60 points daily limit.'
              : '${policy.games.single.points} points per completed round · ${policy.games.single.dailyClaimLimit} per game/day · ${policy.dailyPointsCap} shared daily points.'),
          if (timing?.state == MiniGameRoundSyncState.unavailable) ...[
            const SizedBox(height: 8),
            Text(timing!.canRetry
                ? 'Round timing is not confirmed. Retry before checking participation points.'
                : 'Timing is incomplete for this round. Play again to try participation checking.'),
            if (timing.canRetry)
              TextButton.icon(
                  onPressed: timing.retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry round timing')),
          ],
          if (timing?.state == MiniGameRoundSyncState.starting ||
              timing?.state == MiniGameRoundSyncState.submitting)
            const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Confirming round timing…')),
          if (_busy)
            const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator()),
          if (_failed) ...[
            const SizedBox(height: 8),
            const Text(
                'Participation update unavailable. No new points are confirmed.'),
            TextButton.icon(
                onPressed: _busy ? null : () => _run(attemptId: _retryAttempt),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry participation update'))
          ],
          if (widget.onHistory != null && timing?.completedRound != null)
            TextButton.icon(
                onPressed: _busy ? null : widget.onHistory,
                icon: const Icon(Icons.history),
                label: const Text('View Points History')),
        ]));
      });
}
