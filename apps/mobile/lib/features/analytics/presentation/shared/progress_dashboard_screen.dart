import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../member/activity_timeline_screen.dart';
import '../member/body_metrics_screen.dart';
import '../member/gamification_progress_screen.dart';
import '../member/goal_progress_screen.dart';
import '../member/posture_accuracy_screen.dart';
import '../member/widgets/report_preview_tile.dart';
import '../member/widgets/local_progress_widgets.dart';
import '../member/workout_performance_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gamification.dart';

/// AD-M5.1 — View Personalized Progress Dashboard. The hub for every
/// Progress & Report screen: a computed highlight up top, four tappable
/// stat cards that route straight into the report they summarise, then
/// one entry card per remaining deep-dive, each carrying its own
/// spark-chart preview so a trend is visible before the member ever taps
/// in. Everything reveals with a short staggered fade so the page feels
/// alive on open rather than dumping every panel at once.
class ProgressDashboardScreen extends StatefulWidget {
  const ProgressDashboardScreen(
      {super.key,
      this.localProgress,
      this.onRefresh,
      this.onOpenWorkout,
      this.onOpenHistory,
      this.onOpenPerformance,
      this.onOpenForm});

  final MemberLocalProgress? localProgress;
  final Future<void> Function()? onRefresh;
  final void Function(LocalWorkoutProgressRecord)? onOpenWorkout;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenPerformance;
  final VoidCallback? onOpenForm;

  @override
  State<ProgressDashboardScreen> createState() =>
      _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _reveal(Widget child, double start, double end) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: animation
            .drive(Tween(begin: const Offset(0, 0.06), end: Offset.zero)),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final local = widget.localProgress;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final columns =
        MediaQuery.sizeOf(context).width < 360 || scale > 1.3 ? 1 : 2;

