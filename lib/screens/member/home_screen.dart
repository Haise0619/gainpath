import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';
import 'workout_screens.dart';
import 'reports_screens.dart';
import 'chatbot_screens.dart';
import 'gamification_screens.dart';
import 'coach_booking_screens.dart';
import 'membership_screens.dart';

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
  const MemberHomeScreen({super.key});

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen>
    with SingleTickerProviderStateMixin {
  static const _dailyReward = 50;

  bool _claimed = false;
  bool _dismissedBroadcast = false;
  int _points = MockData.points;

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
    ]).animate(CurvedAnimation(parent: _claimController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _claimController.dispose();
    super.dispose();
  }

  void _claim() {
    setState(() {
      _claimed = true;
      _points += _dailyReward;
    });
    _claimController.forward(from: 0);
    showToast(context, 'Checked in. +$_dailyReward points, streak extended.');
  }

  Future<void> _refresh() async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) showToast(context, 'Up to date.');
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  /// The member's next confirmed coaching session, if any.
  Booking? get _nextBooking {
    final upcoming = MockData.memberBookings
        .where((b) => b.status == 'Confirmed' && b.start.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  void _go(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final firstName = MockData.memberName.split(' ').first;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _go(const ChatbotScreen()),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
        label: const Text('AI coach'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _HeroHeader(greeting: _greeting, firstName: firstName, points: _points),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
              sliver: SliverList.list(
                children: [
                  if (!_dismissedBroadcast) ...[
                    _BroadcastBanner(onDismiss: () => setState(() => _dismissedBroadcast = true)),
                    const SizedBox(height: 14),
                  ],
                  _StreakCard(
                    claimed: _claimed,
                    scale: _claimScale,
                    onClaim: _claim,
                    reward: _dailyReward,
                  ),
                  const SizedBox(height: 20),
                  const Eyebrow("Today's session"),
                  _TodayWorkoutCard(onStart: () => _go(const WorkoutPrepScreen())),
                  const SizedBox(height: 20),
                  const Eyebrow('This week'),
                  const _RingStatsRow(),
                  const SizedBox(height: 20),
                  if (_nextBooking != null) ...[
                    const Eyebrow('Next with a coach'),
                    _NextSessionCard(
                      booking: _nextBooking!,
                      onTap: () => _go(const BookingScheduleScreen()),
                    ),
                    const SizedBox(height: 20),
                  ],
                  const Eyebrow('Quick access'),
                  _QuickActionsGrid(onSelect: _go),
                  const SizedBox(height: 20),
                  const Eyebrow('Goal progress'),
                  _GoalPreviewCard(onTap: () => _go(const GoalProgressScreen())),
                  const SizedBox(height: 20),
                  _MembershipStrip(onTap: () => _go(const MembershipScreen())),
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
  final int points;

  const _HeroHeader({required this.greeting, required this.firstName, required this.points});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 178,
      backgroundColor: AppColors.primaryDark,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(color: Colors.white, fontSize: 18),
      title: const Text('GainPath'),
      actions: [
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () => showToast(context, 'No new notifications.'),
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
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
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: const Center(
                            child: Text('ZY',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
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
                                      color: Colors.white.withValues(alpha: 0.8))),
                              Text(firstName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(color: Colors.white, fontSize: 24, height: 1.15)),
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
  final int points;
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
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: points, end: points),
            duration: const Duration(milliseconds: 600),
            builder: (context, value, _) => Text('$value',
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _BroadcastBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  const _BroadcastBanner({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Panel(
      background: AppColors.accentTint,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.campaign_rounded, size: 20, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Public holiday hours',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  'The gym closes at 6pm this Friday. Book your session early.',
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
  final bool claimed;
  final Animation<double> scale;
  final VoidCallback onClaim;
  final int reward;

  const _StreakCard({
    required this.claimed,
    required this.scale,
    required this.onClaim,
    required this.reward,
  });

  /// Which of the last seven days already have a logged session. Derived
  /// from real history rather than hardcoded so the strip and the streak
  /// count never contradict each other.
  List<bool> get _week {
    final trained = MockData.history
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
    final week = _week;

    return ScaleTransition(
      scale: scale,
      child: Panel(
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: claimed ? AppColors.successTint : AppColors.accentTint,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    claimed ? Icons.check_rounded : Icons.local_fire_department_rounded,
                    color: claimed ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${MockData.streak}-day streak',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        claimed
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
                        color: done ? AppColors.accent : AppColors.surfaceAlt,
                        shape: BoxShape.circle,
                        border: isToday
                            ? Border.all(color: AppColors.primary, width: 2)
                            : null,
                      ),
                      child: done
                          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[day.weekday - 1],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                        color: isToday ? AppColors.primary : AppColors.inkSoft,
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
  final VoidCallback onStart;
  const _TodayWorkoutCard({required this.onStart});

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
                    Text('Lower Body Strength',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white, fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(
                      '${MockData.routine.length} exercises  ·  about 45 min',
                      style: TextStyle(
                          fontSize: 13, color: Colors.white.withValues(alpha: 0.82)),
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
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: MockData.routine
                .take(3)
                .map((e) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(e.name,
                          style: const TextStyle(
                              fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600)),
                    ))
                .toList(),
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
              label: const Text('Start workout'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingStatsRow extends StatelessWidget {
  const _RingStatsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _RingStat(
            value: 4 / 5,
            label: 'Sessions',
            display: '4/5',
            color: AppColors.primary,
            icon: Icons.fitness_center_rounded,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _RingStat(
            value: 0.84,
            label: 'Avg form',
            display: '84%',
            color: AppColors.success,
            icon: Icons.verified_rounded,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _RingStat(
            value: 12 / 14,
            label: 'To badge',
            display: '12/14',
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
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          Text(label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5)),
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
  final Booking booking;
  final VoidCallback onTap;
  const _NextSessionCard({required this.booking, required this.onTap});

  String get _countdown {
    final diff = booking.start.difference(DateTime.now());
    if (diff.inDays >= 1) return 'in ${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
    if (diff.inHours >= 1) return 'in ${diff.inHours} hours';
    return 'starting soon';
  }

  @override
  Widget build(BuildContext context) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final d = booking.start;
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

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
                Text('${d.day}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)),
                Text(months[d.month - 1],
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('with ${booking.coachName}',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text('$time  ·  $_countdown',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          statusPill(booking.status),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.inkSoft),
        ],
      ),
    );
  }
}

/// The frequency-of-access answer: everything the member reaches for
/// regularly, one tap from the landing screen instead of two or three.
class _QuickActionsGrid extends StatelessWidget {
  final void Function(Widget) onSelect;
  const _QuickActionsGrid({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(Icons.insights_rounded, 'Progress', AppColors.primary,
          () => onSelect(const ProgressDashboardScreen())),
      _QuickAction(Icons.emoji_events_rounded, 'Rewards', AppColors.accent,
          () => onSelect(const GamificationDashboardScreen())),
      _QuickAction(Icons.people_alt_rounded, 'Coaches', AppColors.info,
          () => onSelect(const BrowseCoachesScreen())),
      _QuickAction(Icons.event_note_rounded, 'Bookings', AppColors.success,
          () => onSelect(const BookingScheduleScreen())),
      _QuickAction(Icons.leaderboard_rounded, 'Ranking', AppColors.warning,
          () => onSelect(const LeaderboardScreen())),
      _QuickAction(Icons.sports_esports_rounded, 'Mini-games', AppColors.primarySoft,
          () => onSelect(const MiniGamesScreen())),
      _QuickAction(Icons.card_membership_rounded, 'Membership', AppColors.primary,
          () => onSelect(const MembershipScreen())),
      _QuickAction(Icons.bookmark_rounded, 'Saved tips', AppColors.info,
          () => onSelect(const SavedAdviceScreen())),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.82,
      children: actions.map((a) => _QuickActionTile(action: a)).toList(),
    );
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
  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: action.onTap,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalPreviewCard extends StatelessWidget {
  final VoidCallback onTap;
  const _GoalPreviewCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      child: Column(
        children: const [
          ProgressRow('Train 4x per week', 0.75, '3 of 4'),
          ProgressRow('Hit 85% average form', 0.99, '84 of 85', color: AppColors.accent),
          SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('See all goals',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }
}

class _MembershipStrip extends StatelessWidget {
  final VoidCallback onTap;
  const _MembershipStrip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      background: AppColors.surfaceAlt,
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded, size: 22, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${MockData.memberTier} membership',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
                Text('Renews 12 Oct  ·  28 days left',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.inkSoft),
        ],
      ),
    );
  }
}
