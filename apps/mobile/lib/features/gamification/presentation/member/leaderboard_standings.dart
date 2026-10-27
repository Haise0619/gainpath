import 'package:flutter/material.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

String _points(int n) => n
    .toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
String _initial(String name) => name.characters.first.toUpperCase();

/// Reference leaderboard presentation over server-confirmed earned rankings.
class LeaderboardStandings extends StatelessWidget {
  const LeaderboardStandings({super.key, required this.data});
  final EarnedPointsLeaderboard data;
  @override
  Widget build(BuildContext context) {
    final you = data.you, podium = data.entries.take(3).toList();
    final ahead = data.entries.where((e) => e.points > you.points).toList();
    final nearest = ahead.isEmpty ? null : ahead.last;
    // Only describe the immediately preceding rank when it is actually loaded.
    final gapKnown = you.rank != null &&
        nearest != null &&
        (data.entries.any((e) => e.isYou) || nearest.rank == you.rank! - 1);
    final message = you.rank == null
        ? 'Earn points to join the rankings.'
        : you.rank == 1
            ? 'You are rank #1. Keep it up!'
            : gapKnown
                ? 'You are rank #${you.rank} — just ${_points(nearest.points - you.points)} points from #${nearest.rank}.'
                : 'You are rank #${you.rank} with ${_points(you.points)} earned points.';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            const Icon(Icons.trending_up_rounded,
                color: Colors.white, size: 23),
            const SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)))
          ])),
      if (podium.isNotEmpty) ...[
        const SizedBox(height: 28),
        Row(
            key: const Key('leaderboard-podium'),
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (podium.length > 1)
                Expanded(child: _PodiumPlace(row: podium[1], place: 1)),
              if (podium.length > 1) const SizedBox(width: 12),
              Expanded(child: _PodiumPlace(row: podium[0], place: 0)),
              if (podium.length > 2) const SizedBox(width: 12),
              if (podium.length > 2)
                Expanded(child: _PodiumPlace(row: podium[2], place: 2)),
            ]),
        const SizedBox(height: 24),
      ],
      if (data.entries.isEmpty)
        const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Panel(
                child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                        'No rankings yet. Be the first to earn points.')))),
      for (final row in data.entries.skip(3))
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RankingRow(row: row)),
      if (you.rank != null && !data.entries.any((e) => e.isYou)) ...[
        const SizedBox(height: 12),
        const Text('Your position',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        _RankingRow(row: you),
      ],
    ]);
  }
}

class _PodiumPlace extends StatelessWidget {
  const _PodiumPlace({required this.row, required this.place});
  final EarnedPointsRank row;
  final int place;
  @override
  Widget build(BuildContext context) {
    final color = row.rank == 1
        ? const Color(0xFFFFD43B)
        : row.rank == 2
            ? const Color(0xFFB7B7C3)
            : const Color(0xFFC98B48);
    return Semantics(
        container: true,
        label:
            '${row.displayName}${row.isYou ? ', You' : ''}, rank ${row.rank}, ${_points(row.points)} points',
        excludeSemantics: true,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (row.rank == 1)
            Icon(Icons.emoji_events_rounded, color: color, size: 22),
          Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2.5),
                  boxShadow: row.rank == 1
                      ? [
                          BoxShadow(
                              color: color.withValues(alpha: .3),
                              blurRadius: 18,
                              spreadRadius: 2)
                        ]
                      : null),
              child: CircleAvatar(
                  backgroundColor:
                      row.isYou ? AppColors.primary : AppColors.primaryTint,
                  child: Text(_initial(row.displayName),
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color:
                              row.isYou ? Colors.white : AppColors.inkSoft)))),
          const SizedBox(height: 9),
          Text(row.displayName,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: row.isYou ? FontWeight.w800 : FontWeight.w500)),
          const SizedBox(height: 3),
          Text(_points(row.points),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Container(
              width: double.infinity,
              height: [122.0, 92.0, 70.0][place],
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 14),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .16),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(top: BorderSide(color: color, width: 3))),
              child: Text('${row.rank}',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: row.rank == 1
                          ? const Color(0xFF866000)
                          : row.rank == 2
                              ? const Color(0xFF656578)
                              : const Color(0xFF8D5422)))),
        ]));
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.row});
  final EarnedPointsRank row;
  @override
  Widget build(BuildContext context) => Semantics(
      container: true,
      label:
          '${row.displayName}${row.isYou ? ', You' : ''}, rank ${row.rank}, ${_points(row.points)} points',
      excludeSemantics: true,
      child: Container(
          key: row.isYou ? const Key('leaderboard-own-row') : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
              color: row.isYou ? AppColors.primaryTint : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: .1))),
          child: LayoutBuilder(builder: (context, c) {
            final compact = c.maxWidth < 260 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3;
            final name = Text(row.displayName,
                style: TextStyle(
                    fontWeight: row.isYou ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 16));
            final points = Text(_points(row.points),
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16));
            return Row(children: [
              CircleAvatar(
                  radius: 15,
                  backgroundColor:
                      row.isYou ? AppColors.primary : AppColors.primaryTint,
                  child: Text('${row.rank}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color:
                              row.isYou ? Colors.white : AppColors.inkSoft))),
              const SizedBox(width: 10),
              CircleAvatar(
                  radius: 19,
                  backgroundColor:
                      row.isYou ? AppColors.primary : AppColors.primaryTint,
                  child: Text(_initial(row.displayName),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color:
                              row.isYou ? Colors.white : AppColors.inkSoft))),
              const SizedBox(width: 12),
              Expanded(
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [name, const SizedBox(height: 5), points])
                      : Row(children: [
                          Expanded(child: name),
                          const SizedBox(width: 12),
                          points
                        ])),
            ]);
          })));
}
