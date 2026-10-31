import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/app_check_in_cubit.dart';
import '../../domain/app_check_in.dart';

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

    if (compact) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (s == null)
          Text(state.message ?? 'Loading your check-in…')
        else ...[
          Text(s.claimedToday
              ? 'Your app check-in is saved. Come back tomorrow.'
              : 'Check in to the app and collect ${s.pointsPerClaim} points.'),
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
    }

    final isEnlargedText = MediaQuery.textScalerOf(context).scale(1.0) > 1.15;

    Widget claimButton(AppCheckInSnapshot snap) {
      if (snap.claimedToday) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check_circle_rounded,
                  size: 15, color: AppColors.success),
              SizedBox(width: 4),
              Text('Claimed today',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft)),
            ],
          ),
        );
      }
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: !ready || state.claiming ? null : onClaim,
        icon: const Icon(Icons.stars_rounded,
            size: 16, color: AppColors.accent),
        label: Text(
          state.claiming
              ? 'Claiming…'
              : 'Claim ${snap.pointsPerClaim} points',
          style: const TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      );
    }

    // Compact sporty horizontal card for Member Home:
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      background: AppColors.primaryTint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (s?.claimedToday ?? false)
                      ? AppColors.successTint
                      : AppColors.accentTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  (s?.claimedToday ?? false)
                      ? Icons.check_rounded
                      : Icons.local_fire_department_rounded,
                  color: (s?.claimedToday ?? false)
                      ? AppColors.success
                      : AppColors.warning,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            s == null
                                ? 'Daily check-in'
                                : '${s.currentStreak}-day streak',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (s != null) ...[
                          const SizedBox(width: 4),
                          Tooltip(
                            message:
                                'Best: ${s.longestStreak} days · Resets at midnight, Malaysia time',
                            triggerMode: TooltipTriggerMode.tap,
                            child: const Icon(Icons.info_outline_rounded,
                                size: 15, color: AppColors.inkSoft),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      s == null
                          ? (state.message ?? 'Loading check-in…')
                          : (s.claimedToday
                              ? 'Saved for today'
                              : '+${s.pointsPerClaim} pts available'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (s?.claimedToday ?? false)
                            ? AppColors.success
                            : AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              if (s != null && !isEnlargedText) ...[
                const SizedBox(width: 8),
                claimButton(s),
              ],
            ],
          ),
          if (s != null && isEnlargedText) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: claimButton(s),
            ),
          ],
          if (s != null && s.days.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (final day in s.days)
                  Expanded(
                    child: Semantics(
                      label:
                          '${day.date}, ${day.claimed ? 'checked in' : 'not checked in'}',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: day.claimed
                                  ? AppColors.primary
                                  : AppColors.surface,
                              border: day.date == s.today
                                  ? Border.all(
                                      color: AppColors.primary, width: 2)
                                  : Border.all(
                                      color: AppColors.hairline, width: 1),
                            ),
                            child: day.claimed
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 14)
                                : null,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            ['M', 'T', 'W', 'T', 'F', 'S', 'S'][
                                DateTime.parse(day.date).weekday - 1],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: day.date == s.today
                                  ? FontWeight.w800
                                  : (day.claimed
                                      ? FontWeight.w700
                                      : FontWeight.w500),
                              color: day.date == s.today
                                  ? AppColors.primary
                                  : (day.claimed
                                      ? AppColors.ink
                                      : AppColors.inkSoft),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (state.status == AppCheckInStatus.loading || state.claiming)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          if (state.message != null && s != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(state.message!,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
            ),
          if (state.status == AppCheckInStatus.error && onRefresh != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton.icon(
                onPressed: state.claiming ? null : onRefresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh check-in',
                    style: TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}
