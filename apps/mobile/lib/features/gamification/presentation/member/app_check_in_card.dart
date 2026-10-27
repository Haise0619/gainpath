import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/app_check_in_cubit.dart';

class AppCheckInCard extends StatelessWidget {
  const AppCheckInCard(
      {super.key,
      required this.state,
      required this.onClaim,
      this.onRefresh,
      this.compact = false});
  final bool compact;
  final AppCheckInState state;
  final Future<void> Function() onClaim;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) {
    final s = state.snapshot,
        ready = state.status == AppCheckInStatus.ready ||
            state.status == AppCheckInStatus.error;
    final content =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!compact)
        Row(children: [
          const Icon(Icons.local_fire_department_rounded,
              color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  s == null
                      ? 'Daily app check-in'
                      : '${s.currentStreak}-day check-in streak',
                  style: Theme.of(context).textTheme.titleMedium))
        ]),
      if (!compact) const SizedBox(height: 8),
      if (s == null)
        Text(state.message ?? 'Loading your check-in…')
      else ...[
        Text(s.claimedToday
            ? 'Your app check-in is saved. Come back tomorrow.'
            : 'Check in to the app and collect ${s.pointsPerClaim} points.'),
        if (!compact) ...[
          const SizedBox(height: 6),
          Text(
              'Best ${s.longestStreak} days · resets at midnight, Malaysia time',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Row(children: [
            for (final day in s.days)
              Expanded(
                  child: Semantics(
                      label:
                          '${day.date}, ${day.claimed ? 'checked in' : 'not checked in'}',
                      child: Column(children: [
                        Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: day.claimed
                                    ? AppColors.primary
                                    : AppColors.surface,
                                border: day.date == s.today
                                    ? Border.all(
                                        color: AppColors.primary, width: 2)
                                    : null),
                            child: day.claimed
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 18)
                                : null),
                        const SizedBox(height: 5),
                        Text(
                            [
                              'M',
                              'T',
                              'W',
                              'T',
                              'F',
                              'S',
                              'S'
                            ][DateTime.parse(day.date).weekday - 1],
                            style: Theme.of(context).textTheme.bodySmall)
                      ])))
          ]),
        ],
      ],
      if (state.status == AppCheckInStatus.loading || state.claiming)
        const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator()),
      if (s != null) ...[
        const SizedBox(height: 12),
        SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
                onPressed:
                    !ready || state.claiming || s.claimedToday ? null : onClaim,
                icon: Icon(s.claimedToday
                    ? Icons.check_circle_rounded
                    : Icons.stars_rounded),
                label: Text(state.claiming
                    ? 'Claiming…'
                    : s.claimedToday
                        ? 'Claimed today'
                        : 'Claim ${s.pointsPerClaim} points'))),
      ],
      if (state.message != null && s != null)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(state.message!)),
      if (state.status == AppCheckInStatus.error && onRefresh != null)
        TextButton.icon(
            onPressed: state.claiming ? null : onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh check-in')),
    ]);
    return compact
        ? content
        : Panel(background: AppColors.primaryTint, child: content);
  }
}
