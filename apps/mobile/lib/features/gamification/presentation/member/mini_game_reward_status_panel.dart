import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class MiniGameRewardStatusPanel extends StatefulWidget {
  const MiniGameRewardStatusPanel({super.key, required this.reader});
  final MiniGameRewardStatusReader reader;
  @override
  State<MiniGameRewardStatusPanel> createState() =>
      _MiniGameRewardStatusPanelState();
}

class _MiniGameRewardStatusPanelState extends State<MiniGameRewardStatusPanel> {
  MiniGameRewardStatus? _status;
  bool _loading = false, _failed = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MiniGameRewardStatusPanel old) {
    super.didUpdateWidget(old);
    if (!identical(old.reader, widget.reader)) _load();
  }

  Future<void> _load() async {
    final reader = widget.reader, generation = ++_generation;
    _status = null;
    _failed = false;
    _loading = reader.current;
    if (!reader.current) return;
    try {
      final status = await reader.overview();
      if (!mounted || generation != _generation || !reader.current) return;
      if (status.scope != reader.scope) throw const FormatException();
      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (_) {
      if (mounted && generation == _generation && reader.current) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
      stream: context.read<AuthBloc?>()?.stream,
      builder: (context, _) {
        if (!widget.reader.current) return const SizedBox.shrink();
        final s = _status, p = s?.policy ?? MiniGameRewardPolicy();
        return Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text('Reward points',
                    style: Theme.of(context).textTheme.titleMedium),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Text('Not active',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700))),
              ]),
          const SizedBox(height: 12),
          Wrap(spacing: 16, runSpacing: 8, children: [
            Text('${s?.earnedPoints ?? '—'} pts earned today',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${s?.remainingPoints ?? '—'} pts remaining'),
          ]),
          const SizedBox(height: 8),
          Text(s == null
              ? 'Draft: ${p.games.single.points} points per eligible round · ${p.dailyPointsCap} shared points per Malaysia day.'
              : '${p.games.single.points} points per eligible round · ${p.dailyPointsCap} shared points per Malaysia day.'),
          Text(
              '${p.games.single.dailyClaimLimit} rewarded round per game type per day. Keep playing after earning limits.'),
          const SizedBox(height: 8),
          const Text(
              'Verified gameplay and reward issuance are not active yet. Game score is separate from reward points.'),
          const SizedBox(height: 6),
          const Text(
              'Daily Check-in and Workout Rewards have separate limits. Resets at midnight, Malaysia time.'),
          if (_loading)
            const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator()),
          if (_failed) ...[
            const SizedBox(height: 8),
            const Text(
                'Daily reward totals are unavailable. No points are confirmed by this screen.'),
            TextButton.icon(
                onPressed: () {
                  setState(() => _loading = true);
                  _load();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh reward status')),
          ],
        ]));
      });
}
