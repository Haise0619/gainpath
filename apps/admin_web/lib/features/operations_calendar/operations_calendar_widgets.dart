part of 'operations_calendar_screen.dart';

const _small = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: AppColors.inkSoft,
);
const _strong = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w700,
  color: AppColors.ink,
);
final _compactButton = OutlinedButton.styleFrom(
  minimumSize: const Size(0, 40),
  padding: const EdgeInsets.symmetric(horizontal: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
);
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

extension on CalendarEventType {
  String get label => switch (this) {
        CalendarEventType.booking => 'Coach booking',
        CalendarEventType.availability => 'Coach availability',
        CalendarEventType.announcement => 'Announcement',
        CalendarEventType.groupClass => 'Group class',
      };

  String get plural => switch (this) {
        CalendarEventType.booking => 'Coach bookings',
        CalendarEventType.availability => 'Coach availability',
        CalendarEventType.announcement => 'Announcements',
        CalendarEventType.groupClass => 'Group Classes',
      };

  IconData get icon => switch (this) {
        CalendarEventType.booking => Icons.event_available_outlined,
        CalendarEventType.availability => Icons.schedule_rounded,
        CalendarEventType.announcement => Icons.campaign_outlined,
        CalendarEventType.groupClass => Icons.groups_outlined,
      };

  Color get fill => switch (this) {
        CalendarEventType.booking => AppColors.primaryTint,
        CalendarEventType.availability => AppColors.infoTint,
        CalendarEventType.announcement => AppColors.accentTint,
        CalendarEventType.groupClass => const Color(0xFFE6F6F1),
      };

  Color get ink => switch (this) {
        CalendarEventType.booking => AppColors.primaryDark,
        CalendarEventType.availability => const Color(0xff194b9e),
        CalendarEventType.announcement => const Color(0xff834107),
        CalendarEventType.groupClass => const Color(0xFF145D49),
      };
}

String _statusLabel(String status) {
  if (status.isEmpty) return 'Unavailable';
  final readable = status.replaceAll('_', ' ');
  return '${readable[0].toUpperCase()}${readable.substring(1)}';
}

bool _agendaAllDay(OperationsEvent event) =>
    event.allDay ||
    event.type == CalendarEventType.announcement &&
        _civil(_inMalaysia(event.start)) !=
            _civil(_inMalaysia(
                event.end.subtract(const Duration(microseconds: 1))));

int _compareEvents(OperationsEvent first, OperationsEvent second) {
  final a = _agendaAllDay(first) ? 0 : 1;
  final b = _agendaAllDay(second) ? 0 : 1;
  final cmp = a.compareTo(b);
  return cmp != 0 ? cmp : first.start.compareTo(second.start);
}

String _time(BuildContext context, DateTime instant) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(_inMalaysia(instant)),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

String _shortTime(DateTime time) {
  final local = _inMalaysia(time);
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _eventTime(BuildContext context, OperationsEvent event,
    {DateTime? day}) {
  if (event.allDay) return 'All day';
  if (_agendaAllDay(event) && day != null) return 'Multi-day';
  if (day != null && event.start.isBefore(_instant(day))) {
    return 'Continues until ${_time(context, event.end)}';
  }
  return '${_time(context, event.start)} – ${_time(context, event.end)}';
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.insights});
  final bool insights;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.calendar_month_outlined,
                color: AppColors.primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Operations Calendar',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 3),
                Text(
                  insights
                      ? 'Compare daily branch activity and review reporting trends.'
                      : 'Monitor coaching sessions, staff availability and gym operations.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 700)
            const Padding(
              padding: EdgeInsets.only(top: 14, left: 10),
              child: Tooltip(
                message: 'Asia/Kuala_Lumpur (UTC+08:00)',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.public_rounded,
                        size: 15, color: AppColors.inkSoft),
                    SizedBox(width: 5),
                    Text('Malaysia Time', style: _small),
                  ],
                ),
              ),
            ),
        ],
      );
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.insights, required this.onChanged});
  final bool insights;
  final ValueChanged<bool> onChanged;

  Widget _option(bool value, String label, IconData icon) => TextButton.icon(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 11),
          foregroundColor:
              insights == value ? AppColors.primaryDark : AppColors.inkSoft,
          backgroundColor:
              insights == value ? AppColors.surface : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        onPressed: () => onChanged(value),
        icon: Icon(icon, size: 16),
        label: Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          border: Border.all(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Wrap(
            runSpacing: 2,
            children: [
              Semantics(
                  selected: !insights,
                  child: _option(
                      false, 'Schedule', Icons.calendar_view_month_outlined)),
              Semantics(
                  selected: insights,
                  child: _option(true, 'Insights', Icons.grid_on_rounded)),
            ],
          ),
        ),
      );
}

