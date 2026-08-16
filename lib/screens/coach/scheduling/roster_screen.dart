import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import 'client_posture_screen.dart';
import 'consultation_notes_screen.dart';
import 'message_inbox_screen.dart';

/// AD-M9.1 — View Upcoming Session Schedule. Built around a day-rail +
/// vertical timeline rather than the flat panel list every other module
/// this session uses — a coach's schedule is inherently about *when*,
/// so the layout leads with time instead of a plain list.
///
/// Picking a status filter other than "All" switches to a cross-day view
/// instead of ANDing with whatever day happens to be selected — that's
/// what makes "Completed" a real shortcut to "sessions I still need to
/// write notes for" rather than something that only shows results if you
/// also happen to be looking at a day with a completed session on it.
class CoachRosterScreen extends StatefulWidget {
  const CoachRosterScreen({super.key});

  @override
  State<CoachRosterScreen> createState() => _CoachRosterScreenState();
}

class _CoachRosterScreenState extends State<CoachRosterScreen>
    with SingleTickerProviderStateMixin {
  String _statusFilter = 'All';
  int _dayIndex = 0;
  late final AnimationController _reveal;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 450))
      ..forward();
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  void _selectDay(int i) {
    if (i == _dayIndex && _statusFilter == 'All') return;
    setState(() {
      _dayIndex = i;
      _statusFilter = 'All';
    });
    _reveal
      ..reset()
      ..forward();
  }

  void _selectStatus(String s) {
    if (s == _statusFilter) return;
    setState(() => _statusFilter = s);
    _reveal
      ..reset()
      ..forward();
  }

  List<DateTime> get _days {
    final today = DateTime.now();
    return List.generate(7, (i) {
      final d = today.add(Duration(days: i));
      return DateTime(d.year, d.month, d.day);
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final roster = MockData.coachRoster;
    final days = _days;
    final selectedDay = days[_dayIndex];
    final now = DateTime.now();
    final weekEnd = now.add(const Duration(days: 7));
    final filtering = _statusFilter != 'All';

    final visible = filtering
        ? (roster.where((b) => b.status == _statusFilter).toList()
          ..sort((a, b) => b.start.compareTo(a.start)))
        : (roster.where((b) => _isSameDay(b.start, selectedDay)).toList()
          ..sort((a, b) => a.start.compareTo(b.start)));

    final needsReply = roster
        .where((b) => b.messages.isNotEmpty && b.messages.last.senderRole == 'Member')
        .length;
    final todayCount =
        roster.where((b) => _isSameDay(b.start, DateTime(now.year, now.month, now.day))).length;
    final weekCount = roster.where((b) => b.start.isAfter(now) && b.start.isBefore(weekEnd)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My schedule'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.forum_outlined),
                  tooltip: 'Messages',
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CoachMessageInboxScreen())),
                ),
                if (needsReply > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                      child: Text('$needsReply',
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(child: StatTile('${roster.length}', 'Sessions', compact: true)),
                  const SizedBox(width: 8),
                  Expanded(child: StatTile('$weekCount', 'This week', compact: true)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: StatTile('$todayCount', 'Today',
                          compact: true, valueColor: AppColors.accent)),
                ],
              ),
            ),
          ),
          if (!filtering) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  '${_monthNames[selectedDay.month - 1]} ${selectedDay.year}',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.inkSoft),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 72,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: days.length,
                  itemBuilder: (ctx, i) {
                    final d = days[i];
                    final selected = i == _dayIndex;
                    final count = roster.where((b) => _isSameDay(b.start, d)).length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Material(
                        color: selected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        elevation: selected ? 3 : 0,
                        shadowColor: AppColors.primary.withValues(alpha: 0.35),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _selectDay(i),
                          child: Container(
                            width: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: selected ? AppColors.primary : AppColors.hairline),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(i == 0 ? 'Today' : _dayNames[d.weekday - 1],
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: selected ? Colors.white70 : AppColors.inkSoft)),
                                    const SizedBox(height: 4),
                                    Text('${d.day}',
                                        style: TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w700,
                                            color: selected ? Colors.white : AppColors.ink)),
                                  ],
                                ),
                                if (count > 0)
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: selected ? Colors.white : AppColors.accent,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ] else
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: ['All', 'Confirmed', 'Pending', 'Completed'].map((s) {
                  final selected = s == _statusFilter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s),
                      selected: selected,
                      onSelected: (_) => _selectStatus(s),
                      backgroundColor: AppColors.surface,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.ink,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: const BorderSide(color: AppColors.hairline),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      filtering
                          ? '$_statusFilter sessions'
                          : _dayIndex == 0
                              ? "Today's sessions"
                              : '${_dayNames[selectedDay.weekday - 1]}, ${selectedDay.day} ${_monthNames[selectedDay.month - 1]}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text('${visible.length} session${visible.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: const Divider(height: 18)),
          ),
          if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_available_outlined, size: 40, color: AppColors.hairline),
                      const SizedBox(height: 14),
                      Text(
                        filtering ? 'No $_statusFilter sessions.' : 'No sessions this day.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final start = (i / visible.length).clamp(0.0, 1.0);
                    final end = ((i + 1) / visible.length * 0.7 + 0.3).clamp(0.0, 1.0);
                    final anim = CurvedAnimation(
                      parent: _reveal,
                      curve: Interval(start * 0.6, end, curve: Curves.easeOut),
                    );
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: anim.drive(Tween(begin: const Offset(0, 0.05), end: Offset.zero)),
                        child: _TimelineRow(
                          booking: visible[i],
                          isLast: i == visible.length - 1,
                          showConnector: !filtering,
                        ),
                      ),
                    );
                  },
                  childCount: visible.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One entry in the timeline: a time label + connecting dot/line on the
