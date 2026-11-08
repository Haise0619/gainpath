import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show PersistedBookingRecord;
import 'package:gainpath_ui/gainpath_ui.dart';

import '../../application/booking_bloc.dart';
import '../member/booking_details_screen.dart' show resolveBranchLocation;
import 'coach_session_details_screen.dart';

/// Available status filters for coach appointment schedule.
enum CoachStatusFilter {
  all('All'),
  confirmed('Confirmed'),
  pending('Pending hold'),
  completed('Completed'),
  cancelled('Cancelled'),
  expired('Expired');

  const CoachStatusFilter(this.label);
  final String label;
}

/// Date range scoping within the Coach schedule.
enum CoachDateScope {
  selectedDay('Selected Day'),
  next7Days('Next 7 Days'),
  thisWeek('This Week'),
  allDates('All Dates');

  const CoachDateScope(this.label);
  final String label;
}

/// Main tabs for the Coach Roster Dashboard.
enum _RosterTab { schedule, history }

/// AD-M9.1 / Mindbody & Square Appointments-inspired Coach Schedule Dashboard.
///
/// Provides a clear, modern Daily Schedule & Session Management experience:
/// - Sticky header with expandable search, status/date filter sheet, and message inbox badge.
/// - Schedule / History tabs.
/// - Interactive 7-day horizontal calendar rail with quick "Today" jump and date picker.
/// - Daily summary (total sessions, completed, pending notes).
/// - Next session highlight card with direct quick actions.
/// - Needs Attention banner for ended sessions without notes.
/// - Compact, chronologically ordered session appointment cards (~130–160dp).
/// - Dedicated 9-section CoachSessionDetailsScreen on tap.
class CoachRosterScreen extends StatefulWidget {
  const CoachRosterScreen({
    super.key,
    this.persistedBookings,
    this.statusLabels = const {},
    this.details = const {},
    this.onMessage,
    this.onNotes,
    this.onCancel,
    this.onPosture,
    this.showAllDates = false,
    this.historyRange,
    this.onRangeChanged,
    this.onOpenMessages,
    this.todayLocalDate,
    this.serverNowMillis,
    this.recordFor,
    this.onRefresh,
    this.header,
  });

  final List<Booking>? persistedBookings;
  final Map<String, String> statusLabels;
  final Map<String, Widget> details;
  final Widget? header;
  final void Function(Booking)? onMessage;
  final void Function(Booking)? onNotes;
  final void Function(Booking)? onCancel;
  final void Function(Booking)? onPosture;
  final bool showAllDates;
  final bool? historyRange;
  final void Function(bool showHistory)? onRangeChanged;
  final VoidCallback? onOpenMessages;
  final String? todayLocalDate;
  final int? serverNowMillis;
  final PersistedBookingRecord? Function(String bookingId)? recordFor;
  final Future<void> Function()? onRefresh;

  @override
  State<CoachRosterScreen> createState() => _CoachRosterScreenState();
}

