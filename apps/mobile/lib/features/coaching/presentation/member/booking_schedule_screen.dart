import 'package:flutter/material.dart';
import '../../application/booking_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../shared/coach_profile_screen.dart';
import 'message_coach_screen.dart';
import 'reschedule_screen.dart';
import 'widgets/booking_card.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/identity.dart';

const _cancelReasons = [
  'Schedule conflict',
  'Feeling unwell',
  'Found a different time',
  'Other',
];

/// Notification dispatched when a user taps "Find a Coach" in an empty booking state.
class SwitchToFindCoachNotification extends Notification {}

/// AD-M7.3 — View Booking Schedule. Two main tabs — Upcoming and History
/// (with All / Completed / Cancelled sub-filters) — backed by the live
/// `memberBookings` list, so cancelling, rescheduling, or rating here
/// (or from the coach's own profile) is reflected immediately without any
/// local copy to keep in sync.
class BookingScheduleScreen extends StatefulWidget {
  const BookingScheduleScreen(
      {super.key,
      this.persistedBookings,
      this.statusLabels = const {},
      this.details = const {},
      this.onCancelHold,
      this.onReview,
      this.onMessage,
      this.onFindCoach,
      this.header,
      this.embedded = false});
  final bool embedded;
  final List<Booking>? persistedBookings;
  final Map<String, String> statusLabels;
  final Map<String, Widget> details;
  final void Function(String)? onCancelHold;
  final void Function(String)? onReview;
  final void Function(Booking)? onMessage;
  final VoidCallback? onFindCoach;
  final Widget? header;

  @override
  State<BookingScheduleScreen> createState() => _BookingScheduleScreenState();
}

enum _MainBookingTab { upcoming, history }

enum _HistoryFilter { all, completed, cancelled }

class _BookingScheduleScreenState extends State<BookingScheduleScreen> {
  _MainBookingTab? _userSelectedTab;
  _HistoryFilter _historyFilter = _HistoryFilter.all;

  _MainBookingTab _currentTab(int upcomingCount, int historyCount) {
    if (_userSelectedTab != null) return _userSelectedTab!;
    if (upcomingCount == 0 && historyCount > 0) {
      return _MainBookingTab.history;
    }
    return _MainBookingTab.upcoming;
  }