    // The volume record check is computed, not asserted, so this stays
    // correct if the underlying weekly figures ever change.
    final volume = local == null
        ? context.read<AnalyticsRepository>().volumeTrend
        : <int>[];
    final isRecordWeek = volume.isNotEmpty &&
        volume.last >= volume.reduce((a, b) => a > b ? a : b);
    final openPerformance = widget.onOpenPerformance ??
        () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    WorkoutPerformanceScreen(localProgress: local)));
    final openForm = widget.onOpenForm ??
        () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => PostureAccuracyScreen(localProgress: local)));
    final openHistory = widget.onOpenHistory ??
        () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ActivityTimelineScreen(
                    localProgress: local,
                    onRefresh: widget.onRefresh,
                    onOpenWorkout: widget.onOpenWorkout)));

    return Scaffold(
      appBar: AppBar(title: const Text('Your progress'), actions: [
        if (widget.onRefresh != null)
          IconButton(
              tooltip: 'Refresh',
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh_rounded))
      ]),
      body: PageBody(
        children: [
          _reveal(
            _HighlightCard(
              isRecordWeek: isRecordWeek,
              volumeThisWeek: volume.isEmpty ? 0 : volume.last,
              headlineOverride: local == null
                  ? null
                  : '${local.weeklySessions} saved camera sessions this week',
              detailOverride: local == null
                  ? null
                  : 'Local measurements remain provisional. A saved capture does not imply a completed routine.',
              streak: local == null
                  ? context.read<GamificationRepository>().streak
                  : 0,
              longestStreak: local == null
                  ? context.read<GamificationRepository>().longestStreak
                  : 0,
            ),
            0.0,
            0.6,
          ),
          const SizedBox(height: 20),
          Eyebrow(local == null
              ? 'This month at a glance'
              : 'This week at a glance'),
          _reveal(
            GridView(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: 190 * scale,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StatCard(
                  icon: Icons.event_available_rounded,
                  value: local == null ? '18' : '${local.weeklySessions}',
                  label: local == null ? 'Sessions' : 'Saved sessions',
                  delta: local == null
                      ? '+3 vs last month'
                      : 'Camera captures this week',
                  deltaColor: AppColors.success,
                  onTap: openHistory,
                ),
                _StatCard(
                  icon: Icons.verified_rounded,
                  value: local == null ? '84%' : '-',
                  label: 'Avg Form',
                  delta: local == null ? '+5 pts trend' : '-',
                  deltaColor: AppColors.success,
                  onTap: openForm,
                ),
                _StatCard(
                  icon: Icons.fitness_center_rounded,
                  value: local == null ? '3,400' : '-',
                  label: 'kg Volume',
                  delta: local == null ? '+13% this week' : '-',
                  deltaColor: AppColors.success,
                  onTap: openPerformance,
                ),
                _StatCard(
                  icon: Icons.local_fire_department_rounded,
                  value: local == null
                      ? '${context.read<GamificationRepository>().streak}'
                      : '-',
                  label: 'Day Streak',
                  delta: local == null
                      ? 'Best ${context.read<GamificationRepository>().longestStreak} days'
                      : '-',
                  deltaColor: AppColors.accentDark,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              GamificationProgressScreen(live: local != null))),
                ),
              ],
            ),
            0.1,
            0.75,
          ),
          const SizedBox(height: 20),
          const Eyebrow('Deep dives'),
          _reveal(
            Column(
              children: [
                ReportPreviewTile(
                  icon: Icons.bar_chart_rounded,
                  title: 'Workout performance',
                  subtitle: 'Volume and muscle group split',
                  sparkData: local == null
                      ? context
                          .read<AnalyticsRepository>()
                          .volumeTrend
                          .map((v) => v.toDouble())
                          .toList()
                      : const [],
                  onTap: openPerformance,
                ),
                const SizedBox(height: 10),
                ReportPreviewTile(
                  icon: Icons.show_chart_rounded,
                  title: 'Posture accuracy',
                  subtitle: 'How your form is changing',
                  sparkData: local == null
                      ? context
                          .read<AnalyticsRepository>()
                          .postureTrend
                          .map((v) => v.toDouble())
                          .toList()
                      : const [],
                  sparkColor: AppColors.success,
                  onTap: openForm,
                ),
                const SizedBox(height: 10),
                ReportPreviewTile(
                  icon: Icons.history_rounded,
                  title: 'Activity timeline',
                  subtitle: 'Everything you have logged',
                  sparkData: local == null
                      ? context
                          .read<AnalyticsRepository>()
                          .sessionsPerWeek
                          .map((v) => v.toDouble())
                          .toList()
                      : const [],
                  sparkColor: AppColors.primarySoft,
                  onTap: openHistory,
                ),
                const SizedBox(height: 10),
                ReportPreviewTile(
                  icon: Icons.flag_rounded,
                  title: 'Goal progress',
                  subtitle: 'How you are tracking against your targets',
                  sparkData: local == null ? const [75, 99, 86] : const [],
                  sparkColor: AppColors.info,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              GoalProgressScreen(live: local != null, localProgress: local))),
                ),
                const SizedBox(height: 10),
                ReportPreviewTile(
                  icon: Icons.emoji_events_rounded,
                  title: 'Points & streak',
                  subtitle: 'Your gamification momentum',
                  sparkData: local == null
                      ? context
                          .read<AnalyticsRepository>()
                          .pointsHistory
                          .map((v) => v.toDouble())
                          .toList()
                      : const [],
                  sparkColor: AppColors.accentDark,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              GamificationProgressScreen(live: local != null))),
                ),
                const SizedBox(height: 10),
                ReportPreviewTile(
                  icon: Icons.monitor_weight_rounded,
                  title: 'Body metrics',
                  subtitle: 'Weight trend and BMI',
                  sparkData: local == null
                      ? context
                          .read<AnalyticsRepository>()
                          .weightHistory
                          .map((e) => e.weightKg)
                          .toList()
                      : const [],
                  sparkColor: AppColors.primaryDark,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              BodyMetricsScreen(live: local != null))),
                ),
              ],
            ),
            0.25,
            1.0,
          ),
          if (local != null) ...[
            const SizedBox(height: 20),
            const Eyebrow('Measured camera activity'),
            LocalProgressPeriod(progress: local),
            const SizedBox(height: 10),
            GridView(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: 190 * scale,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StatCard(
                      icon: Icons.fitness_center_rounded,
                      value: '${local.weeklyRepetitions}',
                      label: 'Full reps',
                      delta: 'Measured full repetitions',
                      deltaColor: AppColors.inkSoft,
                      onTap: openPerformance),
                  _StatCard(
                      icon: Icons.timelapse_rounded,
                      value: '${local.weeklyPartialRepetitions}',
                      label: 'Partial attempts',
                      delta: 'Separate from full reps',
                      deltaColor: AppColors.inkSoft,
                      onTap: openPerformance),
                  _StatCard(
                      icon: Icons.visibility_rounded,
                      value: local.weeklyCoverage == null
                          ? '-'
                          : localProgressCoverage(local.weeklyCoverage),
                      label: 'Measurement coverage',
                      delta: 'Tracked / (tracked + rejected)',
                      deltaColor: AppColors.inkSoft,
                      onTap: openForm),
                ]),
            const SizedBox(height: 20),
            const Eyebrow('Recent sessions'),
            if (local.records.isEmpty)
              const Panel(child: Text('No saved camera sessions yet.')),
            ...local.records.take(3).map((record) => LocalProgressRecordTile(
                record: record,
                utcOffset: local.utcOffset,
                onOpenWorkout: widget.onOpenWorkout)),
          ],
        ],
      ),
    );
  }
}

