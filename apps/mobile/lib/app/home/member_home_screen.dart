import 'dart:math' as math;
import '../../features/gamification/application/rewards_feature_host.dart';
import '../../features/analytics/domain/member_workout_report.dart';
import '../di/chatbot_factory.dart';
import '../../features/gamification/application/app_check_in_cubit.dart';
import '../../features/gamification/presentation/member/app_check_in_card.dart';
import 'package:gainpath_domain/analytics.dart';
import '../../features/analytics/presentation/member/widgets/local_progress_widgets.dart';
import '../../features/workout/data/published_routine.dart';
import '../../features/workout/domain/routine_attempt.dart';
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
      this.onOpenNotifications,
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
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenEquipment;
  final VoidCallback? onOpenCoaches, onOpenBookings;
  final void Function(LocalWorkoutProgressRecord)? onOpenWorkout;

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen>
    with SingleTickerProviderStateMixin {
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
      floatingActionButton: SizedBox(
        width: 72,
        height: 72,
        child: FloatingActionButton(
          heroTag: 'ai_coach_fab',
          tooltip: 'AI Coach',
          onPressed: live
              ? () => _go(buildMemberChatbot(widget.liveSession!))
              : () => _go(const ChatbotScreen()),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/images/ai_coach_mascot.png',
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
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
                onOpenNotifications: widget.onOpenNotifications,
                onOpenCoachingUpdates: widget.onOpenCoachingUpdates,
                onOpenAnnouncements: live && widget.announcements != null
                    ? _openAnnouncements
                    : null,
                avatarText: live
                    ? (firstName.isEmpty
                        ? '?'
                        : firstName.substring(0, 1).toUpperCase())
                    : 'ZY'),
            SliverToBoxAdapter(
              child: DecoratedBox(
                decoration:
                    const BoxDecoration(gradient: AppColors.heroGradient),
                child: DecoratedBox(
                  key: const ValueKey('home-content-top'),
                  decoration: const BoxDecoration(
                    color: AppColors.bg,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: const SizedBox(height: 24),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              sliver: SliverList.list(
                children: [
                  if (widget.announcements != null) ...[
                    widget.announcements!,
                    const SizedBox(height: 24),
                  ],
                  const _HomeSectionHeading('Daily check-in'),
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
                  const SizedBox(height: 24),
                  const _HomeSectionHeading("Today's session"),
                  _TodayWorkoutCard(
                      live: live,
                      publishedRoutine: widget.publishedRoutine,
                      routineStatusMessage: widget.routineStatusMessage,
                      onStart: live
                          ? widget.onStartWorkout ??
                              () => _go(WorkoutPrepRoute(
                                  publishedRoutine: widget.publishedRoutine))
                          : () => _go(const WorkoutPrepRoute(live: false))),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Expanded(
                          child:
                              _HomeSectionHeading('This week', padded: false)),
                      if (widget.onOpenProgress != null || !live)
                        InkWell(
                          onTap: widget.onOpenProgress ??
                              () => _go(GoalProgressScreen(
                                  live: live,
                                  localProgress: widget.localProgress)),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  'Details',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(Icons.chevron_right_rounded,
                                    size: 14, color: AppColors.primary),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _WeeklySummaryCard(
                    live: live,
                    progress: widget.localProgress,
                  ),
                  if (widget.progressError != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 16, color: AppColors.danger),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.progressError!,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.danger),
                            ),
                          ),
                          if (widget.onRefreshProgress != null)
                            TextButton(
                              onPressed: widget.onRefreshProgress,
                              child: const Text('Retry',
                                  style: TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _RecentActivitySection(
                    live: live,
                    localProgress: widget.localProgress,
                    onOpenHistory: widget.onOpenHistory ??
                        widget.onOpenRoutineHistory ??
                        () => _go(const ProgressDashboardScreen()),
                    onOpenWorkout: widget.onOpenWorkout,
                  ),
                  const SizedBox(height: 24),
                  const _HomeSectionHeading('Quick access'),
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
                  if (nextBooking != null) ...[
                    const SizedBox(height: 24),
                    const _HomeSectionHeading('Next with a coach'),
                    _NextSessionCard(
                      booking: nextBooking,
                      onTap: live
                          ? widget.onOpenBookings ??
                              () => showUnavailable(context)
                          : () => _go(const BookingScheduleScreen()),
                    ),
                  ],
                  if (live &&
                      widget.liveProfile != null &&
                      widget.liveProfile!.goals.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const _HomeSectionHeading('Goal progress'),
                    _GoalPreviewCard(
                      live: true,
                      liveProfile: widget.liveProfile,
                      onTap: () => _go(GoalProgressScreen(
                          live: true, localProgress: widget.localProgress)),
                    ),
                  ] else if (!live) ...[
                    const SizedBox(height: 24),
                    const _HomeSectionHeading('Goal progress'),
                    _GoalPreviewCard(
                      live: false,
                      onTap: () => _go(const GoalProgressScreen()),
                    ),
                    const SizedBox(height: 24),
                    _MembershipStrip(
                      live: false,
                      onTap: () => _go(const MembershipDashboardScreen()),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSectionHeading extends StatelessWidget {
  const _HomeSectionHeading(this.text, {this.padded = true});

  final String text;
  final bool padded;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: padded ? 10 : 0),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'BarlowCondensed',
            fontSize: 16,
            height: 1.25,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
      );
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
  final VoidCallback? onOpenNotifications;

  const _HeroHeader(
      {required this.greeting,
      required this.firstName,
      required this.points,
      required this.live,
      this.onOpenNotifications,
      this.onOpenAnnouncements,
      this.onOpenCoachingUpdates,
      this.avatarText = 'ZY'});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 116,
      backgroundColor: AppColors.primaryDark,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
      title: const Text('GainPath'),
      actions: [
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: onOpenNotifications ??
              onOpenAnnouncements ??
              onOpenCoachingUpdates ??
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
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Center(
                            child: Text(
                              avatarText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                greeting,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.0,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                firstName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.5,
                                  height: 1.15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars_rounded, size: 15, color: AppColors.accent),
          const SizedBox(width: 5),
          if (points == null)
            const Text('—',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800))
          else
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: points!, end: points!),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, _) => Text('$value',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
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
    final streak = live ? 0 : context.watch<GamificationBloc>().state.streak;
    final isEnlargedText = MediaQuery.textScalerOf(context).scale(1.0) > 1.15;

    Widget claimButton() {
      if (claimed) {
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
              Text('Checked in',
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
        onPressed: onClaim,
        icon:
            const Icon(Icons.stars_rounded, size: 16, color: AppColors.accent),
        label: Text('Claim $reward pts',
            style:
                const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      );
    }

    return ScaleTransition(
      scale: scale,
      child: Panel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        background: AppColors.primaryTint,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color:
                        claimed ? AppColors.successTint : AppColors.accentTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    claimed
                        ? Icons.check_rounded
                        : Icons.local_fire_department_rounded,
                    color: claimed ? AppColors.success : AppColors.warning,
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
                              live ? '- day streak' : '$streak-day streak',
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
                          const SizedBox(width: 4),
                          const Tooltip(
                            message:
                                'Check in daily to build your streak · Resets at midnight',
                            triggerMode: TooltipTriggerMode.tap,
                            child: Icon(Icons.info_outline_rounded,
                                size: 15, color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        live
                            ? 'Check-in is not connected yet.'
                            : (claimed
                                ? 'Checked in today'
                                : '+$reward pts available'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              claimed ? AppColors.success : AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isEnlargedText) ...[
                  const SizedBox(width: 8),
                  claimButton(),
                ],
              ],
            ),
            if (isEnlargedText) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: claimButton(),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final day = now.subtract(Duration(days: 6 - i));
                final isToday = i == 6;
                final done = week[i] || (isToday && claimed);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: done ? AppColors.primary : AppColors.surface,
                        shape: BoxShape.circle,
                        border: isToday
                            ? Border.all(color: AppColors.primary, width: 2)
                            : Border.all(color: AppColors.hairline, width: 1),
                      ),
                      child: done
                          ? const Icon(Icons.check_rounded,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      labels[day.weekday - 1],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isToday
                            ? FontWeight.w800
                            : (done ? FontWeight.w700 : FontWeight.w600),
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
    final exercises = live
        ? publishedRoutine?.exercises ?? <Exercise>[]
        : context.read<WorkoutRepository>().routine;
    final title = live
        ? publishedRoutine?.title ??
            routineStatusMessage ??
            'No published routine yet'
        : 'Lower Body Strength';
    final durationText = live
        ? publishedRoutine == null
            ? 'Exercises and duration unavailable'
            : '${exercises.length} exercises  ·  about ${publishedRoutine!.estimatedMinutes} min'
        : '${exercises.length} exercises  ·  about 45 min';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x384C1D95), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.bolt_rounded, size: 12, color: AppColors.accent),
                    SizedBox(width: 3),
                    Text(
                      "TODAY'S WORKOUT",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (live &&
                  publishedRoutine != null &&
                  publishedRoutine!.exercises.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    publishedRoutine!.exercises.first.category.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            durationText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 10),
          if (exercises.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ...exercises.take(2).map(
                      (e) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          e.name,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                if (exercises.length > 2)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      '+${exercises.length - 2} more',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            )
          else if (live && publishedRoutine == null)
            Wrap(
              spacing: 6,
              children: List.generate(
                2,
                (_) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('-',
                      style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDark,
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.25),
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(
                routineStatusMessage?.contains('progress') == true
                    ? 'Resume workout'
                    : 'Start workout',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklySummaryCard extends StatelessWidget {
  final bool live;
  final MemberLocalProgress? progress;

  const _WeeklySummaryCard({
    this.live = false,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final sessions = live ? (progress?.weeklySessions ?? 0) : 4;
    final reps = live ? (progress?.weeklyRepetitions ?? 0) : 120;
    final coverage = live ? progress?.weeklyCoverage : 0.84;
    final isEnlarged = MediaQuery.textScalerOf(context).scale(1.0) > 1.15;

    final tile1 = _CompactMetricTile(
      icon: Icons.videocam_outlined,
      color: AppColors.primary,
      value: live ? (progress == null ? '—' : '$sessions') : '4/5',
      label: 'Sessions',
    );
    final tile2 = _CompactMetricTile(
      icon: Icons.fitness_center_rounded,
      color: AppColors.accent,
      value: live ? (progress == null ? '—' : '$reps') : '120',
      label: 'Reps',
    );
    final tile3 = _CompactMetricTile(
      icon: Icons.verified_outlined,
      color: AppColors.success,
      value: live
          ? (coverage == null || coverage == 0
              ? '—'
              : '${(coverage * 100).round()}%')
          : '84%',
      label: 'Form scored',
    );

    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: isEnlarged
          ? Column(
              children: [
                Row(
                  children: [
                    Expanded(child: tile1),
                    const SizedBox(width: 8),
                    Expanded(child: tile2),
                  ],
                ),
                const SizedBox(height: 8),
                tile3,
              ],
            )
          : Row(
              children: [
                Expanded(child: tile1),
                Container(
                  width: 1,
                  height: 34,
                  color: AppColors.hairline,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                Expanded(child: tile2),
                Container(
                  width: 1,
                  height: 34,
                  color: AppColors.hairline,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                Expanded(child: tile3),
              ],
            ),
    );
  }
}

class _CompactMetricTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _CompactMetricTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  final bool live;
  final MemberLocalProgress? localProgress;
  final VoidCallback? onOpenHistory;
  final void Function(LocalWorkoutProgressRecord)? onOpenWorkout;

  const _RecentActivitySection({
    required this.live,
    this.localProgress,
    this.onOpenHistory,
    this.onOpenWorkout,
  });

  @override
  Widget build(BuildContext context) {
    final records = live ? (localProgress?.records ?? []) : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
                child: _HomeSectionHeading('Recent activity', padded: false)),
            if (onOpenHistory != null)
              InkWell(
                onTap: onOpenHistory,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'View all',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded,
                          size: 14, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (live && localProgress == null)
          const Panel(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Text('Loading saved camera sessions…',
                style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
          )
        else if (records.isEmpty)
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: const [
                Icon(Icons.history_rounded, size: 18, color: AppColors.inkSoft),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No saved camera sessions yet.',
                    style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                  ),
                ),
              ],
            ),
          )
        else ...[
          for (final record in records.take(2))
            _CompactActivityTile(
              record: record,
              utcOffset: localProgress!.utcOffset,
              onTap:
                  onOpenWorkout == null ? null : () => onOpenWorkout!(record),
            ),
        ],
      ],
    );
  }
}

class _CompactActivityTile extends StatelessWidget {
  final LocalWorkoutProgressRecord record;
  final Duration utcOffset;
  final VoidCallback? onTap;

  const _CompactActivityTile({
    required this.record,
    required this.utcOffset,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (record.status) {
      LocalWorkoutRecordStatus.accepted => AppColors.success,
      LocalWorkoutRecordStatus.rejected => AppColors.danger,
      LocalWorkoutRecordStatus.retryable => AppColors.warning,
      LocalWorkoutRecordStatus.pending => AppColors.warning,
      _ => AppColors.inkSoft,
    };

    final statusText = switch (record.status) {
      LocalWorkoutRecordStatus.accepted => 'Backed up',
      LocalWorkoutRecordStatus.localOnly => 'Saved on device',
      LocalWorkoutRecordStatus.pending => 'Pending upload',
      LocalWorkoutRecordStatus.retryable => 'Retry upload',
      LocalWorkoutRecordStatus.rejected => 'Rejected',
      LocalWorkoutRecordStatus.unknown => 'Unknown',
    };

    final date = localProgressDate(record.endedAt, utcOffset);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.fitness_center_rounded,
                      size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        reportExerciseLabel(record.exerciseId),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$date · ${record.repetitions} reps${record.partialRepetitions > 0 ? ' (${record.partialRepetitions} partial)' : ''}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppColors.inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
            constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF3EEFD), Color(0xFFEDE7FB)],
              ),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(d == null ? '-' : '${d.day}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
                Text(d == null ? '-' : months[d.month - 1].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      booking == null ? 'with -' : 'with ${booking!.coachName}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded,
                        size: 14, color: AppColors.primary),
                  ],
                ),
                const SizedBox(height: 3),
                Text(booking == null ? '-  ·  -' : '$time  ·  $_countdown',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkSoft,
                    )),
              ],
            ),
          ),
          statusPill(booking?.status.label ?? '-'),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 13, color: AppColors.inkSoft),
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
      _QuickAction(
          Icons.sports_esports_rounded,
          'Mini-games',
          AppColors.primarySoft,
          () => onSelect(MiniGamesScreen(connected: !enabled))),
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
        padding: EdgeInsets.zero,
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
                    a.label == 'Mini-games' ||
                    (a.label == 'Progress' && onOpenProgress != null) ||
                    (a.label == 'Coaches' && onOpenCoaches != null) ||
                    (a.label == 'Bookings' && onOpenBookings != null) ||
                    (a.label == 'Saved tips' && onOpenSavedAdvice != null) ||
                    (a.label == 'Equipment' && onOpenEquipment != null) ||
                    (a.label == 'Scan gear' && onOpenEquipment != null)))
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
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: AppColors.hairline.withValues(alpha: 0.8)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x06190F2E), blurRadius: 6, offset: Offset(0, 2))
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: action.color.withValues(alpha: 0.20)),
                ),
                child: Icon(action.icon, size: 20, color: action.color),
              ),
              const SizedBox(height: 7),
              Flexible(
                child: Text(
                  action.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    letterSpacing: -0.2,
                  ),
                ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!live) ...[
            const ProgressRow('Train 4x per week', 0.75, '3 of 4'),
            const ProgressRow('Hit 85% average form', 0.99, '84 of 85',
                color: AppColors.accent),
          ] else if (liveProfile != null) ...[
            for (final goal in liveProfile!.goals.take(2))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.flag_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        goal.label,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [
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