  void _onFindCoachPressed() {
    if (widget.onFindCoach != null) {
      widget.onFindCoach!();
    } else if (widget.embedded) {
      SwitchToFindCoachNotification().dispatch(context);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Coach? _coachById(String id) {
    for (final c in context.read<CoachRepository>().coaches) {
      if (c.id == id) return c;
    }
    return null;
  }

  static const _months = [
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

  String _formatSessionTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${_months[d.month - 1]}  ·  $h:$m';
  }

  Widget _buildMainTabs(
      _MainBookingTab currentTab, int upcomingCount, int historyCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMainTabButton(
              tab: _MainBookingTab.upcoming,
              label: 'Upcoming',
              count: upcomingCount,
              isSelected: currentTab == _MainBookingTab.upcoming,
              icon: Icons.event_available_rounded,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildMainTabButton(
              tab: _MainBookingTab.history,
              label: 'History',
              count: historyCount,
              isSelected: currentTab == _MainBookingTab.history,
              icon: Icons.history_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainTabButton({
    required _MainBookingTab tab,
    required String label,
    required int count,
    required bool isSelected,
    required IconData icon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _userSelectedTab = tab),
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: .24),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
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
                  color: isSelected ? Colors.white : AppColors.inkSoft,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.ink,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: .22)
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryFilterChips(
      int totalCount, int completedCount, int cancelledCount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildHistoryFilterChip(
            filter: _HistoryFilter.all,
            label: 'All',
            count: totalCount,
            icon: Icons.dashboard_outlined,
          ),
          _buildHistoryFilterChip(
            filter: _HistoryFilter.completed,
            label: 'Completed',
            count: completedCount,
            icon: Icons.task_alt_outlined,
          ),
          _buildHistoryFilterChip(
            filter: _HistoryFilter.cancelled,
            label: 'Cancelled',
            count: cancelledCount,
            icon: Icons.event_busy_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryFilterChip({
    required _HistoryFilter filter,
    required String label,
    required int count,
    required IconData icon,
  }) {
    final isSelected = _historyFilter == filter;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _historyFilter = filter),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.hairline,
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: .18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? Colors.white : AppColors.inkSoft,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.ink,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: .22)
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Row(
      children: [
        Eyebrow(title),
        const SizedBox(width: 8),
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkSoft,
                  height: 1.4,
                ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action,
          ],
        ],
      ),
    );
  }

  Widget _buildFindCoachButton() {
    return FilledButton.icon(
      onPressed: _onFindCoachPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: const Icon(Icons.search_rounded, size: 18),
      label: const Text(
        'Find a Coach',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookings = widget.persistedBookings == null
        ? context.watch<BookingBloc>().state
        : null;
    final upcoming = widget.persistedBookings
            ?.where((b) =>
                b.status == BookingStatus.pending ||
                b.status == BookingStatus.confirmed)
            .toList() ??
        bookings!.memberUpcoming;
    final completed = widget.persistedBookings
            ?.where((b) => b.status == BookingStatus.completed)
            .toList() ??
        bookings!.memberCompleted;
    final cancelled = widget.persistedBookings
            ?.where((b) => b.status == BookingStatus.cancelled)
            .toList() ??
        bookings!.memberCancelled;
    final live = widget.persistedBookings != null;

    final currentTab =
        _currentTab(upcoming.length, completed.length + cancelled.length);

    final body = PageBody(
      children: [
        if (widget.header != null) widget.header!,
        _buildMainTabs(
          currentTab,
          upcoming.length,
          completed.length + cancelled.length,
        ),
        if (currentTab == _MainBookingTab.upcoming) ...[
          _sectionHeader('Upcoming', upcoming.length),
          if (upcoming.isEmpty)
            _emptyState(
              context,
              icon: Icons.event_available_outlined,
              title: 'No upcoming sessions',
              subtitle:
                  'You have no scheduled sessions. Connect with a top coach to plan your next workout.',
              action: _buildFindCoachButton(),
            )
          else
            ...upcoming.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: BookingCard(
                    booking: b,
                    live: live,
                    statusLabel: widget.statusLabels[b.id],
                    details: widget.details[b.id],
                    onReschedule: live ? null : () => _reschedule(b),
                    onCancel: live
                        ? (widget.onCancelHold == null ||
                                widget.statusLabels[b.id] != 'Pending hold'
                            ? null
                            : () => widget.onCancelHold!(b.id))
                        : () => _cancel(b),
                    onMessage: live
                        ? (widget.onMessage == null
                            ? null
                            : () => widget.onMessage!(b))
                        : () => _message(b),
                  ),
                )),
        ] else ...[
          _buildHistoryFilterChips(
            completed.length + cancelled.length,
            completed.length,
            cancelled.length,
          ),
          if (_historyFilter == _HistoryFilter.all) ...[
            if (completed.isEmpty && cancelled.isEmpty)
              _emptyState(
                context,
                icon: Icons.history_rounded,
                title: 'No session history',
                subtitle:
                    'Completed workouts and coach notes will appear here once you finish a session.',
                action: _buildFindCoachButton(),
              )
            else ...[
              if (completed.isNotEmpty) ...[
                _sectionHeader('Completed', completed.length),
                ...completed.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: BookingCard(
                        booking: b,
                        live: live,
                        statusLabel: widget.statusLabels[b.id],
                        details: widget.details[b.id],
                        onMessage: live
                            ? (widget.onMessage == null
                                ? null
                                : () => widget.onMessage!(b))
                            : () => _message(b),
                        onRate: live
                            ? (widget.onReview == null
                                ? null
                                : () => widget.onReview!(b.id))
                            : () => _rate(b),
                      ),
                    )),
              ],
              if (cancelled.isNotEmpty) ...[
                if (completed.isNotEmpty) const SizedBox(height: 14),
                _sectionHeader('Cancelled', cancelled.length),
                ...cancelled.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: BookingCard(
                        booking: b,
                        live: live,
                        statusLabel: widget.statusLabels[b.id],
                        details: widget.details[b.id],
                        onBookAgain: live ? null : () => _bookAgain(b),
                        onMessage: live && widget.onMessage != null
                            ? () => widget.onMessage!(b)
                            : null,
                      ),
                    )),
              ],
            ],
          ] else if (_historyFilter == _HistoryFilter.completed) ...[
            _sectionHeader('Completed', completed.length),
            if (completed.isEmpty)
              _emptyState(
                context,
                icon: Icons.task_alt_rounded,
                title: 'No completed sessions',
                subtitle:
                    'Past sessions, ratings, and coach consultation notes will appear here.',
                action: _buildFindCoachButton(),
              )
            else
              ...completed.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: BookingCard(
                      booking: b,
                      live: live,
                      statusLabel: widget.statusLabels[b.id],
                      details: widget.details[b.id],
                      onMessage: live
                          ? (widget.onMessage == null
                              ? null
                              : () => widget.onMessage!(b))
                          : () => _message(b),
                      onRate: live
                          ? (widget.onReview == null
                              ? null
                              : () => widget.onReview!(b.id))
                          : () => _rate(b),
                    ),
                  )),
          ] else if (_historyFilter == _HistoryFilter.cancelled) ...[
            _sectionHeader('Cancelled', cancelled.length),
            if (cancelled.isEmpty)
              _emptyState(
                context,
                icon: Icons.event_busy_outlined,
                title: 'No cancelled sessions',
                subtitle:
                    'Any cancelled appointments or expired slot holds will be logged here.',
              )
            else
              ...cancelled.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: BookingCard(
                      booking: b,
                      live: live,
                      statusLabel: widget.statusLabels[b.id],
                      details: widget.details[b.id],
                      onBookAgain: live ? null : () => _bookAgain(b),
                      onMessage: live && widget.onMessage != null
                          ? () => widget.onMessage!(b)
                          : null,
                    ),
                  )),
          ],
        ],
      ],
    );
    return widget.embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: const Text('My bookings')), body: body);
  }

  void _bookAgain(Booking b) {
    final coach = _coachById(b.coachId);
    if (coach == null) return;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => CoachProfileScreen(coach: coach)));
  }

  Future<void> _reschedule(Booking b) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => RescheduleScreen(booking: b)));
    if (mounted) setState(() {});
  }

  void _message(Booking b) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => MessageCoachScreen(booking: b)));
  }

  Future<void> _cancel(Booking b) async {
    String? reason = _cancelReasons.first;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Cancel this session?',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          b.coachName.trim().isNotEmpty
                              ? b.coachName.trim()[0].toUpperCase()
                              : 'C',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.coachName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_formatSessionTime(b.start)}  ·  ${b.branch}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.danger,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cancelling frees the slot for other members. You can cancel up to 12 hours before the start time.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Eyebrow('Reason'),
              RadioGroup<String>(
                groupValue: reason,
                onChanged: (v) => setSheet(() => reason = v),
                child: Column(
                  children: _cancelReasons.map((r) {
                    final isSelected = reason == r;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => setSheet(() => reason = r),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryTint
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.hairline,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                size: 19,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.inkSoft,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  r,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Keep booking', maxLines: 1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Cancel session', maxLines: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<BookingBloc>().add(BookingCancelled(
        b.id, 'Member requested — ${reason ?? _cancelReasons.first}.'));
    if (mounted) showToast(context, 'Session cancelled.');
  }

  Future<void> _rate(Booking b) async {
    int stars = 0;
    final controller = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          const starFeedback = [
            '',
            'Needs improvement',
            'Fair session',
            'Good workout',
            'Very good!',
            'Outstanding session!'
          ];
          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Rate your session',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                const SizedBox(height: 4),
                Text('with ${b.coachName}',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkSoft,
                        )),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          return IconButton(
                            iconSize: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            onPressed: () => setSheet(() => stars = i + 1),
                            icon: Icon(
                              i < stars
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: AppColors.accent,
                            ),
                          );
                        }),
                      ),
                      if (stars > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accentTint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              starFeedback[stars],
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Anything you want to add?',
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.hairline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.hairline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: stars == 0 ? null : () => Navigator.pop(ctx),
                    child: const Text('Submit review'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    final reviewText = controller.text.trim();
    controller.dispose();
    if (stars == 0 || !mounted) return;
    context.read<BookingBloc>().add(BookingRated(b.id));
    setState(() {
      final coach = _coachById(b.coachId);
      if (coach != null) {
        coach.topReviews.insert(
          0,
          CoachReview(
            context.read<MemberProfileRepository>().memberName,
            stars,
            reviewText.isEmpty ? 'Great session.' : reviewText,
            DateTime.now(),
          ),
        );
      }
    });
    if (mounted) showToast(context, 'Thanks for your review.');
  }
}
