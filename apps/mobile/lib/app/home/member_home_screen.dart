import '../di/chatbot_factory.dart';
import '../../features/gamification/application/app_check_in_cubit.dart';
import '../../features/gamification/presentation/member/app_check_in_card.dart';
import 'dart:math' as math;
import '../../features/gamification/application/rewards_feature_host.dart';
import 'package:gainpath_domain/analytics.dart';
import '../../features/analytics/presentation/member/widgets/local_progress_widgets.dart';
import '../../features/workout/data/published_routine.dart';
import '../../features/workout/domain/routine_attempt.dart';
import '../../features/analytics/presentation/member/widgets/routine_progress_card.dart';
import 'package:flutter/material.dart';
import '../../features/gamification/application/gamification_bloc.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../routing/workout_prep_route.dart';
import '../../features/workout/presentation/member/equipment_scanner_screen.dart';
import '../../features/analytics/presentation/member/goal_progress_screen.dart';
import '../../features/analytics/presentation/shared/progress_dashboard_screen.dart';
import '../../features/chatbot/presentation/member/chatbot_screen.dart';
import '../../features/chatbot/presentation/member/saved_advice_screen.dart';
import '../../features/gamification/presentation/member/gamification_dashboard_screen.dart';
import '../../features/gamification/presentation/member/leaderboard_screen.dart';
import '../../features/gamification/presentation/member/mini_games_screen.dart';
import '../../features/coaching/presentation/member/booking_schedule_screen.dart';
import '../../features/coaching/presentation/member/browse_coaches_screen.dart';
import '../../features/membership/presentation/shared/membership_dashboard_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AuthSession, FitnessProfile;

/// Member landing screen — the hub every other member flow is reachable
/// from. It carries the daily check-in prompt (AD-M3.2), the broadcast
/// banner (AD-M11.4), the primary entry into the tracked-workout flow
/// (AD-M2.2), and a quick-action grid so the high-frequency destinations
/// are one tap away rather than buried behind a tab.
///
/// The AI coach sits on a persistent floating action button here rather
/// than in the app bar, matching the design direction's note that
/// consulting it is usually prompted by something already on screen.
class MemberHomeScreen extends StatefulWidget {
  const MemberHomeScreen(
      {super.key,
      this.liveSession,
      this.appCheckIn,
      this.onAppClaim,
      this.onRefreshCheckIn,
      this.onOpenCoachingUpdates,
      this.liveProfile,
      this.publishedRoutine,
      this.routineStatusMessage,
      this.onStartWorkout,
      this.localProgress,
      this.routineProgress,
      this.onOpenRoutineHistory,
      this.onOpenRoutine,
      this.progressError,
      this.progressWarnings = const [],
      this.onRefreshProgress,
      this.onRefreshRoutines,
      this.announcements,
      this.onRefreshAnnouncements,
      this.onOpenRewards,
      this.onOpenProgress,
      this.onOpenHistory,
      this.onOpenEquipment,
      this.onOpenCoaches,
      this.onOpenBookings,
      this.onOpenWorkout});

