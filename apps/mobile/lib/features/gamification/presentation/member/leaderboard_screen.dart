import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/identity.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _scope = 0;

  static const _podiumColors = [Color(0xFFFFD700), Color(0xFFC0C0C0), Color(0xFFCD7F32)];
  // Comfortably fits the tallest slot's content (avatar 44 + spacing 14 +
  // name/points ~30 + tallest bar 108 ≈ 196) with headroom to spare, so the
  // podium can never overflow regardless of name length.
  static const _podiumHeight = 216.0;
  static const _barHeights = [108.0, 82.0, 62.0]; // 1st, 2nd, 3rd

  @override
  Widget build(BuildContext context) {
    final top3 = context.read<GamificationRepository>().leaderboard.take(3).toList();
    final rest = context.read<GamificationRepository>().leaderboard.skip(3).toList();
    final you = context.read<GamificationRepository>().leaderboard.firstWhere((r) => r[1] == context.read<MemberProfileRepository>().memberName,
        orElse: () => const ['—', '', '0']);
    final youPoints = int.tryParse(you[2].replaceAll(',', '')) ?? 0;
    final ahead = context.read<GamificationRepository>().leaderboard
        .where((r) => (int.tryParse(r[2].replaceAll(',', '')) ?? 0) > youPoints)
        .toList();
    final gap = ahead.isEmpty
        ? 0
        : (int.tryParse(ahead.last[2].replaceAll(',', '')) ?? 0) - youPoints;

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: PageBody(
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('This week')),
              ButtonSegment(value: 1, label: Text('All time')),
            ],
            selected: {_scope},
            onSelectionChanged: (s) => setState(() => _scope = s.first),
          ),
          if (gap > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('You are rank #${you[0]} — just $gap points from #${ahead.last[0]}.',
                        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (top3.length == 3)
            SizedBox(
              height: _podiumHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: _podiumSlot(context, top3[1], 1)),
                  const SizedBox(width: 8),
                  Expanded(child: _podiumSlot(context, top3[0], 0)),
                  const SizedBox(width: 8),
                  Expanded(child: _podiumSlot(context, top3[2], 2)),
                ],
              ),
            ),
          const SizedBox(height: 20),
          ...rest.map((row) {
            final isYou = row[1] == context.read<MemberProfileRepository>().memberName;
            final rankNum = int.tryParse(row[0]) ?? 0;
            final trendUp = rankNum.isEven;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                background: isYou ? AppColors.primaryTint : null,
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isYou ? AppColors.primary : AppColors.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      child: Text(row[0],
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isYou ? Colors.white : AppColors.inkSoft)),
                    ),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isYou ? AppColors.primary : AppColors.surfaceAlt,
                      child: Text(
                        row[1].substring(0, 1),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isYou ? Colors.white : AppColors.inkSoft),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(row[1],
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  isYou ? FontWeight.w700 : FontWeight.w500)),
                    ),
                    Icon(trendUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 14, color: trendUp ? AppColors.success : AppColors.danger),
                    const SizedBox(width: 4),
                    Text(row[2],
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _podiumSlot(BuildContext context, List<String> row, int podiumIndex) {
    final isYou = row[1] == context.read<MemberProfileRepository>().memberName;
    final color = _podiumColors[podiumIndex];
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2.5),
                boxShadow: podiumIndex == 0
                    ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 14, spreadRadius: 1)]
                    : null,
              ),
              padding: const EdgeInsets.all(2),
              child: CircleAvatar(
                backgroundColor: isYou ? AppColors.primary : AppColors.surfaceAlt,
                child: Text(row[1].substring(0, 1),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isYou ? Colors.white : AppColors.inkSoft)),
              ),
            ),
            if (podiumIndex == 0)
              Positioned(
                top: -16,
                child: Icon(Icons.emoji_events_rounded, color: color, size: 20),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(row[1],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: isYou ? FontWeight.w800 : FontWeight.w600)),
        Text(row[2],
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: _barHeights[podiumIndex],
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(top: BorderSide(color: color, width: 3)),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 8),
          child: Text(row[0], style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ),
      ],
    );
  }
}