class _CalendarMenu<T> extends StatelessWidget {
  const _CalendarMenu({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.items,
    required this.onSelected,
  });
  final IconData icon;
  final String label;
  final String tooltip;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
        tooltip: tooltip,
        onSelected: onSelected,
        itemBuilder: (_) => items,
        position: PopupMenuPosition.under,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          constraints: BoxConstraints(
            minHeight: 42,
            maxWidth:
                (MediaQuery.sizeOf(context).width - 30).clamp(120.0, 322.0),
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.inkSoft),
              const SizedBox(width: 7),
              Flexible(
                  child: Text(label,
                      style: _strong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 5),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16, color: AppColors.inkSoft),
            ],
          ),
        ),
      );
}

class _DateNumber extends StatelessWidget {
  const _DateNumber(
      {required this.date,
      required this.selected,
      required this.today,
      this.adjacent = false});
  final int date;
  final bool selected;
  final bool today;
  final bool adjacent;

  @override
  Widget build(BuildContext context) => Container(
        width: 25,
        height: 25,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: today
              ? AppColors.primary
              : selected
                  ? AppColors.primaryTint
                  : Colors.transparent,
        ),
        child: Text(
          '$date',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: today
                ? Colors.white
                : selected
                    ? AppColors.primaryDark
                    : adjacent
                        ? AppColors.inkSoft
                        : AppColors.ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _MiniCalendar extends StatelessWidget {
  const _MiniCalendar(
      {required this.month,
      required this.today,
      required this.selected,
      required this.onSelected});
  final DateTime month;
  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final first = month.subtract(Duration(days: month.weekday - 1));
    final dayCount = DateTime.utc(month.year, month.month + 1, 0).day;
    final rows = (dayCount + month.weekday - 1 + 6) ~/ 7;
    final local = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 9),
          child: Text(local.formatMonthYear(month),
              style: _strong,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              semanticsLabel: 'Mini calendar, ${local.formatMonthYear(month)}'),
        ),
        Row(children: [
          for (final label in _weekdays)
            Expanded(
                child: Center(
              child: Text(label.substring(0, 1), style: _small),
            )),
        ]),
        const SizedBox(height: 3),
        for (var week = 0; week < rows; week++)
          Row(children: [
            for (var day = 0; day < 7; day++)
              Expanded(
                  child: _dayCell(
                      context, first.add(Duration(days: week * 7 + day)))),
          ]),
      ],
    );
  }

  Widget _dayCell(BuildContext context, DateTime date) => Tooltip(
        message:
            'Jump to ${MaterialLocalizations.of(context).formatFullDate(date)}',
        child: InkWell(
          onTap: () => onSelected(date),
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 29,
            child: Center(
                child: _DateNumber(
              date: date.day,
              selected: date == selected,
              today: date == today,
              adjacent: date.month != month.month,
            )),
          ),
        ),
      );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => _Surface(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 14,
            runSpacing: 9,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Event legend', style: _strong),
              for (final type in CalendarEventType.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _EventIcon(type: type, size: 24),
                    const SizedBox(width: 7),
                    Flexible(child: Text(type.plural, style: _small)),
                  ],
                ),
            ],
          ),
        ),
      );
}