  final AuthSession? liveSession;
  final AppCheckInState? appCheckIn;
  final Future<void> Function()? onAppClaim, onRefreshCheckIn;
  final VoidCallback? onOpenCoachingUpdates;
  final FitnessProfile? liveProfile;
  final PublishedRoutine? publishedRoutine;
  final String? routineStatusMessage;
  final VoidCallback? onStartWorkout;
  final MemberLocalProgress? localProgress;
  final RoutineProgress? routineProgress;
  final VoidCallback? onOpenRoutineHistory;
  final void Function(RoutineAttempt)? onOpenRoutine;
  final String? progressError;
  final List<String> progressWarnings;
  final Future<void> Function()? onRefreshProgress;
  final Future<void> Function()? onRefreshRoutines;
  final Widget? announcements;
  final Future<void> Function()? onRefreshAnnouncements;
  final VoidCallback? onOpenProgress, onOpenHistory, onOpenRewards;
  final VoidCallback? onOpenEquipment;
  final VoidCallback? onOpenCoaches, onOpenBookings;
  final void Function(LocalWorkoutProgressRecord)? onOpenWorkout;

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen>
    with SingleTickerProviderStateMixin {
  bool _dismissedBroadcast = false;
  final _homeScroll = ScrollController();

  late final AnimationController _claimController;
  late final Animation<double> _claimScale;

  @override
  void initState() {
    super.initState();
    _claimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    // Scale-and-settle: overshoot then relax, per the motion rule that
    // gamification moments are the one place expressive motion is allowed.
    _claimScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.06), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 60),
    ]).animate(
        CurvedAnimation(parent: _claimController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _homeScroll.dispose();
    _claimController.dispose();
    super.dispose();
  }

  void _claim() {
    context.read<GamificationBloc>().add(const DailyCheckInClaimed());
    _claimController.forward(from: 0);
    showToast(context,
        'Checked in. +${RewardPolicy.dailyCheckIn} points, streak extended.');
  }

  Future<void> _refresh() async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) showToast(context, 'Up to date.');
  }

  Future<void> _refreshLive() async {
    await Future.wait<void>([
      if (widget.onRefreshProgress != null) widget.onRefreshProgress!(),
      if (widget.onRefreshCheckIn != null) widget.onRefreshCheckIn!(),
      if (widget.onRefreshRoutines != null) widget.onRefreshRoutines!(),
      if (widget.onRefreshAnnouncements != null)
        widget.onRefreshAnnouncements!(),
    ]);
  }

  Future<void> _openAnnouncements() async {
    if (_homeScroll.hasClients) {
      await _homeScroll.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
    if (mounted) await widget.onRefreshAnnouncements?.call();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  /// The member's next confirmed coaching session, if any.
  Booking? get _nextBooking {
    final upcoming = context
        .read<BookingRepository>()
        .memberBookings
        .where((b) =>
            b.status == BookingStatus.confirmed &&
            b.start.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  Future<void> _go(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted && widget.liveSession != null) {
      await widget.onRefreshProgress?.call();
      await widget.onRefreshCheckIn?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.liveSession != null;
    final gamification = live ? null : context.watch<GamificationBloc>().state;
    final firstName = live
        ? (widget.liveSession!.displayName?.trim().isNotEmpty == true
            ? widget.liveSession!.displayName!.trim().split(' ').first
            : widget.liveSession!.email.split('@').first)
        : context.read<MemberProfileRepository>().memberName.split(' ').first;
    final nextBooking = live ? null : _nextBooking;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: live
            ? () => _go(buildMemberChatbot(widget.liveSession!))
            : () => _go(const ChatbotScreen()),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
        label: const Text('AI coach'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: live ? _refreshLive : _refresh,
        child: CustomScrollView(
          controller: _homeScroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _HeroHeader(
                greeting: _greeting,
                firstName: firstName,
                points: live
                    ? widget.appCheckIn?.snapshot?.balance
                    : gamification?.points,
                live: live,
                onOpenCoachingUpdates: widget.onOpenCoachingUpdates,
                onOpenAnnouncements: live && widget.announcements != null
                    ? _openAnnouncements
                    : null,
                avatarText: live
                    ? (firstName.isEmpty
                        ? '?'
                        : firstName.substring(0, 1).toUpperCase())
                    : 'ZY'),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
              sliver: SliverList.list(
                children: [
                  if (widget.announcements != null) ...[
                    widget.announcements!,
                    const SizedBox(height: 14),
                  ] else if (!live && !_dismissedBroadcast) ...[
                    _BroadcastBanner(
                        live: live,
                        onDismiss: () =>
                            setState(() => _dismissedBroadcast = true)),
                    const SizedBox(height: 14),
                  ],
                  const Eyebrow("Today's session"),
                  _TodayWorkoutCard(
                      live: live,
                      publishedRoutine: widget.publishedRoutine,
                      routineStatusMessage: widget.routineStatusMessage,
                      onStart: live
                          ? widget.onStartWorkout ??
                              () => _go(WorkoutPrepRoute(
                                  publishedRoutine: widget.publishedRoutine))
                          : () => _go(const WorkoutPrepRoute(live: false))),
                  const SizedBox(height: 16),
                  if (live && widget.appCheckIn != null)
                    AppCheckInCard(
                        state: widget.appCheckIn!,
                        onClaim: widget.onAppClaim ?? () async {},
                        onRefresh: widget.onRefreshCheckIn)
                  else
                    _StreakCard(
                      live: live,
                      claimed: gamification?.checkedInToday ?? false,
                      scale: _claimScale,
                      onClaim: live ? () => showUnavailable(context) : _claim,
                      reward: RewardPolicy.dailyCheckIn,
                    ),
                  const SizedBox(height: 20),
                  if (live) ...[
                    RoutineProgressCard(
                        progress: widget.routineProgress,
                        onOpenHistory: widget.onOpenRoutineHistory,
                        onOpenAttempt: widget.onOpenRoutine),
                    const SizedBox(height: 16),
                  ],
                  const Eyebrow('This week'),
                  _RingStatsRow(live: live, progress: widget.localProgress),
                  if (live) ...[
                    const SizedBox(height: 8),
                    if (widget.localProgress != null)
                      LocalProgressPeriod(progress: widget.localProgress!),
                    Text(widget.progressError ??
                        (widget.localProgress == null
                            ? 'Loading saved camera sessions…'
                            : 'Saved local measurements · provisional; no rewards implied.')),
                    if (widget.progressError != null)
                      TextButton(
                          onPressed: widget.onRefreshProgress,
                          child: const Text('Retry local progress')),
                    ...widget.progressWarnings.map((warning) => Text(warning)),
                    const SizedBox(height: 16),
                    const Eyebrow('Recent local workouts'),
                    if (widget.localProgress?.records.isEmpty == true)
                      const Panel(child: Text('No saved camera sessions yet.')),
                    ...?widget.localProgress?.records.take(3).map((record) =>
                        LocalProgressRecordTile(
                            record: record,
                            utcOffset: widget.localProgress!.utcOffset,
                            onOpenWorkout: widget.onOpenWorkout)),
                    TextButton(
                        onPressed: widget.onOpenHistory,
                        child: const Text('View local workout history')),
                  ],
                  const SizedBox(height: 20),
                  if (live || nextBooking != null) ...[
                    const Eyebrow('Next with a coach'),
                    _NextSessionCard(
                      booking: nextBooking,
                      onTap: live
                          ? widget.onOpenBookings ??
                              () => showUnavailable(context)
                          : () => _go(const BookingScheduleScreen()),
                    ),
                    const SizedBox(height: 20),
                  ],
                  const Eyebrow('Quick access'),
                  _QuickActionsGrid(
                      onOpenRewards: widget.onOpenRewards,
                      onSelect: _go,
                      enabled: !live,
                      onOpenSavedAdvice: live
                          ? () => _go(buildMemberChatbot(widget.liveSession!,
                              openSavedAdvice: true))
                          : null,
                      onOpenEquipment: widget.onOpenEquipment,
                      onOpenCoaches: widget.onOpenCoaches,
                      onOpenBookings: widget.onOpenBookings,
                      onOpenProgress: widget.onOpenProgress),
                  const SizedBox(height: 20),
                  const Eyebrow('Goal progress'),
                  _GoalPreviewCard(
                      live: live,
                      liveProfile: widget.liveProfile,
                      onTap: live
                          ? () => _go(GoalProgressScreen(
                              live: true, localProgress: widget.localProgress))
                          : () => _go(const GoalProgressScreen())),
                  const SizedBox(height: 20),
                  _MembershipStrip(
                      live: live,
                      onTap: live
                          ? () => _go(
                              const MembershipDashboardScreen(connected: true))
                          : () => _go(const MembershipDashboardScreen())),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Collapsing gradient header. Expanded it carries the greeting and the
/// live points balance; collapsed it leaves just the wordmark so the
/// content below keeps the full viewport while scrolling.
class _HeroHeader extends StatelessWidget {
  final String greeting;
  final String firstName;
  final int? points;
  final bool live;
  final String avatarText;
  final VoidCallback? onOpenAnnouncements;
  final VoidCallback? onOpenCoachingUpdates;

  const _HeroHeader(
      {required this.greeting,
      required this.firstName,
      required this.points,
      required this.live,
      this.onOpenAnnouncements,
      this.onOpenCoachingUpdates,
      this.avatarText = 'ZY'});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 140,
      backgroundColor: AppColors.primaryDark,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(color: Colors.white, fontSize: 18),
      title: const Text('GainPath'),
      actions: [
        if (onOpenCoachingUpdates != null)
          IconButton(
              tooltip: 'Coaching updates and privacy',
              icon: const Icon(Icons.notifications_active_outlined),
              onPressed: onOpenCoachingUpdates),
        IconButton(
          tooltip:
              onOpenAnnouncements != null ? 'Announcements' : 'Notifications',
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: onOpenAnnouncements ??
              () => live
                  ? showUnavailable(context)
                  : showToast(context, 'No new notifications.'),
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.heroGradient)),
            Positioned(
              top: -50,
              right: -40,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 52, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Center(
                            child: Text(avatarText,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(greeting,
                                  style: TextStyle(
                                      fontSize: 13,
                                      height: 1.0,
                                      color:
                                          Colors.white.withValues(alpha: 0.8))),
                              Text(firstName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                          color: Colors.white,
                                          fontSize: 20,
                                          height: 1.15)),
                            ],
                          ),
                        ),
                        _PointsPill(points: points),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Points balance. Animates between values so claiming the daily reward
/// visibly lands on the balance rather than silently jumping.
class _PointsPill extends StatelessWidget {
  final int? points;
  const _PointsPill({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars_rounded, size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          if (points == null)
            const Text('—',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800))
          else
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: points!, end: points!),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, _) => Text('$value',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }
}

class _BroadcastBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  final bool live;
  const _BroadcastBanner({required this.onDismiss, this.live = false});

  @override
  Widget build(BuildContext context) {
    return Panel(
      background: AppColors.accentTint,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.campaign_rounded,
              size: 20, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(live ? 'Announcements' : 'Public holiday hours',
                    style:
                        TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  live
                      ? 'No announcements are available yet.'
                      : 'The gym closes at 6pm this Friday. Book your session early.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.ink, fontSize: 13.5),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// AD-M3.2 — daily attendance reward, plus the seven-day strip that gives
/// the streak number something concrete to refer to.
class _StreakCard extends StatelessWidget {
  final bool live;
  final bool claimed;
  final Animation<double> scale;
  final VoidCallback? onClaim;
  final int reward;

  const _StreakCard({
    this.live = false,
    required this.claimed,
    required this.scale,
    required this.onClaim,
    required this.reward,
  });

  /// Which of the last seven days already have a logged session. Derived
  /// from real history rather than hardcoded so the strip and the streak
  /// count never contradict each other.
  List<bool> _week(BuildContext context) {
    if (live) return List.filled(7, false);
    final trained = context
        .read<WorkoutRepository>()
        .history
        .map((r) => DateTime(r.date.year, r.date.month, r.date.day))
        .toSet();
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return trained.contains(DateTime(day.year, day.month, day.day));
    });
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final now = DateTime.now();
    final week = _week(context);

    return ScaleTransition(
      scale: scale,
      child: Panel(
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        claimed ? AppColors.successTint : AppColors.accentTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    claimed
                        ? Icons.check_rounded
                        : Icons.local_fire_department_rounded,
                    color: claimed ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          live
                              ? '- day streak'
                              : '${context.watch<GamificationBloc>().state.streak}-day streak',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        live
                            ? 'Check-in is not connected yet.'
                            : claimed
                                ? 'Checked in. Come back tomorrow.'
                                : 'Claim $reward points for showing up.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (!claimed)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.ink,
                    ),
                    onPressed: onClaim,
                    child: const Text('Claim'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final day = now.subtract(Duration(days: 6 - i));
                final isToday = i == 6;
                final done = week[i] || (isToday && claimed);
                return Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: done ? AppColors.primary : AppColors.surfaceAlt,
                        shape: BoxShape.circle,
                        border: isToday
                            ? Border.all(color: AppColors.primary, width: 2)
                            : Border.all(color: AppColors.hairline, width: 1),
                      ),
                      child: done
                          ? const Icon(Icons.check_rounded,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[day.weekday - 1],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.w800 : (done ? FontWeight.w700 : FontWeight.w600),
                        color: isToday
                            ? AppColors.primary
                            : (done ? AppColors.ink : AppColors.inkSoft),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

/// The single most important action on this screen, so it gets the full
/// gradient treatment rather than sitting in a plain card.
class _TodayWorkoutCard extends StatelessWidget {
  final VoidCallback? onStart;
  final bool live;
  final PublishedRoutine? publishedRoutine;
  final String? routineStatusMessage;
  const _TodayWorkoutCard(
      {required this.onStart,
      this.live = false,
      this.publishedRoutine,
      this.routineStatusMessage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        live
                            ? publishedRoutine?.title ??
                                routineStatusMessage ??
                                'No published routine yet'
                            : 'Lower Body Strength',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white, fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(
                      live
                          ? publishedRoutine == null
                              ? 'Exercises and duration unavailable'
                              : '${publishedRoutine!.exercises.length} exercises  ·  about ${publishedRoutine!.estimatedMinutes} min'
                          : '${context.read<WorkoutRepository>().routine.length} exercises  ·  about 45 min',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.82)),
                    ),
                  ],
                ),
              ),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.35)),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (live && publishedRoutine != null && publishedRoutine!.exercises.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Text(publishedRoutine!.exercises.first.category,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ),
            const SizedBox(height: 10),
          ] else
            const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            // Keep the exercise chips in the shared layout while the routine
            // is unavailable, without implying that sample exercises exist.
            children: (live
                    ? publishedRoutine?.exercises ?? <Exercise>[]
                    : context.read<WorkoutRepository>().routine)
                .take(3)
                .map((e) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(e.name,
                          style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ))
                .toList(),
          ),
          if (live && publishedRoutine == null)
            Wrap(
              spacing: 6,
              children: List.generate(
                  3,
                  (_) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('-',
                            style: TextStyle(color: Colors.white)),
                      )),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDark,
                minimumSize: const Size(0, 48),
              ),
              onPressed: onStart,
              icon: const Icon(Icons.bolt_rounded, size: 20),
              label: Text(routineStatusMessage?.contains('progress') == true ? 'Resume workout' : 'Start workout'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingStatsRow extends StatelessWidget {
  const _RingStatsRow({this.live = false, this.progress});
  final bool live;
  final MemberLocalProgress? progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RingStat(
            value: live ? 0 : 4 / 5,
            label: 'Sessions',
            display:
                live ? (progress?.weeklySessions.toString() ?? '—') : '4/5',
            color: AppColors.primary,
            icon: Icons.fitness_center_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _RingStat(
            value: live ? 0 : 0.84,
            label: 'Avg form',
            display: live ? '-' : '84%',
            color: AppColors.success,
            icon: Icons.verified_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _RingStat(
            value: live ? 0 : 12 / 14,
            label: 'To badge',
            display: live ? '-' : '12/14',
            color: AppColors.accent,
            icon: Icons.military_tech_rounded,
          ),
        ),
      ],
    );
  }
}

/// A metric shown as an animated arc rather than a bare number — the same
/// data, but it reads as progress toward something instead of a static
/// figure, which is the point of the weekly summary.
class _RingStat extends StatelessWidget {
  final double value;
  final String label;
  final String display;
  final Color color;
  final IconData icon;

  const _RingStat({
    required this.value,
    required this.label,
    required this.display,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => CustomPaint(
                painter: _RingPainter(v, color),
                child: Center(child: Icon(icon, size: 20, color: color)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(display,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          Text(label,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - 6) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.hairline
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

class _NextSessionCard extends StatelessWidget {
  final Booking? booking;
  final VoidCallback onTap;
  const _NextSessionCard({required this.booking, required this.onTap});

  String get _countdown {
    final diff = booking!.start.difference(DateTime.now());
    if (diff.inDays >= 1) {
      return 'in ${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
    }
    if (diff.inHours >= 1) return 'in ${diff.inHours} hours';
    return 'starting soon';
  }

  @override
  Widget build(BuildContext context) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final d = booking?.start;
    final time = d == null
        ? '-'
        : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return Panel(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(d == null ? '-' : '${d.day}',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
                Text(d == null ? '-' : months[d.month - 1],
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking == null ? 'with -' : 'with ${booking!.coachName}',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(booking == null ? '-  ·  -' : '$time  ·  $_countdown',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          statusPill(booking?.status.label ?? '-'),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppColors.inkSoft),
        ],
      ),
    );
  }
}

/// The frequency-of-access answer: everything the member reaches for
/// regularly, one tap from the landing screen instead of two or three.
class _QuickActionsGrid extends StatelessWidget {
  final void Function(Widget) onSelect;
  final bool enabled;
  final VoidCallback? onOpenProgress, onOpenRewards;
  final VoidCallback? onOpenEquipment;
  final VoidCallback? onOpenSavedAdvice;
  final VoidCallback? onOpenCoaches, onOpenBookings;
  const _QuickActionsGrid(
      {required this.onSelect,
      this.enabled = true,
      this.onOpenProgress,
      this.onOpenRewards,
      this.onOpenCoaches,
      this.onOpenBookings,
      this.onOpenSavedAdvice,
      this.onOpenEquipment});

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(Icons.insights_rounded, 'Progress', AppColors.primary,
          onOpenProgress ?? () => onSelect(const ProgressDashboardScreen())),
      _QuickAction(
          Icons.emoji_events_rounded,
          'Rewards',
          AppColors.accent,
          onOpenRewards ??
              () => onSelect(GamificationDashboardScreen(live: !enabled))),
      _QuickAction(Icons.people_alt_rounded, 'Coaches', AppColors.info,
          onOpenCoaches ?? () => onSelect(const BrowseCoachesScreen())),
      _QuickAction(Icons.event_note_rounded, 'Bookings', AppColors.success,
          onOpenBookings ?? () => onSelect(const BookingScheduleScreen())),
      _QuickAction(
          Icons.leaderboard_rounded,
          'Ranking',
          AppColors.warning,
          () => onSelect(enabled
              ? const LeaderboardScreen()
              : RewardsFeatureHost(
                  builder: (repo) =>
                      LeaderboardScreen(connected: true, repository: repo)))),
      _QuickAction(Icons.sports_esports_rounded, 'Mini-games',
          AppColors.primarySoft, () => onSelect(const MiniGamesScreen())),
      _QuickAction(
          Icons.card_membership_rounded,
          'Membership',
          AppColors.primary,
          () => onSelect(MembershipDashboardScreen(connected: !enabled))),
      _QuickAction(Icons.bookmark_rounded, 'Saved tips', AppColors.info,
          onOpenSavedAdvice ?? () => onSelect(const SavedAdviceScreen())),
      _QuickAction(
          Icons.qr_code_scanner_rounded,
          onOpenEquipment != null ? 'Equipment' : 'Scan gear',
          AppColors.primarySoft,
          onOpenEquipment ?? () => onSelect(const EquipmentScannerScreen())),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(11) / 11;
      final columns =
          (constraints.maxWidth / (72 * textScale)).floor().clamp(2, 4);
      final tileWidth = (constraints.maxWidth - 10 * (columns - 1)) / columns;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: columns,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio:
            tileWidth / math.max(tileWidth / 0.82, 72 + 28 * textScale),
        children: actions
            .map((a) => _QuickActionTile(
                action: a,
                enabled: enabled ||
                    a.label == 'Rewards' ||
                    a.label == 'Ranking' ||
                    a.label == 'Membership' ||
                    (a.label == 'Progress' && onOpenProgress != null) ||
                    (a.label == 'Coaches' && onOpenCoaches != null) ||
                    (a.label == 'Bookings' && onOpenBookings != null) ||
                    (a.label == 'Saved tips' && onOpenSavedAdvice != null) ||
                    (a.label == 'Equipment' && onOpenEquipment != null)))
            .toList(),
      );
    });
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, this.color, this.onTap);
}

class _QuickActionTile extends StatelessWidget {
  final _QuickAction action;
  final bool enabled;
  const _QuickActionTile({required this.action, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? action.onTap : () => showUnavailable(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(action.icon, size: 19, color: action.color),
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalPreviewCard extends StatelessWidget {
  final bool live;
  final VoidCallback? onTap;
  final FitnessProfile? liveProfile;
  const _GoalPreviewCard(
      {required this.onTap, this.liveProfile, this.live = false});

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      child: Column(
        children: [
          if (!live) ...[
            const ProgressRow('Train 4x per week', 0.75, '3 of 4'),
            const ProgressRow('Hit 85% average form', 0.99, '84 of 85',
                color: AppColors.accent),
          ] else ...[
            const ProgressRow('Train 4x per week', 0, '-'),
            const ProgressRow('Hit 85% average form', 0, '-',
                color: AppColors.accent),
            if (liveProfile != null)
              Text(liveProfile!.goals.map((goal) => goal.label).join(' · ')),
          ],
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('See all goals',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }
}

class _MembershipStrip extends StatelessWidget {
  final VoidCallback? onTap;
  final bool live;
  const _MembershipStrip({required this.onTap, this.live = false});

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      background: AppColors.surfaceAlt,
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded,
              size: 22, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    live
                        ? '- membership'
                        : '${context.read<MemberProfileRepository>().memberTier} membership',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontSize: 14)),
                Text(
                    live
                        ? 'Renews -  ·  - days left'
                        : 'Renews 12 Oct  ·  28 days left',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 12.5)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppColors.inkSoft),
        ],
      ),
    );
  }
}