/// left, the session card on the right. The connecting line is only
/// drawn in day view (`showConnector`) — in the cross-day filtered view
/// the rows aren't actually adjacent in time, so a line linking them
/// would misleadingly imply they are.
class _TimelineRow extends StatelessWidget {
  final Booking booking;
  final bool isLast;
  final bool showConnector;
  const _TimelineRow({required this.booking, required this.isLast, required this.showConnector});

  @override
  Widget build(BuildContext context) {
    final h = booking.start.hour.toString().padLeft(2, '0');
    final m = booking.start.minute.toString().padLeft(2, '0');
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text('$h:$m',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
                const SizedBox(height: 6),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _statusColor(booking.status)),
                ),
                if (showConnector && !isLast)
                  Expanded(child: Container(width: 2, color: AppColors.hairline)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _SessionCard(booking: booking),
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'Confirmed':
    case 'Completed':
      return AppColors.success;
    case 'Pending':
      return AppColors.warning;
    case 'Cancelled':
      return AppColors.danger;
    default:
      return AppColors.inkSoft;
  }
}

/// Everything the coach's own booking history says about one client,
/// computed from `coachRoster` rather than stored anywhere — the roster
/// is the only real record of the relationship that exists in this data
/// model, so this surfaces what's genuinely there instead of inventing
/// demographic details the system was never given for anyone but the
/// signed-in member.
class _ClientStats {
  final int sessionsTogether;
  final int completed;
  final int cancelled;
  final double revenue;
  final DateTime clientSince;
  final String? mostRecentNote;

  const _ClientStats({
    required this.sessionsTogether,
    required this.completed,
    required this.cancelled,
    required this.revenue,
    required this.clientSince,
    required this.mostRecentNote,
  });

  factory _ClientStats.of(String memberName) {
    final bookings = MockData.coachRoster.where((b) => b.memberName == memberName).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final completed = bookings.where((b) => b.status == 'Completed').toList();
    final withNotes = [...completed]..sort((a, b) => b.start.compareTo(a.start));
    return _ClientStats(
      sessionsTogether: bookings.length,
      completed: completed.length,
      cancelled: bookings.where((b) => b.status == 'Cancelled').length,
      revenue: completed.fold(0, (sum, b) => sum + b.fee),
      clientSince: bookings.first.start,
      mostRecentNote: withNotes.isEmpty
          ? null
          : withNotes.firstWhere((b) => b.notes != null, orElse: () => withNotes.first).notes,
    );
  }
}