class _CoachRosterScreenState extends State<CoachRosterScreen>
    with SingleTickerProviderStateMixin {
  _RosterTab _currentTab = _RosterTab.schedule;
  CoachStatusFilter _statusFilter = CoachStatusFilter.all;
  CoachDateScope _dateScope = CoachDateScope.selectedDay;
  String _historySubFilter =
      'All'; // 'All', 'Completed', 'Cancelled', 'Expired'

  bool _isSearchExpanded = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  late DateTime _selectedDate;
  late final AnimationController _reveal;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthNames = [
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

  @override
  void initState() {
    super.initState();
    _selectedDate = _parseToday();
    if (widget.historyRange != null) {
      _currentTab =
          widget.historyRange! ? _RosterTab.history : _RosterTab.schedule;
    }
    if (widget.showAllDates) {
      _dateScope = CoachDateScope.allDates;
    }
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
  }

  @override
  void didUpdateWidget(CoachRosterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.historyRange != oldWidget.historyRange &&
        widget.historyRange != null) {
      setState(() {
        _currentTab =
            widget.historyRange! ? _RosterTab.history : _RosterTab.schedule;
      });
    }
    if (widget.todayLocalDate != oldWidget.todayLocalDate &&
        widget.todayLocalDate != null) {
      final parsed = _parseToday();
      if (_isSameDay(_selectedDate, _parseDate(oldWidget.todayLocalDate))) {
        setState(() => _selectedDate = parsed);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _reveal.dispose();
    super.dispose();
  }

  DateTime _parseToday() {
    if (widget.todayLocalDate != null && widget.todayLocalDate!.contains('-')) {
      final parsed = _parseDate(widget.todayLocalDate);
      if (parsed != null) return parsed;
    }
    if (widget.serverNowMillis != null) {
      final d = DateTime.fromMillisecondsSinceEpoch(widget.serverNowMillis!);
      return DateTime(d.year, d.month, d.day);
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    final parts = raw.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    return null;
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int get _nowMillis =>
      widget.serverNowMillis ?? DateTime.now().millisecondsSinceEpoch;

  List<Booking> _getRawBookings(bool live) {
    if (widget.persistedBookings != null) {
      return widget.persistedBookings!;
    }
    if (live) {
      return const <Booking>[];
    }
    try {
      return context.watch<BookingBloc>().state.coachRoster;
    } catch (_) {
      try {
        return context.read<BookingRepository>().coachRoster;
      } catch (_) {
        return const <Booking>[];
      }
    }
  }

  bool _matchesStatus(Booking b, CoachStatusFilter filter) {
    if (filter == CoachStatusFilter.all) return true;
    final record = widget.recordFor?.call(b.id);
    final rawStatus = record?.rawStatus.toLowerCase();

    switch (filter) {
      case CoachStatusFilter.confirmed:
        return rawStatus == 'confirmed' || b.status == BookingStatus.confirmed;
      case CoachStatusFilter.pending:
        return rawStatus == 'pending_hold' ||
            rawStatus == 'pending' ||
            b.status == BookingStatus.pending;
      case CoachStatusFilter.completed:
        return rawStatus == 'completed' || b.status == BookingStatus.completed;
      case CoachStatusFilter.cancelled:
        return rawStatus == 'cancelled' || b.status == BookingStatus.cancelled;
      case CoachStatusFilter.expired:
        return rawStatus == 'expired' ||
            (b.status == BookingStatus.pending &&
                record != null &&
                record.holdExpiresAtMillis <= _nowMillis);
      case CoachStatusFilter.all:
        return true;
    }
  }

  bool _isSessionEnded(Booking b) {
    final record = widget.recordFor?.call(b.id);
    if (record != null) {
      return record.endAtMillis <= _nowMillis;
    }
    return b.start
            .add(Duration(minutes: b.durationMin))
            .millisecondsSinceEpoch <=
        _nowMillis;
  }

  bool _isSessionInProgress(Booking b) {
    final record = widget.recordFor?.call(b.id);
    final start = record?.startAtMillis ?? b.start.millisecondsSinceEpoch;
    final end = record?.endAtMillis ??
        b.start.add(Duration(minutes: b.durationMin)).millisecondsSinceEpoch;
    return _nowMillis >= start && _nowMillis < end;
  }

  bool _isSessionHistory(Booking b) {
    final record = widget.recordFor?.call(b.id);
    final rawStatus = record?.rawStatus.toLowerCase();
    if (rawStatus == 'completed' ||
        rawStatus == 'cancelled' ||
        rawStatus == 'expired') {
      return true;
    }
    if (b.status == BookingStatus.completed ||
        b.status == BookingStatus.cancelled) {
      return true;
    }
    return _isSessionEnded(b);
  }

  bool _matchesDateScope(Booking b, CoachDateScope scope, DateTime anchorDay) {
    final record = widget.recordFor?.call(b.id);
    DateTime sessionDate;
    if (record != null) {
      final parsed = _parseDate(record.localDate);
      if (parsed != null) {
        sessionDate = parsed;
      } else {
        final d = DateTime.fromMillisecondsSinceEpoch(record.startAtMillis);
        sessionDate = DateTime(d.year, d.month, d.day);
      }
    } else {
      sessionDate = DateTime(b.start.year, b.start.month, b.start.day);
    }

    switch (scope) {
      case CoachDateScope.selectedDay:
        return _isSameDay(sessionDate, anchorDay);
      case CoachDateScope.next7Days:
        final diff = sessionDate.difference(anchorDay).inDays;
        return diff >= 0 && diff < 7;
      case CoachDateScope.thisWeek:
        final startOfWeek =
            anchorDay.subtract(Duration(days: anchorDay.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return !sessionDate.isBefore(startOfWeek) &&
            !sessionDate.isAfter(endOfWeek);
      case CoachDateScope.allDates:
        return true;
    }
  }

  int get _activeFilterCount {
    var count = 0;
    if (_statusFilter != CoachStatusFilter.all) count++;
    if (_dateScope != CoachDateScope.selectedDay) count++;
    return count;
  }

  void _clearFilters() {
    setState(() {
      _statusFilter = CoachStatusFilter.all;
      _dateScope = CoachDateScope.selectedDay;
      _searchController.clear();
      _searchQuery = '';
      _isSearchExpanded = false;
    });
  }

  void _openDetails(Booking booking) {
    final record = widget.recordFor?.call(booking.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoachSessionDetailsScreen(
          booking: booking,
          record: record,
          live: widget.persistedBookings != null,
          statusLabel: widget.statusLabels[booking.id],
          onMessage: widget.onMessage != null
              ? () => widget.onMessage!(booking)
              : null,
          onNotes:
              widget.onNotes != null ? () => widget.onNotes!(booking) : null,
          onCancel:
              widget.onCancel != null ? () => widget.onCancel!(booking) : null,
          onPosture: widget.onPosture != null
              ? () => widget.onPosture!(booking)
              : null,
          serverNowMillis: widget.serverNowMillis,
        ),
      ),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final hasActive = _statusFilter != CoachStatusFilter.all ||
                _dateScope != CoachDateScope.selectedDay;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.hairline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          'Filter Schedule',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                        ),
                        const Spacer(),
                        if (hasActive)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _statusFilter = CoachStatusFilter.all;
                                _dateScope = CoachDateScope.selectedDay;
                              });
                              setSheetState(() {});
                            },
                            child: const Text(
                              'Clear all',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Eyebrow('DATE SCOPE'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: CoachDateScope.values.map((scope) {
                        final isSelected = _dateScope == scope;
                        return ChoiceChip(
                          label: Text(scope.label),
                          selected: isSelected,
                          selectedColor: AppColors.primaryTint,
                          backgroundColor: AppColors.surfaceAlt,
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color:
                                isSelected ? AppColors.primary : AppColors.ink,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.hairline,
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _dateScope = scope);
                              setSheetState(() {});
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    const Eyebrow('STATUS'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: CoachStatusFilter.values.map((status) {
                        final isSelected = _statusFilter == status;
                        return ChoiceChip(
                          label: Text(status.label),
                          selected: isSelected,
                          selectedColor: AppColors.primaryTint,
                          backgroundColor: AppColors.surfaceAlt,
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color:
                                isSelected ? AppColors.primary : AppColors.ink,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.hairline,
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _statusFilter = status);
                              setSheetState(() {});
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final today = _parseToday();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.ink,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && !_isSameDay(picked, _selectedDate)) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
      _reveal
        ..reset()
        ..forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.persistedBookings != null;
    final allBookings = _getRawBookings(live);
    final today = _parseToday();

    // Query / search filtering
    final filteredBookings = allBookings.where((b) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final record = widget.recordFor?.call(b.id);
        final nameMatch = b.memberName.toLowerCase().contains(q) ||
            ((record?.memberDisplayName ?? '').toLowerCase().contains(q));
        final branchMatch =
            ((record?.branchId ?? '').toLowerCase().contains(q)) ||
                b.branch.toLowerCase().contains(q);
        if (!nameMatch && !branchMatch) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(context, allBookings),
      body: widget.onRefresh != null
          ? RefreshIndicator(
              onRefresh: widget.onRefresh!,
              color: AppColors.primary,
              child: _buildBody(context, filteredBookings, allBookings, today),
            )
          : _buildBody(context, filteredBookings, allBookings, today),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, List<Booking> allBookings) {
    final chipHeight = _currentTab == _RosterTab.history
        ? (MediaQuery.textScalerOf(context).scale(12) * 1.4 + 20)
                .clamp(48.0, 100.0) +
            16
        : 0.0;
    return AppBar(
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(64 + chipHeight),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _buildMainTabs()),
          if (_currentTab == _RosterTab.history)
            SizedBox(height: chipHeight, child: _buildPinnedHistoryFilters()),
        ]),
      ),
      title: _isSearchExpanded
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search member or branch...',
                hintStyle:
                    const TextStyle(color: AppColors.inkSoft, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                      _isSearchExpanded = false;
                    });
                  },
                ),
              ),
              style: const TextStyle(fontSize: 15, color: AppColors.ink),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            )
          : const Text('My schedule'),
      actions: [
        if (!_isSearchExpanded)
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search schedule',
            onPressed: () => setState(() => _isSearchExpanded = true),
          ),
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Filter schedule',
              onPressed: _openFilterSheet,
            ),
            if (_activeFilterCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      '$_activeFilterCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (widget.onOpenMessages != null)
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            tooltip: 'Client messages',
            onPressed: widget.onOpenMessages,
          ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<Booking> filteredBookings,
    List<Booking> allBookings,
    DateTime today,
  ) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        if (widget.header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: widget.header!,
          ),
        if (_currentTab == _RosterTab.schedule) ...[
          // Date strip & quick jump
          _buildDateNavigation(today, allBookings),
          const SizedBox(height: 12),

          // Daily summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildDailySummary(allBookings, today),
          ),
          const SizedBox(height: 14),

          // Needs Attention banner (if applicable)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildNeedsAttentionSection(allBookings),
          ),

          // Next Session Highlight (nearest upcoming today)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildNextSessionHighlight(allBookings, today),
          ),

          // Section Title & active filters reminder
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Text(
                  _dateScope == CoachDateScope.selectedDay
                      ? 'Appointments'
                      : 'Appointments (${_dateScope.label})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkSoft,
                        letterSpacing: .3,
                      ),
                ),
                const Spacer(),
                if (_statusFilter != CoachStatusFilter.all)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _statusFilter.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Sessions List for Schedule tab
          _buildScheduleSessionList(filteredBookings),
        ] else ...[
          // History tab view
          _buildHistorySection(filteredBookings),
        ],
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildMainTabs() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              title: 'Schedule',
              icon: Icons.calendar_today_rounded,
              isSelected: _currentTab == _RosterTab.schedule,
              onTap: () {
                if (_currentTab != _RosterTab.schedule) {
                  setState(() => _currentTab = _RosterTab.schedule);
                  widget.onRangeChanged?.call(false);
                }
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TabButton(
              title: 'History',
              icon: Icons.history_rounded,
              isSelected: _currentTab == _RosterTab.history,
              onTap: () {
                if (_currentTab != _RosterTab.history) {
                  setState(() => _currentTab = _RosterTab.history);
                  widget.onRangeChanged?.call(true);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateNavigation(DateTime today, List<Booking> allBookings) {
    final isTodaySelected = _isSameDay(_selectedDate, today);

    // Build 7 consecutive days anchored around selected date or today
    final startAnchor = _selectedDate.subtract(const Duration(days: 3));
    final days = List.generate(7, (i) => startAnchor.add(Duration(days: i)));

    // Days with sessions
    final sessionDayKeys = <String>{};
    for (final b in allBookings) {
      final record = widget.recordFor?.call(b.id);
      if (record != null) {
        sessionDayKeys.add(record.localDate);
      } else {
        final d = b.start;
        final y = d.year.toString().padLeft(4, '0');
        final m = d.month.toString().padLeft(2, '0');
        final day = d.day.toString().padLeft(2, '0');
        sessionDayKeys.add('$y-$m-$day');
      }
    }

    final dateTitle = isTodaySelected
        ? 'Today · ${_dayNames[_selectedDate.weekday - 1]}, ${_selectedDate.day} ${_monthNames[_selectedDate.month - 1]}'
        : '${_dayNames[_selectedDate.weekday - 1]}, ${_selectedDate.day} ${_monthNames[_selectedDate.month - 1]} ${_selectedDate.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  dateTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isTodaySelected)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                  ),
                  onPressed: () {
                    setState(() => _selectedDate = today);
                    _reveal
                      ..reset()
                      ..forward();
                  },
                  icon: const Icon(Icons.today_rounded, size: 16),
                  label: const Text(
                    'Today',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.calendar_month_outlined, size: 20),
                tooltip: 'Choose date',
                color: AppColors.inkSoft,
                visualDensity: VisualDensity.compact,
                onPressed: _pickDate,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Horizontal 7-Day calendar rail
        SizedBox(
          height: 76,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final d = days[index];
              final isSelected = _isSameDay(d, _selectedDate);
              final isDayToday = _isSameDay(d, today);

              final yStr = d.year.toString().padLeft(4, '0');
              final mStr = d.month.toString().padLeft(2, '0');
              final dStr = d.day.toString().padLeft(2, '0');
              final hasSession = sessionDayKeys.contains('$yStr-$mStr-$dStr');

              return _DayRailCell(
                weekday: _dayNames[d.weekday - 1],
                dayNumber: '${d.day}',
                isSelected: isSelected,
                isToday: isDayToday,
                hasSession: hasSession,
                onTap: () {
                  if (!isSelected) {
                    setState(() => _selectedDate = d);
                    _reveal
                      ..reset()
                      ..forward();
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDailySummary(List<Booking> allBookings, DateTime today) {
    // Calculate sessions on the selected day
    final daySessions = allBookings.where((b) {
      return _matchesDateScope(b, CoachDateScope.selectedDay, _selectedDate);
    }).toList();

    final total = daySessions.length;
    final completed = daySessions.where((b) {
      final record = widget.recordFor?.call(b.id);
      return record?.rawStatus == 'completed' ||
          b.status == BookingStatus.completed;
    }).length;

    final pendingNotes = daySessions.where((b) {
      if (b.status == BookingStatus.cancelled) return false;
      final record = widget.recordFor?.call(b.id);
      if (record?.rawStatus == 'completed' || _isSessionEnded(b)) {
        return b.notes == null || b.notes!.trim().isEmpty;
      }
      return false;
    }).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryColumn(
              value: '$total',
              label: 'Scheduled',
              color: AppColors.primary,
            ),
          ),
          Container(width: 1, height: 28, color: AppColors.hairline),
          Expanded(
            child: _SummaryColumn(
              value: '$completed',
              label: 'Completed',
              color: AppColors.success,
            ),
          ),
          Container(width: 1, height: 28, color: AppColors.hairline),
          Expanded(
            child: _SummaryColumn(
              value: '$pendingNotes',
              label: 'Notes Due',
              color: pendingNotes > 0 ? AppColors.warning : AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeedsAttentionSection(List<Booking> allBookings) {
    final pendingNotesBookings = allBookings.where((b) {
      if (b.status == BookingStatus.cancelled) return false;
      final record = widget.recordFor?.call(b.id);
      if (record?.rawStatus == 'completed' || _isSessionEnded(b)) {
        return b.notes == null || b.notes!.trim().isEmpty;
      }
      return false;
    }).toList();

    if (pendingNotesBookings.isEmpty) {
      return const SizedBox.shrink();
    }

    final count = pendingNotesBookings.length;
    final first = pendingNotesBookings.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: .3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: .15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_late_outlined,
              color: AppColors.warning,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1
                      ? '1 session needs consultation notes'
                      : '$count sessions need consultation notes',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap to write notes for ${first.memberName}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onNotes != null)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: () => widget.onNotes!(first),
              child: const Text(
                'Write',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNextSessionHighlight(List<Booking> allBookings, DateTime today) {
    // Next upcoming confirmed or in-progress session today
    final todaySessions = allBookings.where((b) {
      return _matchesDateScope(b, CoachDateScope.selectedDay, today);
    }).toList();

    Booking? nextSession;
    var earliestStart = double.infinity;

    for (final b in todaySessions) {
      final record = widget.recordFor?.call(b.id);
      final rawStatus = record?.rawStatus.toLowerCase();
      final isConfirmed =
          rawStatus == 'confirmed' || b.status == BookingStatus.confirmed;

      if (!isConfirmed) continue;
      final start =
          (record?.startAtMillis ?? b.start.millisecondsSinceEpoch).toDouble();
      final end = (record?.endAtMillis ??
              b.start
                  .add(Duration(minutes: b.durationMin))
                  .millisecondsSinceEpoch)
          .toDouble();

      if (end > _nowMillis && start < earliestStart) {
        earliestStart = start;
        nextSession = b;
      }
    }

    if (nextSession == null) {
      return const SizedBox.shrink();
    }

    final record = widget.recordFor?.call(nextSession.id);
    final inProgress = _isSessionInProgress(nextSession);
    final resolvedBranch = resolveBranchLocation(
      record?.branchId ?? nextSession.branch,
    );

    final start =
        record?.startAtMillis ?? nextSession.start.millisecondsSinceEpoch;
    final diffMinutes = ((start - _nowMillis) / 60000).round();

    final timeLabel = inProgress
        ? 'In progress now'
        : diffMinutes <= 0
            ? 'Starting now'
            : diffMinutes < 60
                ? 'Starting in $diffMinutes mins'
                : 'Today at ${nextSession.start.hour.toString().padLeft(2, '0')}:${nextSession.start.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: .35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
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
                  color: inProgress ? AppColors.primary : AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      inProgress
                          ? Icons.play_circle_fill_rounded
                          : Icons.access_time_filled_rounded,
                      size: 13,
                      color: inProgress ? Colors.white : AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      inProgress ? 'ACTIVE SESSION' : 'NEXT UP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: inProgress ? Colors.white : AppColors.primary,
                        letterSpacing: .4,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                timeLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: inProgress ? AppColors.primary : AppColors.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryTint,
                child: Text(
                  nextSession.memberName
                      .split(' ')
                      .where((s) => s.isNotEmpty)
                      .map((s) => s[0].toUpperCase())
                      .take(2)
                      .join(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'with ${nextSession.memberName}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${nextSession.durationMin} min Consultation · $resolvedBranch',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.onMessage != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.hairline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => widget.onMessage!(nextSession!),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                  label: const Text('Message', style: TextStyle(fontSize: 12)),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _openDetails(nextSession!),
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: const Text('Details', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSessionList(List<Booking> filteredBookings) {
    final activeSessions = filteredBookings.where((b) {
      if (!_matchesStatus(b, _statusFilter)) return false;
      return _matchesDateScope(b, _dateScope, _selectedDate);
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    if (activeSessions.isEmpty) {
      return _buildEmptyState(
        title: _statusFilter != CoachStatusFilter.all
            ? 'No ${_statusFilter.label.toLowerCase()} sessions found'
            : 'No sessions scheduled',
        message: _dateScope == CoachDateScope.selectedDay
            ? 'No appointments are booked for ${_selectedDate.day} ${_monthNames[_selectedDate.month - 1]}.'
            : 'No appointments match the current filter criteria.',
        actionLabel:
            _activeFilterCount > 0 ? 'Clear filters' : 'Choose another date',
        onAction: _activeFilterCount > 0 ? _clearFilters : _pickDate,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: activeSessions.map((b) {
          final record = widget.recordFor?.call(b.id);
          return _SessionAppointmentCard(
            booking: b,
            record: record,
            serverNowMillis: _nowMillis,
            statusLabel: widget.statusLabels[b.id],
            onTap: () => _openDetails(b),
            onMessage:
                widget.onMessage != null ? () => widget.onMessage!(b) : null,
            onNotes: widget.onNotes != null ? () => widget.onNotes!(b) : null,
            onCancel:
                widget.onCancel != null ? () => widget.onCancel!(b) : null,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPinnedHistoryFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['All', 'Completed', 'Cancelled', 'Expired'].map((sub) {
            final isSelected = _historySubFilter == sub;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(sub),
                selected: isSelected,
                selectedColor: AppColors.primaryTint,
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.inkSoft,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.hairline,
                  ),
                ),
                onSelected: (_) {
                  setState(() => _historySubFilter = sub);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHistorySection(List<Booking> filteredBookings) {
    final historySessions = filteredBookings.where((b) {
      if (!_isSessionHistory(b)) return false;
      if (_historySubFilter == 'Completed') {
        final record = widget.recordFor?.call(b.id);
        return record?.rawStatus == 'completed' ||
            b.status == BookingStatus.completed;
      }
      if (_historySubFilter == 'Cancelled') {
        final record = widget.recordFor?.call(b.id);
        return record?.rawStatus == 'cancelled' ||
            b.status == BookingStatus.cancelled;
      }
      if (_historySubFilter == 'Expired') {
        final record = widget.recordFor?.call(b.id);
        return record?.rawStatus == 'expired' ||
            (b.status == BookingStatus.pending &&
                record != null &&
                record.holdExpiresAtMillis <= _nowMillis);
      }
      return true;
    }).toList()
      ..sort((a, b) => b.start.compareTo(a.start)); // newest first

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (historySessions.isEmpty)
          _buildEmptyState(
            title: 'No past sessions',
            message:
                'You have no past ${_historySubFilter == "All" ? "" : _historySubFilter.toLowerCase()} sessions recorded.',
            actionLabel: 'Return to Schedule',
            onAction: () {
              setState(() => _currentTab = _RosterTab.schedule);
              widget.onRangeChanged?.call(false);
            },
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: historySessions.map((b) {
                final record = widget.recordFor?.call(b.id);
                return _SessionAppointmentCard(
                  booking: b,
                  record: record,
                  serverNowMillis: _nowMillis,
                  statusLabel: widget.statusLabels[b.id],
                  onTap: () => _openDetails(b),
                  onMessage: widget.onMessage != null
                      ? () => widget.onMessage!(b)
                      : null,
                  onNotes:
                      widget.onNotes != null ? () => widget.onNotes!(b) : null,
                  onCancel: widget.onCancel != null
                      ? () => widget.onCancel!(b)
                      : null,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_busy_rounded,
                size: 32,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.inkSoft,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SUB-WIDGETS & PRESENTATION COMPONENTS
// ---------------------------------------------------------------------------

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? AppColors.primary : AppColors.inkSoft,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.primary : AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayRailCell extends StatelessWidget {
  const _DayRailCell({
    required this.weekday,
    required this.dayNumber,
    required this.isSelected,
    required this.isToday,
    required this.hasSession,
    required this.onTap,
  });

  final String weekday;
  final String dayNumber;
  final bool isSelected;
  final bool isToday;
  final bool hasSession;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : isToday
                  ? AppColors.primaryTint
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : isToday
                    ? AppColors.primary.withValues(alpha: .3)
                    : AppColors.hairline,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekday,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white.withValues(alpha: .85)
                      : AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                dayNumber,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? Colors.white
                      : isToday
                          ? AppColors.primary
                          : AppColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasSession
                      ? (isSelected ? Colors.white : AppColors.primary)
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact (~130–160dp) Session Appointment Card
class _SessionAppointmentCard extends StatelessWidget {
  const _SessionAppointmentCard({
    required this.booking,
    this.record,
    required this.serverNowMillis,
    this.statusLabel,
    required this.onTap,
    this.onMessage,
    this.onNotes,
    this.onCancel,
  });

  final Booking booking;
  final PersistedBookingRecord? record;
  final int serverNowMillis;
  final String? statusLabel;
  final VoidCallback onTap;
  final VoidCallback? onMessage;
  final VoidCallback? onNotes;
  final VoidCallback? onCancel;

  bool get _isEnded {
    if (record != null) return record!.endAtMillis <= serverNowMillis;
    return booking.start
            .add(Duration(minutes: booking.durationMin))
            .millisecondsSinceEpoch <=
        serverNowMillis;
  }

  bool get _isInProgress {
    final start = record?.startAtMillis ?? booking.start.millisecondsSinceEpoch;
    final end = record?.endAtMillis ??
        booking.start
            .add(Duration(minutes: booking.durationMin))
            .millisecondsSinceEpoch;
    return serverNowMillis >= start && serverNowMillis < end;
  }

  bool get _canCancel {
    if (record != null) {
      return record!.rawStatus == 'confirmed' && !_isEnded;
    }
    return booking.status == BookingStatus.confirmed && !_isEnded;
  }

  Color _statusColor(BookingStatus status, String? rawStatus) {
    if (rawStatus == 'cancelled' || status == BookingStatus.cancelled) {
      return AppColors.danger;
    }
    if (rawStatus == 'expired') return AppColors.inkSoft;
    if (rawStatus == 'completed' || status == BookingStatus.completed) {
      return AppColors.accent;
    }
    if (_isInProgress) return AppColors.primary;
    if (rawStatus == 'confirmed' || status == BookingStatus.confirmed) {
      return AppColors.success;
    }
    return AppColors.warning;
  }

  String _computedStatusLabel() {
    if (statusLabel != null) return statusLabel!;
    if (record?.rawStatus == 'expired') return 'Expired';
    if (_isInProgress) return 'In Progress';
    switch (booking.status) {
      case BookingStatus.confirmed:
        return _isEnded ? 'Awaiting notes' : 'Confirmed';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.pending:
        return 'Pending hold';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawStatus = record?.rawStatus.toLowerCase();
    final badgeColor = _statusColor(booking.status, rawStatus);
    final statusText = _computedStatusLabel();

    final start = booking.start;
    final end = start.add(Duration(minutes: booking.durationMin));
    String clock(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final timeStr = record == null
        ? '${clock(start)} – ${clock(end)}'
        : '${record!.startLabel} – ${record!.endLabel}';
    final localDate =
        record == null ? start : DateTime.tryParse(record!.localDate) ?? start;
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
    final dateStr =
        '${localDate.day} ${months[localDate.month - 1]} ${localDate.year}';

    final displayName =
        booking.memberName.isNotEmpty && booking.memberName != '-'
            ? booking.memberName
            : (record?.memberDisplayName ?? 'Member');

    final initials = displayName
        .trim()
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase())
        .take(2)
        .join();

    final resolvedBranch = resolveBranchLocation(
      record?.branchId ?? booking.branch,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isInProgress
              ? AppColors.primary.withValues(alpha: .4)
              : AppColors.hairline,
          width: _isInProgress ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .025),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr,
                    key: ValueKey('coach-session-date-${booking.id}'),
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft)),
                const SizedBox(height: 6),
                Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(timeStr,
                          key: ValueKey('coach-session-time-${booking.id}'),
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: _isInProgress
                                  ? AppColors.primary
                                  : AppColors.ink)),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(6)),
                          child: Text('${booking.durationMin}m',
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.inkSoft))),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(statusText,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: badgeColor))),
                    ]),
                const SizedBox(height: 12),

                // Member info row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: AppColors.primaryTint,
                      child: Text(
                        initials.isNotEmpty ? initials : 'M',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '1-on-1 Consultation · $resolvedBranch',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Actions bar
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Lifecycle button
                    if (!_isEnded &&
                        (rawStatus == 'confirmed' ||
                            booking.status == BookingStatus.confirmed) &&
                        onMessage != null) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.hairline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: onMessage,
                        icon: const Icon(Icons.chat_bubble_outline_rounded,
                            size: 14),
                        label: const Text('Message',
                            style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                    ],

                    if ((rawStatus == 'completed' ||
                            (_isEnded &&
                                (rawStatus == 'confirmed' ||
                                    booking.status ==
                                        BookingStatus.confirmed))) &&
                        onNotes != null) ...[
                      if (rawStatus == 'completed' ||
                          booking.status == BookingStatus.completed ||
                          (booking.notes != null &&
                              booking.notes!.trim().isNotEmpty))
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.hairline),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: onNotes,
                          icon: const Icon(Icons.sticky_note_2_outlined,
                              size: 14),
                          label: const Text('View notes',
                              style: TextStyle(fontSize: 12)),
                        )
                      else
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: onNotes,
                          icon: const Icon(Icons.edit_note_rounded, size: 14),
                          label: const Text('Write notes',
                              style: TextStyle(fontSize: 12)),
                        ),
                      const SizedBox(width: 8),
                    ],

                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.inkSoft,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: onTap,
                      icon: const Icon(Icons.info_outline_rounded, size: 14),
                      label:
                          const Text('Details', style: TextStyle(fontSize: 12)),
                    ),

                    // Coach cancellation button (mandatory tooltip for test matching)
                    if (_canCancel && onCancel != null)
                      IconButton(
                        tooltip: 'Cancel session',
                        icon: const Icon(
                          Icons.cancel_outlined,
                          size: 20,
                          color: AppColors.danger,
                        ),
                        onPressed: onCancel,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PUBLIC CLIENT STATS HELPER
// ---------------------------------------------------------------------------

/// Client statistics snapshot model used by Coach Session Details and Roster.
class ClientStats {
  const ClientStats({
    required this.sessionsTogether,
    required this.completed,
    required this.cancelled,
    required this.revenue,
    required this.clientSince,
    required this.mostRecentNote,
  });

  final int sessionsTogether;
  final int completed;
  final int cancelled;
  final double revenue;
  final DateTime clientSince;
  final String? mostRecentNote;

  factory ClientStats.of(
    BuildContext context,
    String memberName, {
    List<Booking>? persistedList,
  }) {
    if (persistedList != null) {
      final forMember = persistedList
          .where((b) => b.memberName == memberName)
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
      final completedList =
          forMember.where((b) => b.status == BookingStatus.completed).toList();
      final cancelledList =
          forMember.where((b) => b.status == BookingStatus.cancelled).toList();
      final notesList = forMember
          .where((b) => b.notes != null && b.notes!.trim().isNotEmpty)
          .toList()
        ..sort((a, b) => b.start.compareTo(a.start));

      return ClientStats(
        sessionsTogether: forMember.length,
        completed: completedList.length,
        cancelled: cancelledList.length,
        revenue: completedList.fold(0.0, (sum, b) => sum + b.fee),
        clientSince:
            forMember.isNotEmpty ? forMember.first.start : DateTime.now(),
        mostRecentNote: notesList.isEmpty ? null : notesList.first.notes,
      );
    }

    try {
      final bookings = context
          .read<BookingRepository>()
          .coachRoster
          .where((b) => b.memberName == memberName)
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
      final completed =
          bookings.where((b) => b.status == BookingStatus.completed).toList();
      final withNotes = [...completed]
        ..sort((a, b) => b.start.compareTo(a.start));

      return ClientStats(
        sessionsTogether: bookings.length,
        completed: completed.length,
        cancelled:
            bookings.where((b) => b.status == BookingStatus.cancelled).length,
        revenue: completed.fold(0.0, (sum, b) => sum + b.fee),
        clientSince: bookings.isEmpty ? DateTime.now() : bookings.first.start,
        mostRecentNote: withNotes.isEmpty
            ? null
            : withNotes
                .firstWhere((b) => b.notes != null,
                    orElse: () => withNotes.first)
                .notes,
      );
    } catch (_) {
      return ClientStats(
        sessionsTogether: 1,
        completed: 0,
        cancelled: 0,
        revenue: 0.0,
        clientSince: DateTime.now(),
        mostRecentNote: null,
      );
    }
  }
}