/// The one thing on this page most worth knowing right now, computed from
/// the same series the reports below chart — not a decorative banner.
class _HighlightCard extends StatelessWidget {
  final String? headlineOverride, detailOverride;
  final bool isRecordWeek;
  final int volumeThisWeek;
  final int streak;
  final int longestStreak;

  const _HighlightCard({
    this.headlineOverride,
    this.detailOverride,
    required this.isRecordWeek,
    required this.volumeThisWeek,
    required this.streak,
    required this.longestStreak,
  });

  @override
  Widget build(BuildContext context) {
    final daysToPersonalBest = longestStreak - streak;
    final String headline;
    final String detail;
    final IconData icon;
    if (isRecordWeek) {
      headline = 'New personal best';
      detail =
          '$volumeThisWeek kg lifted this week — your highest volume week yet. Keep the momentum going.';
      icon = Icons.military_tech_rounded;
    } else if (daysToPersonalBest > 0) {
      headline = '$daysToPersonalBest days from your best streak';
      detail =
          'You are on a $streak-day streak, chasing your personal best of $longestStreak days.';
      icon = Icons.local_fire_department_rounded;
    } else {
      headline = 'You matched your longest streak';
      detail = '$streak days and counting — this is your best run yet.';
      icon = Icons.emoji_events_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 22,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headlineOverride ?? headline,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2)),
                const SizedBox(height: 5),
                Text(detailOverride ?? detail,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 12.5,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One tile in the 2x2 summary grid. Every cell is forced to the same
/// width and height by the parent `GridView.count` (not by hoping the
/// text happens to fit), and the label itself is capped to a single line
/// as a second line of defence — together these are what keep all four
/// cards visually symmetric regardless of label length. Tapping a card
/// routes straight into the report it summarises, so the numbers up top
/// are an entry point rather than a dead end.
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String delta;
  final Color deltaColor;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.delta,
    required this.deltaColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: AppColors.primary),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppColors.inkSoft),
              ],
            ),
            Text(value,
                style: Theme.of(context).textTheme.headlineMedium, maxLines: 1),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              delta,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: deltaColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