void _showClientSnapshot(BuildContext context, Booking booking) {
  final stats = _ClientStats.of(booking.memberName);
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(14)),
                child: Center(
                  child: Text(
                    booking.memberName.split(' ').map((w) => w[0]).take(2).join(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.memberName, style: Theme.of(ctx).textTheme.titleLarge),
                    Text(
                      'Client since ${stats.clientSince.day} ${months[stats.clientSince.month - 1]} ${stats.clientSince.year}',
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: StatTile('${stats.sessionsTogether}', 'Together', compact: true)),
              const SizedBox(width: 8),
              Expanded(child: StatTile('${stats.completed}', 'Completed', compact: true)),
              const SizedBox(width: 8),
              Expanded(
                  child: StatTile('RM ${stats.revenue.toStringAsFixed(0)}', 'Revenue',
                      compact: true, valueColor: AppColors.success)),
            ],
          ),
          if (stats.mostRecentNote != null) ...[
            const SizedBox(height: 14),
            const Eyebrow('Most recent note'),
            Panel(
              background: AppColors.surfaceAlt,
              child: Text(stats.mostRecentNote!, style: const TextStyle(fontSize: 13.5, height: 1.45)),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ClientPostureScreen(name: booking.memberName)));
                  },
                  icon: const Icon(Icons.insights_rounded, size: 18),
                  label: const Text('Form history'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => CoachMessageThreadScreen(booking: booking)));
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Message'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// The session card, with a status-colored left accent bar — a quick-scan
/// cue borrowed from calendar apps — and a one-line relationship summary
/// ("New client" / "3rd session together") computed from the coach's own
/// booking history with this member. Tapping the member row opens the
/// fuller client snapshot.
///
/// The fee/duration/branch line used to be one long `Text` that wrapped
/// awkwardly on narrow widths; it's now a `Wrap` of small info bits,
/// which reflows instead of overflowing. Cancel used to share the bottom
/// action row with Form history and Message — three widgets fighting for
/// the same width squeezed "Form history" down to an ellipsis. Cancel now
/// lives beside the status pill in the header instead, so the action row
/// is always exactly two buttons and never needs to shrink their labels.
class _SessionCard extends StatelessWidget {
  final Booking booking;
  const _SessionCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final isPast = booking.start.isBefore(DateTime.now());
    final stats = _ClientStats.of(booking.memberName);
    final relationship = stats.sessionsTogether <= 1
        ? 'New client'
        : '${_ordinal(stats.sessionsTogether)} session together';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.hairline)),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: _statusColor(booking.status)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _showClientSnapshot(context, booking),
                              borderRadius: BorderRadius.circular(10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryTint,
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Center(
                                      child: Text(
                                        booking.memberName.split(' ').map((w) => w[0]).take(2).join(),
                                        style: const TextStyle(
                                            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(booking.memberName, style: Theme.of(context).textTheme.titleMedium),
                                        const SizedBox(height: 3),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 3,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            _InfoBit(Icons.payments_outlined, 'RM ${booking.fee.toStringAsFixed(0)}'),
                                            _InfoBit(Icons.schedule_outlined, '${booking.durationMin} min'),
                                            _InfoBit(Icons.location_on_outlined, booking.branch),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.badge_outlined, size: 12, color: AppColors.primary),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(relationship,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.primary)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              statusPill(booking.status),
                              if (!isPast) ...[
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppColors.dangerTint,
                                      foregroundColor: AppColors.danger,
                                    ),
                                    tooltip: 'Cancel session',
                                    onPressed: () => confirmSheet(context,
                                        title: 'Cancel this session?',
                                        message:
                                            'The member is notified and the slot reopens for booking. Any refund is handled separately by staff.',
                                        confirmLabel: 'Cancel session',
                                        destructive: true),
                                    icon: const Icon(Icons.close_rounded, size: 15),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      if (booking.notes != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.sticky_note_2_outlined, size: 14, color: AppColors.inkSoft),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(booking.notes!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5, height: 1.4)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.insights_rounded,
                              label: 'Form history',
                              filled: false,
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => ClientPostureScreen(name: booking.memberName))),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isPast)
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.edit_note_rounded,
                                label: 'Write notes',
                                filled: true,
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => ConsultationNotesScreen(booking: booking))),
                              ),
                            )
                          else
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.chat_bubble_outline_rounded,
                                label: 'Message',
                                filled: false,
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => CoachMessageThreadScreen(booking: booking))),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }
}

/// One small icon+label fact (fee, duration, branch) inside the session
/// card's info `Wrap`. Using `Wrap` instead of one long `Text` joined
/// with "·" means this reflows onto a second line on narrow widths
/// instead of triggering a `Row`/`Text` overflow.
class _InfoBit extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoBit(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.inkSoft),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.inkSoft)),
      ],
    );
  }
}

/// A small, icon + label action button with an explicit, non-scaling
/// font size shared by every call site. The previous version wrapped
/// only the longer labels in `FittedBox(scaleDown)` — the ones needing
/// no scaling rendered at the theme's default size while the ones that
/// did scale rendered visibly smaller, so two buttons in the same row
/// showed different-sized text. Giving every instance the same fixed
/// size up front removes the inconsistency instead of papering over it.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onPressed;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: filled ? Colors.white : AppColors.primary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: filled ? Colors.white : AppColors.primary),
          ),
        ),
      ],
    );
    return SizedBox(
      height: 42,
      child: filled
          ? FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
              onPressed: onPressed,
              child: child,
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
              onPressed: onPressed,
              child: child,
            ),
    );
  }
}