class _EventIcon extends StatelessWidget {
  const _EventIcon({required this.type, this.size = 30});
  final CalendarEventType type;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: type.fill,
          borderRadius: BorderRadius.circular(size >= 30 ? 8 : 6),
        ),
        child: Icon(type.icon, size: size * .55, color: type.ink),
      );
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.timeline,
    required this.branch,
    required this.showBranch,
    required this.onTap,
  });

  final OperationsEvent event;
  final bool timeline;
  final String branch;
  final bool showBranch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactive = event.type == CalendarEventType.booking &&
        {'cancelled', 'expired', 'refunded'}.contains(event.status);
    final held = event.type == CalendarEventType.booking &&
        (event.status == 'pending_hold' ||
            event.paymentStatus == 'pending' ||
            event.paymentStatus == 'reconciliation_required');
    final ink = inactive ? AppColors.inkSoft : event.type.ink;
    final fill = inactive
        ? AppColors.membershipFreeTint
        : held
            ? const Color(0xfff6eeff)
            : event.type.fill;
    final status = _statusLabel(event.status);
    final tooltip = '${event.type.label} · ${event.title}\n'
        '${_eventTime(context, event)} · $branch · $status';
    final title = event.type == CalendarEventType.availability && !timeline
        ? 'Available · ${event.title}'
        : event.title;
    return Tooltip(
      message: tooltip,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(timeline ? 7 : 4),
        child: Material(
          color: fill,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                    left: BorderSide(
                        color: ink.withValues(alpha: .65), width: 2)),
              ),
              child: LayoutBuilder(builder: (context, constraints) {
                final scaler = MediaQuery.textScalerOf(context);
                final lines =
                    timeline && constraints.maxHeight >= scaler.scale(29);
                final canShowIcon =
                    constraints.maxWidth >= (timeline ? 70 : 46) &&
                        constraints.maxHeight >= 14;
                final branchLine = showBranch &&
                    constraints.maxWidth >= 154 &&
                    constraints.maxHeight >= scaler.scale(21);
                final prefix = event.type == CalendarEventType.booking &&
                        !timeline &&
                        constraints.maxWidth >= 105
                    ? '${_shortTime(event.start)} '
                    : '';
                final suffix = inactive || held ? ' · $status' : '';
                return Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: constraints.maxWidth < 40 ? 2 : 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (canShowIcon) ...[
                        Icon(
                            inactive
                                ? Icons.event_busy_outlined
                                : held
                                    ? Icons.pending_outlined
                                    : event.type.icon,
                            size: timeline ? 14 : 12,
                            color: ink),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                          child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                              child: Text(
                            '$prefix$title$suffix',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: timeline && constraints.maxWidth >= 70
                                    ? 12
                                    : 10.5,
                                height: 1.12,
                                color: ink,
                                fontWeight: FontWeight.w700,
                                decoration:
                                    inactive && event.status == 'cancelled'
                                        ? TextDecoration.lineThrough
                                        : null),
                          )),
                          if (lines)
                            Text(
                              showBranch ? branch : _eventTime(context, event),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10.5, color: ink, height: 1.3),
                            )
                          else if (branchLine)
                            Text(
                              branch,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 8.5, color: ink, height: 1),
                            ),
                        ],
                      )),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback(this.message, {this.retry});
  final String message;
  final VoidCallback? retry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: retry == null ? AppColors.accentTint : AppColors.dangerTint,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 5, 8, 5),
            child: Row(
              children: [
                Icon(retry == null ? Icons.info_outline : Icons.error_outline,
                    color:
                        retry == null ? AppColors.accentDark : AppColors.danger,
                    size: 17),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(message,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              retry == null ? AppColors.ink : AppColors.danger,
                        ))),
                if (retry != null)
                  TextButton(
                      onPressed: retry,
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger),
                      child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
}

class _CalendarDrawer extends StatelessWidget {
  const _CalendarDrawer({required this.child, required this.onClose});
  final Widget child;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Drawer(
        semanticLabel: 'Calendar details panel',
        width: MediaQuery.sizeOf(context).width.clamp(0.0, 414.0),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(18)),
        ),
        backgroundColor: AppColors.surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(5, 8, 10, 0),
                  child: IconButton(
                    onPressed: onClose,
                    tooltip: 'Close panel',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
              Expanded(
                  child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(23, 0, 23, 27),
                child: child,
              )),
            ],
          ),
        ),
      );
}

