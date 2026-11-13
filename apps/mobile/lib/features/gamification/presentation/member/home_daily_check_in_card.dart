import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/app_check_in_cubit.dart';
import 'daily_check_in_claim_button.dart';

class HomeDailyCheckInCard extends StatelessWidget {
  const HomeDailyCheckInCard({
    super.key,
    required this.state,
    required this.onClaim,
    this.onRefresh,
    this.showDays = true,
  });
  final AppCheckInState state;
  final Future<void> Function() onClaim;
  final Future<void> Function()? onRefresh;
  final bool showDays;
  @override
  Widget build(BuildContext context) {
    final s = state.snapshot;
    final ready = state.status == AppCheckInStatus.ready ||
        state.status == AppCheckInStatus.error;
    final info =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/streak_fire.svg',
            width: 17,
            height: 17,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
                s == null ? 'Check-in status' : '${s.currentStreak}-day streak',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      const SizedBox(height: 2),
      Text(
          s == null
              ? state.message ?? 'Loading check-in…'
              : s.claimedToday
                  ? 'Checked in today'
                  : '+${s.pointsPerClaim} points available today',
          style: TextStyle(
              fontSize: 12,
              fontWeight: (s?.claimedToday ?? false) ? FontWeight.w600 : FontWeight.normal,
              color: (s?.claimedToday ?? false) ? const Color(0xFFEA580C) : AppColors.inkSoft)),
    ]);
    final action = (s != null && ready)
        ? DailyCheckInClaimButton(
            claimed: s.claimedToday,
            claiming: state.claiming,
            points: s.pointsPerClaim,
            onClaim: onClaim,
          )
        : null;
    return Panel(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (MediaQuery.textScalerOf(context).scale(1) > 1.3) ...[
            info,
            if (action != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: action)
          ] else
            Row(children: [
              Expanded(child: info),
              if (action != null) ...[const SizedBox(width: 8), action]
            ]),
          if (showDays && s != null && s.days.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              for (final day in s.days.take(7))
                Expanded(
                    child: Semantics(
                        label:
                            '${day.date}, ${day.claimed ? 'checked in' : 'not checked in'}',
                        child: ExcludeSemantics(
                            child: Column(children: [
                          Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (day.date == s.today && day.claimed)
                                      ? const Color(0xFFFF8A00)
                                      : (day.claimed
                                          ? AppColors.primary
                                          : AppColors.surfaceAlt),
                                  border: day.date == s.today
                                      ? Border.all(
                                          color: day.claimed
                                              ? const Color(0xFFFF8A00)
                                              : AppColors.primary,
                                          width: 2)
                                      : null),
                              child: day.claimed
                                  ? const Icon(Icons.check,
                                      size: 12, color: Colors.white)
                                  : null),
                          const SizedBox(height: 3),
                          Text(
                              const [
                                'M',
                                'T',
                                'W',
                                'T',
                                'F',
                                'S',
                                'S'
                              ][DateTime.parse(day.date).weekday - 1],
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.inkSoft)),
                        ])))),
            ])
          ],
          if (state.status == AppCheckInStatus.loading || state.claiming)
            const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator()),
          if (state.message != null && s != null)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(state.message!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.inkSoft))),
          if (state.status == AppCheckInStatus.error && onRefresh != null)
            TextButton.icon(
                onPressed: state.claiming ? null : onRefresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh check-in')),
        ]));
  }
}
