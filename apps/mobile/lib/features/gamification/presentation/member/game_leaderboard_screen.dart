import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'game_competition_privacy.dart';

class GameLeaderboardScreen extends StatefulWidget {
  const GameLeaderboardScreen({
    super.key,
    required this.repository,
    this.gameId = 'move-catch-v1',
  });

  final MiniGameCompetitionRepository repository;
  final String gameId;

  @override
  State<GameLeaderboardScreen> createState() => _GameLeaderboardScreenState();
}

class _GameLeaderboardScreenState extends State<GameLeaderboardScreen> {
  late String _game;
  String _period = 'week';
  MiniGameScoreLeaderboard? _result;
  bool _loading = false;
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _game = competitiveGameIds.contains(widget.gameId)
        ? widget.gameId
        : 'move-catch-v1';
    unawaited(_load());
  }

  @override
  void didUpdateWidget(GameLeaderboardScreen old) {
    super.didUpdateWidget(old);
    if (!identical(old.repository, widget.repository)) {
      _generation++;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final repo = widget.repository;
    final game = _game;
    final period = _period;
    final generation = ++_generation;

    if (!repo.current) return;
    setState(() {
      _loading = true;
      _failed = false;
      _result = null;
    });

    try {
      final result = await repo
          .leaderboard(gameId: game, period: period)
          .timeout(const Duration(seconds: 12));
      if (!mounted || !repo.current || generation != _generation) return;
      if (result.scope != repo.scope ||
          result.gameId != game ||
          result.period != period) {
        throw const FormatException('Unowned standings');
      }
      setState(() => _result = result);
    } catch (_) {
      if (mounted && repo.current && generation == _generation) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _privacy() async {
    final repo = widget.repository;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(title: const Text('Ranking privacy')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: GameCompetitionPrivacy(repository: repo),
            ),
          ),
        ),
      ),
    );
    if (mounted && repo.current) await _load();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
        stream: context.read<AuthBloc?>()?.stream,
        builder: (context, _) {
          if (!widget.repository.current) {
            return Scaffold(
              backgroundColor: AppColors.bg,
              appBar: AppBar(title: const Text('Game Rankings')),
              body: const Center(child: Text('Ranking session ended.')),
            );
          }

          final gameTitle =
              _game == 'reach-tap-v1' ? 'Reach & Tap' : 'Move & Catch';

          return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: AppBar(
              title: const Text('Game Rankings'),
              actions: [
                IconButton(
                  tooltip: 'Refresh game rankings',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            body: SafeArea(
              child: RefreshIndicator(
                onRefresh: _load,
                color: AppColors.primary,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  children: [
                    // 1. Game Selection Tabs
                    _buildGameSelector(),
                    const SizedBox(height: 16),

                    // 2. Leaderboard Header with Game Title & Period Control
                    _buildLeaderboardHeader(gameTitle),
                    const SizedBox(height: 8),

                    // 3. Weekly Reset & Cadence Notice
                    _buildResetInfoRow(),
                    const SizedBox(height: 6),

                    // 4. Trust Label Notice (Single occurrence upfront)
                    _buildTrustNote(),
                    const SizedBox(height: 16),

                    // 5. Loading / Error / Standings
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child:
                              CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    else if (_failed)
                      _buildErrorCard()
                    else if (_result != null) ...[
                      // 6. Personal Best Card (Visual Focal Point)
                      _buildPersonalBestCard(_result!),
                      const SizedBox(height: 20),

                      // 7. Adaptive Rankings (0 players, 1-2 players, or 3+ with Podium)
                      ..._buildAdaptiveStandings(_result!),
                    ],

                    const SizedBox(height: 24),

                    // 8. Scoring Rules & Ranking Privacy Section
                    _buildRulesAndPrivacySection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      );

  /// 1. Premium segmented game switcher (responsive to 2.0x text scale)
  Widget _buildGameSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08190F2E),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildGameTab(
              id: 'move-catch-v1',
              label: 'Move & Catch',
              icon: Icons.directions_run_rounded,
              selected: _game == 'move-catch-v1',
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildGameTab(
              id: 'reach-tap-v1',
              label: 'Reach & Tap',
              icon: Icons.touch_app_rounded,
              selected: _game == 'reach-tap-v1',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameTab({
    required String id,
    required String label,
    required IconData icon,
    required bool selected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!selected) {
            setState(() => _game = id);
            unawaited(_load());
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x286D28D9),
                      offset: Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.inkSoft,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.ink,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 2. Header with active game title and compact period switcher (Column-based for zero overflow)
  Widget _buildLeaderboardHeader(String gameTitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$gameTitle rankings',
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1EDF9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.hairline),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPeriodPill(
                  periodId: 'week',
                  label: 'Weekly',
                  selected: _period == 'week',
                ),
                _buildPeriodPill(
                  periodId: 'all-time',
                  label: 'All-time',
                  selected: _period == 'all-time',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodPill({
    required String periodId,
    required String label,
    required bool selected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!selected) {
            setState(() => _period = periodId);
            unawaited(_load());
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x10190F2E),
                      offset: Offset(0, 1),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.inkSoft,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// 3. Reset cadence notice
  Widget _buildResetInfoRow() {
    final isWeekly = _period == 'week';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            isWeekly ? Icons.schedule_rounded : Icons.history_rounded,
            size: 13,
            color: AppColors.inkSoft,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            isWeekly
                ? 'Weekly rankings reset every Monday at 00:00 (MYT)'
                : 'Cumulative verified personal records of all time',
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// 4. Trust note (satisfies single match for 'not physically verified')
  Widget _buildTrustNote() {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.verified_user_outlined,
            size: 13,
            color: AppColors.inkSoft,
          ),
        ),
        SizedBox(width: 5),
        Expanded(
          child: Text(
            miniGameCompetitionTrustLabel,
            style: TextStyle(
              color: AppColors.inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// 5. Error card with retry
  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFDC2626), size: 36),
          const SizedBox(height: 8),
          const Text(
            'Could not load game rankings.',
            style: TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Unable to reach ranking server. Please check connection.',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: _load,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryTint,
              foregroundColor: AppColors.primary,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// 6. Personal Best Card (Focal Point - Wrap-based for full 2.0x scale responsiveness)
  Widget _buildPersonalBestCard(MiniGameScoreLeaderboard result) {
    final hasRank = result.you.rank != null && result.you.score != null;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF6F0FE), Color(0xFFECE4FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDD2F3), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x106D28D9),
            offset: Offset(0, 3),
            blurRadius: 10,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header: Badge & Period context
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events_rounded,
                          color: Colors.white, size: 13),
                      SizedBox(width: 4),
                      Text(
                        'PERSONAL BEST',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2D7F5)),
                  ),
                  child: Text(
                    _period == 'week' ? 'This Week' : 'All-Time',
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Main Stats Row (or Unranked state)
          if (hasRank) ...[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                // Rank Box
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFDACCF3)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0C190F2E),
                              offset: Offset(0, 1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          '#${result.you.rank}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Rank',
                            style: TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Official Standing',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Score Box
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${result.you.score}',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      const Text(
                        'Game Score',
                        style: TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFDDD2F3), height: 1),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.primary, size: 14),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _period == 'week'
                        ? 'Best eligible round · Week of ${result.periodKey} (${result.totalParticipants} ranked)'
                        : 'Best eligible completed round of all time (${result.totalParticipants} ranked)',
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Unranked state
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFDACCF3)),
                  ),
                  child: const Icon(
                    Icons.emoji_events_outlined,
                    color: AppColors.inkSoft,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unranked',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Opt in and complete a new round to join.',
                        style: TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 7. Adaptive Standings: 0 players -> Empty state, 1-2 players -> list, 3+ players -> Podium + non-duplicated remaining
  List<Widget> _buildAdaptiveStandings(MiniGameScoreLeaderboard result) {
    final entries = result.entries;

    // 0 players
    if (entries.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.hairline),
          ),
          child: const Column(
            children: [
              Icon(Icons.military_tech_outlined,
                  size: 44, color: AppColors.inkSoft),
              SizedBox(height: 12),
              Text(
                'No Rankings Yet',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'No accepted scores yet. Your first eligible round can start the rankings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    // 1–2 players: compact elegant list
    if (entries.length < 3) {
      return [
        Text(
          'Rankings (${entries.length})',
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (final row in entries) _buildRankRow(row),
      ];
    }

    // 3 or more players: Top 3 Podium + remaining entries (no duplicate Top 3)
    final top3 = entries.take(3).toList();
    final remaining = entries.skip(3).toList();

    return [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          const Text(
            'Top 3',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${entries.length} ranked',
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),

      // Visual Podium
      _buildTop3Podium(top3),
      const SizedBox(height: 20),

      // Remaining rows (rank 4 to 20) without duplicating Top 3
      if (remaining.isNotEmpty) ...[
        Text(
          'Rankings (4–${entries.length})',
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (final row in remaining) _buildRankRow(row),
      ],
    ];
  }

  /// Duolingo/Strava-inspired Top 3 podium
  Widget _buildTop3Podium(List<MiniGameScoreRank> top3) {
    if (top3.length < 3) return const SizedBox.shrink();

    final first = top3[0];
    final second = top3[1];
    final third = top3[2];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06190F2E),
            offset: Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place (Left)
          Expanded(
            child: _buildPodiumPedestal(
              rank: second,
              rankNumber: 2,
              medalColor: const Color(0xFF94A3B8),
              pedestalHeight: 68,
              pedestalColor: const Color(0xFFF1F5F9),
              trophyIcon: Icons.military_tech_rounded,
            ),
          ),
          const SizedBox(width: 6),

          // 1st Place (Center - Elevated)
          Expanded(
            child: _buildPodiumPedestal(
              rank: first,
              rankNumber: 1,
              medalColor: const Color(0xFFF59E0B),
              pedestalHeight: 90,
              pedestalColor: const Color(0xFFFEF3C7),
              trophyIcon: Icons.workspace_premium_rounded,
              isFirst: true,
            ),
          ),
          const SizedBox(width: 6),

          // 3rd Place (Right)
          Expanded(
            child: _buildPodiumPedestal(
              rank: third,
              rankNumber: 3,
              medalColor: const Color(0xFFCD7F32),
              pedestalHeight: 52,
              pedestalColor: const Color(0xFFFBF2EA),
              trophyIcon: Icons.military_tech_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumPedestal({
    required MiniGameScoreRank rank,
    required int rankNumber,
    required Color medalColor,
    required double pedestalHeight,
    required Color pedestalColor,
    required IconData trophyIcon,
    bool isFirst = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Medal / Trophy avatar
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: isFirst ? 44 : 38,
              height: isFirst ? 44 : 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: rank.isYou ? AppColors.primaryTint : Colors.white,
                border: Border.all(
                  color: rank.isYou ? AppColors.primary : medalColor,
                  width: isFirst ? 2.5 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: medalColor.withValues(alpha: 0.25),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(
                trophyIcon,
                color: medalColor,
                size: isFirst ? 24 : 20,
              ),
            ),
            Positioned(
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: medalColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x20000000),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: Text(
                  '#$rankNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Display Name (with You pill if applicable)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            rank.isYou ? '${rank.displayName} · You' : rank.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: rank.isYou ? AppColors.primary : AppColors.ink,
              fontSize: 11,
              fontWeight: rank.isYou ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 2),

        // Score (FittedBox to prevent overflow at 2.0x text scale)
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${rank.score}',
            style: TextStyle(
              color: isFirst ? AppColors.primaryDark : AppColors.ink,
              fontSize: isFirst ? 16 : 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Pedestal step block
        Container(
          width: double.infinity,
          height: pedestalHeight,
          decoration: BoxDecoration(
            color: rank.isYou ? AppColors.primaryTint : pedestalColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(
              color: rank.isYou
                  ? AppColors.primary
                  : medalColor.withValues(alpha: 0.3),
              width: rank.isYou ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '#$rankNumber',
                style: TextStyle(
                  color: rank.isYou
                      ? AppColors.primary
                      : medalColor.withValues(alpha: 0.6),
                  fontSize: isFirst ? 26 : 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Compact, premium rank row for positions 4..20 (and 1..2 when < 3)
  Widget _buildRankRow(MiniGameScoreRank row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: row.isYou ? AppColors.primaryTint : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: row.isYou ? AppColors.primary : AppColors.hairline,
            width: row.isYou ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x04190F2E),
              offset: Offset(0, 1),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          children: [
            // Rank Badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color:
                    row.isYou ? AppColors.primary : const Color(0xFFF3F0FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '#${row.rank}',
                    style: TextStyle(
                      color: row.isYou ? Colors.white : AppColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Display Name
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      row.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 13,
                        fontWeight:
                            row.isYou ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (row.isYou) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'YOU',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Score Column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${row.score}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Text(
                  'Game Score',
                  style: TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 8. Rules and Privacy Section
  Widget _buildRulesAndPrivacySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Scoring & Ranking Rules',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Preserved business rules
          _buildRuleBullet(
            'Best eligible completed round per member (scores are not cumulative).',
          ),
          _buildRuleBullet(
            'Replays improve your personal record; only your best score appears.',
          ),
          _buildRuleBullet(
            'Weekly rankings reset every Monday at 00:00 Malaysia Time.',
          ),
          _buildRuleBullet(
            'No Reward Points are awarded based on rank.',
          ),
          const SizedBox(height: 14),

          // Privacy Action Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _privacy,
              icon: const Icon(Icons.privacy_tip_outlined, size: 18),
              label: const Text('Ranking privacy'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.hairline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5, right: 8),
            child: CircleAvatar(
              radius: 2.5,
              backgroundColor: AppColors.primarySoft,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