class _Agenda extends StatelessWidget {
  const _Agenda({
    required this.date,
    required this.today,
    required this.events,
    required this.loading,
    required this.expanded,
    required this.incomplete,
    required this.branch,
    required this.onOpenEvent,
    this.onOpenAll,
  });
  final DateTime date;
  final bool today;
  final List<OperationsEvent> events;
  final bool loading;
  final bool expanded;
  final bool incomplete;
  final String Function(OperationsEvent) branch;
  final ValueChanged<OperationsEvent> onOpenEvent;
  final VoidCallback? onOpenAll;

  @override
  Widget build(BuildContext context) {
    final local = MaterialLocalizations.of(context);
    final visible = expanded ? events : events.take(4);
    if (loading) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(today ? 'Today’s agenda' : 'Daily agenda', style: _strong),
        const SizedBox(height: 6),
        const Text('Loading activities…', style: _small),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(today ? 'Today’s agenda' : 'Daily agenda',
            style: expanded
                ? Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24)
                : _strong),
        const SizedBox(height: 4),
        Text(
          expanded
              ? local.formatFullDate(date)
              : '${_weekdays[date.weekday - 1]}, ${local.formatShortMonthDay(date)}',
          style: _small,
        ),
        const SizedBox(height: 7),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
                incomplete
                    ? 'No activities from the available sources.'
                    : 'No scheduled activities for this day.',
                style: _small),
          ),
        for (final event in visible)
          InkWell(
            key: ValueKey('${expanded ? 'drawer' : 'agenda'}-${event.id}'),
            borderRadius: BorderRadius.circular(7),
            onTap: () => onOpenEvent(event),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EventIcon(type: event.type),
                  const SizedBox(width: 7),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title,
                          style: _strong,
                          maxLines: expanded ? 3 : 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(_eventTime(context, event, day: date),
                          style: _small),
                      Text('${branch(event)} · ${_statusLabel(event.status)}',
                          style: _small,
                          maxLines: expanded ? 3 : 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  )),
                ],
              ),
            ),
          ),
        if (onOpenAll != null && events.length > 4)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onOpenAll,
              child: Text('View all ${events.length} activities'),
            ),
          ),
      ],
    );
  }
}

class _EventDetails extends StatelessWidget {
  const _EventDetails({
    required this.event,
    required this.branch,
    required this.onSource,
    required this.onCoach,
  });
  final OperationsEvent event;
  final String branch;
  final VoidCallback onSource;
  final VoidCallback onCoach;

