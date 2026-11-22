import 'package:flutter/material.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// Read-only public game results. No balance or score editing is exposed.
class MiniGameStandingsScreen extends StatefulWidget {
  const MiniGameStandingsScreen({
    super.key,
    required this.repository,
    this.embedded = false,
    this.initialGameId,
  });

  final MiniGameCompetitionRepository repository;
  final bool embedded;
  final String? initialGameId;

  @override
  State<MiniGameStandingsScreen> createState() =>
      _MiniGameStandingsScreenState();
}

class _MiniGameStandingsScreenState extends State<MiniGameStandingsScreen> {
  late String _game;
  String _period = 'week';
  MiniGameScoreLeaderboard? _result;
  bool _loading = false, _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _game = widget.initialGameId ?? 'move-catch-v1';
    _load();
  }

  @override
  void didUpdateWidget(MiniGameStandingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialGameId != null &&
        widget.initialGameId != oldWidget.initialGameId &&
        widget.initialGameId != _game) {
      _game = widget.initialGameId!;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation, repo = widget.repository;
    setState(() {
      _loading = true;
      _failed = false;
      _result = null;
    });
    try {
      final r = await repo.leaderboard(gameId: _game, period: _period);
      if (mounted && generation == _generation && repo.current) {
        setState(() => _result = r);
      }
    } catch (_) {
      if (mounted && generation == _generation && repo.current) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.repository.current) {
      return const Center(child: Text('This Admin session has ended.'));
    }

    final content = _buildContent(context);

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Game standings'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.hairline),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: content,
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header & Notice Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.hairline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  const Text(
                    'Independent game leaderboards',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: const Text(
                      miniGameCompetitionTrustLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'One best eligible completed round per Member. No Reward Points are awarded by ranking.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.inkSoft,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Rankings reflect verified sensor session scores. Leaderboard standings are purely competitive and do not confer Reward Points.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Controls Toolbar: Game Selection Cards & Time Filter
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Game Selector Cards
            _buildGameSelectorCard(
              id: 'move-catch-v1',
              title: 'Move & Catch',
              icon: Icons.sports_esports_rounded,
              selected: _game == 'move-catch-v1',
            ),
            _buildGameSelectorCard(
              id: 'reach-tap-v1',
              title: 'Reach & Tap',
              icon: Icons.touch_app_rounded,
              selected: _game == 'reach-tap-v1',
            ),
            const SizedBox(width: 8),

            // Time Period Filter
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.hairline),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPeriodTab(id: 'week', label: 'Weekly'),
                  _buildPeriodTab(id: 'all-time', label: 'All-time'),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Refresh Button
            OutlinedButton.icon(
              onPressed: _loading ? null : _load,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.hairline),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Leaderboard Content State
        if (_loading)
          const LinearProgressIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceAlt,
          )
        else if (_failed)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.danger, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Could not load game standings. Refresh to retry.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (_result != null) ...[
          // Header summary
          Row(
            children: [
              Text(
                '${_result!.totalParticipants} ranked Members · Top 20',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft,
                ),
              ),
              const Spacer(),
              Text(
                'Game: ${_game == 'move-catch-v1' ? 'Move & Catch' : 'Reach & Tap'} · ${_period == 'week' ? 'Weekly' : 'All-time'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Dynamic Leaderboard Presentation
          if (_result!.entries.isEmpty)
            _buildEmptyState()
          else if (_result!.entries.length == 1)
            _buildSingleLeaderCard(_result!.entries.first)
          else if (_result!.entries.length == 2)
            _buildTwoLeadersView(_result!.entries)
          else
            _buildPodiumAndTable(_result!.entries),
        ],
      ],
    );
  }

  Widget _buildGameSelectorCard({
    required String id,
    required String title,
    required IconData icon,
    required bool selected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_game != id) {
            setState(() => _game = id);
            _load();
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryTint.withValues(alpha: 0.35)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.hairline,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 16,
                    color: selected ? Colors.white : AppColors.inkSoft,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primary : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodTab({required String id, required String label}) {
    final selected = _period == id;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_period != id) {
            setState(() => _period = id);
            _load();
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.emoji_events_outlined,
                size: 28,
                color: AppColors.inkSoft,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No eligible published rounds yet.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'When members complete games on their mobile app, their best round of the period will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleLeaderCard(MiniGameScoreRank leader) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Crown & Rank Badge
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(
                Icons.emoji_events_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Member Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${leader.rank}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'CURRENT LEADER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  leader.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          // Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Best accepted Game Score',
                style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${leader.score}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'pts',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTwoLeadersView(List<MiniGameScoreRank> entries) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildRankBadgeCard(
                entries[0],
                accentColor: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFEF3C7),
                icon: Icons.emoji_events_rounded,
                rankLabel: '1st Place',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildRankBadgeCard(
                entries[1],
                accentColor: const Color(0xFF64748B),
                bgColor: const Color(0xFFF1F5F9),
                icon: Icons.military_tech_rounded,
                rankLabel: '2nd Place',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildTable(entries),
      ],
    );
  }

  Widget _buildPodiumAndTable(List<MiniGameScoreRank> entries) {
    return Column(
      children: [
        // Top 3 Podium
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 2nd Place (Silver)
            Expanded(
              child: _buildPodiumStep(
                entry: entries[1],
                rank: 2,
                color: const Color(0xFF64748B),
                bgColor: const Color(0xFFF1F5F9),
                height: 190,
              ),
            ),
            const SizedBox(width: 12),
            // 1st Place (Gold)
            Expanded(
              child: _buildPodiumStep(
                entry: entries[0],
                rank: 1,
                color: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFEF3C7),
                height: 220,
                isLeader: true,
              ),
            ),
            const SizedBox(width: 12),
            // 3rd Place (Bronze)
            Expanded(
              child: _buildPodiumStep(
                entry: entries[2],
                rank: 3,
                color: const Color(0xFFB45309),
                bgColor: const Color(0xFFFFFBEB),
                height: 170,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildTable(entries),
      ],
    );
  }

  Widget _buildPodiumStep({
    required MiniGameScoreRank entry,
    required int rank,
    required Color color,
    required Color bgColor,
    required double height,
    bool isLeader = false,
  }) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLeader ? const Color(0xFFFDE68A) : AppColors.hairline,
          width: isLeader ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text(
              entry.displayName.isNotEmpty
                  ? entry.displayName.substring(0, 1).toUpperCase()
                  : 'M',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${entry.score} pts',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadgeCard(
    MiniGameScoreRank entry, {
    required Color accentColor,
    required Color bgColor,
    required IconData icon,
    required String rankLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(icon, color: accentColor, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rankLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
                Text(
                  entry.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${entry.score} pts',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<MiniGameScoreRank> entries) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          // Header Row
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: AppColors.hairline)),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    'Rank',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Member',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Best accepted Game Score',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Data Rows
          for (var i = 0; i < entries.length; i++) ...[
            Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                border: i < entries.length - 1
                    ? const Border(bottom: BorderSide(color: AppColors.hairline))
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      '#${entries[i].rank}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: entries[i].rank == 1
                            ? const Color(0xFFD97706)
                            : entries[i].rank == 2
                                ? const Color(0xFF64748B)
                                : entries[i].rank == 3
                                    ? const Color(0xFFB45309)
                                    : AppColors.ink,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primaryTint,
                          child: Text(
                            entries[i].displayName.isNotEmpty
                                ? entries[i]
                                    .displayName
                                    .substring(0, 1)
                                    .toUpperCase()
                                : 'M',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          entries[i].displayName,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${entries[i].score}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