  @override
  Widget build(BuildContext context) {
    final local = MaterialLocalizations.of(context);
    final start = _inMalaysia(event.start);
    final end = _inMalaysia(event.end);
    final lastDay = event.allDay
        ? _inMalaysia(event.end.subtract(const Duration(microseconds: 1)))
        : end;
    final dates = _civil(start) == _civil(lastDay)
        ? local.formatFullDate(start)
        : '${local.formatShortDate(start)} – ${local.formatShortDate(lastDay)}';
    final sourceLabel = switch (event.type) {
      CalendarEventType.booking => 'View Booking',
      CalendarEventType.availability => 'Manage Schedule',
      CalendarEventType.announcement => 'View Announcement',
      CalendarEventType.groupClass => 'View Class & Participants',
    };
    final heading = switch (event.type) {
      CalendarEventType.booking => 'Booking details',
      CalendarEventType.availability => 'Availability details',
      CalendarEventType.announcement => 'Announcement details',
      CalendarEventType.groupClass => 'Group class details',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
            alignment: Alignment.centerLeft,
            child: _EventIcon(type: event.type, size: 38)),
        const SizedBox(height: 11),
        Text(heading, style: _small),
        const SizedBox(height: 3),
        Text(event.title,
            style:
                Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24)),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: event.type.fill,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Text(_statusLabel(event.status),
                  style: TextStyle(
                    color: event.type.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ),
        ),
        const SizedBox(height: 17),
        if (event.description case final description?
            when description.trim().isNotEmpty) ...[
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 13),
        ],
        const Divider(height: 1, color: AppColors.hairline),
        _DetailLine(
            Icons.location_on_outlined,
            event.type == CalendarEventType.announcement
                ? 'Audience'
                : 'Branch',
            branch),
        if (event.type == CalendarEventType.announcement) ...[
          _DetailLine(Icons.event_outlined, 'Starts · Malaysia',
              '${local.formatShortDate(start)} · ${_time(context, event.start)}'),
          _DetailLine(Icons.event_available_outlined, 'Ends · Malaysia',
              '${local.formatShortDate(end)} · ${_time(context, event.end)}'),
        ] else ...[
          _DetailLine(Icons.event_outlined, 'Date', dates),
          _DetailLine(Icons.schedule_rounded, 'Time · Malaysia',
              '${_time(context, event.start)} – ${_time(context, event.end)}'),
        ],
        if (event.category case final category? when category.isNotEmpty)
          _DetailLine(
              Icons.label_outline_rounded, 'Category', _statusLabel(category)),
        if (event.paymentStatus case final payment? when payment.isNotEmpty)
          _DetailLine(
              Icons.payments_outlined, 'Payment status', _statusLabel(payment)),
        if (event.type != CalendarEventType.announcement)
          _DetailLine(
              Icons.tag_rounded,
              event.type == CalendarEventType.booking
                  ? 'Booking reference'
                  : (event.type == CalendarEventType.groupClass
                      ? 'Class reference'
                      : 'Schedule reference'),
              event.sourceId,
              selectable: true),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onSource,
          icon: const Icon(Icons.arrow_outward_rounded, size: 17),
          label: Text(sourceLabel),
        ),
        if (event.type == CalendarEventType.booking &&
            event.coachId != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onCoach, child: const Text('View Coach')),
        ],
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.icon, this.label, this.value,
      {this.selectable = false});
  final IconData icon;
  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: AppColors.inkSoft),
            const SizedBox(width: 9),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _small),
                const SizedBox(height: 3),
                if (selectable)
                  SelectableText(value, style: _strong)
                else
                  Text(value, style: _strong),
              ],
            )),
          ],
        ),
      );
}

enum _Metric {
  visits(
      'Gym Visits',
      'visits',
      'Successful gym QR check-ins by check-in date.',
      [5, 15, 30],
      ['1–5', '6–15', '16–30', '31+']),
  bookings(
      'Coach Bookings',
      'bookings',
      'Booking records by creation date, including all booking statuses.',
      [2, 5, 10],
      ['1–2', '3–5', '6–10', '11+']),
  receipts(
      'Confirmed Sandbox Receipts (MYR)',
      'coachingMinor',
      'Confirmed coaching receipts by payment verification date.',
      [10000, 30000, 60000],
      ['0.01–100', '100.01–300', '300.01–600', '600.01+']);

  const _Metric(
      this.title, this.source, this.basis, this.thresholds, this.buckets);
  final String title;
  final String source;
  final String basis;
  final List<int> thresholds;
  final List<String> buckets;

  int? value(CalendarInsightDay? daily) => switch (this) {
        _Metric.visits => daily?.visits,
        _Metric.bookings => daily?.bookings,
        _Metric.receipts => daily?.coachingMinor,
      };

  int level(int value) {
    if (value == 0) return 0;
    return thresholds.where((threshold) => value > threshold).length + 1;
  }

  String format(int value, {bool short = false}) {
    if (this == _Metric.receipts) {
      final text = (value / 100).toStringAsFixed(2);
      return short ? text : 'MYR $text';
    }
    return '$value';
  }
}

const _heatColors = [
  Color(0xfff6f2fc),
  Color(0xffede7fb),
  Color(0xffdfcef8),
  Color(0xffa573ec),
  Color(0xff672ab9),
];

class _Heatmap extends StatelessWidget {
  const _Heatmap(
      {required this.month,
      required this.metric,
      required this.selected,
      required this.today,
      required this.branch,
      required this.loading,
      required this.daily,
      required this.onSelect,
      required this.onReport});

  final DateTime month;
  final _Metric metric;
  final DateTime selected;
  final DateTime today;
  final String branch;
  final bool loading;
  final List<CalendarInsightDay> daily;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final data = {for (final day in daily) _civil(day.date): day};
            final grid = _buildGrid(context, data);
            final detail = _buildDetail(context, data[selected]);
            if (constraints.maxWidth < 850) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [grid, const SizedBox(height: 15), detail],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: grid),
                const SizedBox(width: 18),
                SizedBox(width: 256, child: detail),
              ],
            );
          },
        ),
      );

  Widget _buildGrid(
      BuildContext context, Map<DateTime, CalendarInsightDay> data) {
    final local = MaterialLocalizations.of(context);
    final first = month.subtract(Duration(days: month.weekday - 1));
    final days = DateTime.utc(month.year, month.month + 1, 0).day;
    final rows = (days + month.weekday - 1 + 6) ~/ 7;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(metric.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('${metric.basis} Malaysia Time.', style: _small),
        const SizedBox(height: 12),
        Row(children: [
          for (final label in _weekdays)
            Expanded(
                child: Center(child: Text(label, style: _small, maxLines: 1))),
        ]),
        const SizedBox(height: 7),
        for (var row = 0; row < rows; row++)
          Row(children: [
            for (var col = 0; col < 7; col++)
              Expanded(
                  child: _cell(context, local,
                      first.add(Duration(days: row * 7 + col)), data)),
          ]),
        const SizedBox(height: 10),
        Wrap(
          runSpacing: 8,
          spacing: 9,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Less', style: _small),
            _HeatSwatch(color: _heatColors.first, label: '0'),
            for (var index = 0; index < metric.buckets.length; index++)
              _HeatSwatch(
                  color: _heatColors[index + 1], label: metric.buckets[index]),
            const Text('More', style: _small),
            const _HeatSwatch(color: AppColors.surface, label: '— Unavailable'),
          ],
        ),
      ],
    );
  }

  Widget _cell(BuildContext context, MaterialLocalizations local, DateTime date,
      Map<DateTime, CalendarInsightDay> data) {
    if (date.month != month.month) {
      return const SizedBox(height: 56);
    }
    final value = metric.value(data[date]);
    final level = value == null ? null : metric.level(value);
    final selectedDay = date == selected;
    final fill = level == null ? AppColors.surface : _heatColors[level];
    final ink = (level ?? 0) >= 4 ? Colors.white : AppColors.ink;
    final display = value == null ? '—' : metric.format(value, short: true);
    final label = loading
        ? 'Loading'
        : value == null
            ? 'Unavailable'
            : metric.format(value);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Semantics(
        selected: selectedDay,
        child: Tooltip(
          message: '${local.formatFullDate(date)} · $label',
          child: Material(
            color: fill,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: selectedDay ? AppColors.primaryDark : AppColors.hairline,
                width: selectedDay ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(7),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelect(date),
              child: SizedBox(
                height: 53,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${date.day}',
                          maxLines: 1,
                          style: TextStyle(
                            color: ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          )),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(display,
                              maxLines: 1,
                              style: TextStyle(
                                color: ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              )),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetail(BuildContext context, CalendarInsightDay? selection) {
    final local = MaterialLocalizations.of(context);
    final value = metric.value(selection);
    final future = selected.isAfter(today);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Daily breakdown',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(local.formatFullDate(selected), style: _small),
            Text(branch, style: _small),
            const SizedBox(height: 14),
            Text(
                loading
                    ? 'Loading…'
                    : value == null
                        ? 'Unavailable'
                        : metric.format(value),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 24,
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                    )),
            Text(metric.title, style: _small),
            const SizedBox(height: 13),
            const Divider(height: 1, color: AppColors.hairline),
            for (final other
                in _Metric.values.where((other) => other != metric))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '${other.title} · ${switch (other.value(selection)) {
                    final number? => other.format(number),
                    null => '—'
                  }}',
                  style: _small,
                ),
              ),
            const SizedBox(height: 15),
            if (future)
              const Text('Reporting begins once this day arrives.',
                  style: _small)
            else
              OutlinedButton.icon(
                onPressed: onReport,
                icon: const Icon(Icons.arrow_outward_rounded, size: 15),
                style: _compactButton,
                label: const Text('View Full Report'),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeatSwatch extends StatelessWidget {
  const _HeatSwatch({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: AppColors.hairline),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 10.5)),
        ],
      );
}
