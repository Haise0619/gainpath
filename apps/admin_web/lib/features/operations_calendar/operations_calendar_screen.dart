import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:kalender/kalender.dart';
// The compact IANA dataset omits the Kuala Lumpur link.
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import 'operations_calendar_data.dart';

part 'operations_calendar_widgets.dart';

final _malaysia = (() {
  timezone_data.initializeTimeZones();
  return tz.getLocation('Asia/Kuala_Lumpur');
})();
const _day = Duration(days: 1);

DateTime _civil(DateTime date) => DateTime.utc(date.year, date.month, date.day);
DateTime _month(DateTime date) => DateTime.utc(date.year, date.month);
DateTime _moveMonth(DateTime date, int by) {
  final last = DateTime.utc(date.year, date.month + by + 1, 0).day;
  return DateTime.utc(date.year, date.month + by, date.day.clamp(1, last));
}

DateTime _inMalaysia(DateTime instant) =>
    tz.TZDateTime.from(instant, _malaysia);
DateTime _instant(DateTime civil) =>
    tz.TZDateTime(_malaysia, civil.year, civil.month, civil.day).toUtc();
String _dateKey(DateTime date) =>
    _civil(date).toIso8601String().substring(0, 10);

enum _CalendarView { month, week, day }

enum _EventFilter {
  booking,
  availability,
  announcement,
  groupClass,
  inactiveBookings
}

typedef _CalendarRange = ({DateTime start, DateTime end});
typedef _EventScope = ({_CalendarRange range, String? branch, int types});
typedef _InsightScope = ({_CalendarRange range, String? branch});

/// Read-only access to the calendar of the active admin organization.
class OperationsCalendarScreen extends StatefulWidget {
  const OperationsCalendarScreen({
    super.key,
    required this.repository,
    this.initialBranchId,
    this.groupClassesRevision = 0,
    required this.onOpenSource,
    required this.onOpenCoach,
    required this.onOpenReport,
    this.clock,
  });

  final OperationsCalendarRepository repository;
  final String? initialBranchId;
  final int groupClassesRevision;
  final ValueChanged<OperationsEvent> onOpenSource;
  final ValueChanged<OperationsEvent> onOpenCoach;
  final void Function(String? branchId, DateTime date) onOpenReport;
  final DateTime Function()? clock;

  @override
  State<OperationsCalendarScreen> createState() =>
      _OperationsCalendarScreenState();
}

class _OperationsCalendarScreenState extends State<OperationsCalendarScreen> {
  final _scaffold = GlobalKey<ScaffoldState>();
  final _eventController = DefaultEventsController();
  final _calendarScroll = ScrollController();
  final _eventCache = _RangeCache<_EventScope, CalendarEventsResult>();
  final _insightCache = _RangeCache<_InsightScope, CalendarInsightsResult>();
  final _enabled = CalendarEventType.values.toSet();
  late final KalenderController _calendar;
  late DateTime _selected;
  late _CalendarRange _scheduleRange;
  late String? _branchId = widget.initialBranchId;
  _CalendarView _view = _CalendarView.month;
  _Metric _metric = _Metric.visits;
  var _insights = false;
  var _includeInactiveBookings = false;

  List<CalendarBranch>? _branches;
  bool _branchError = false;
  int _branchGeneration = 0;
  Timer? _pendingLoad;
  int _generation = 0;
  bool _loading = true;
  CalendarEventsResult? _events;
  List<OperationsEvent> _shownEvents = const [];
  CalendarInsightsResult? _insightDays;
  OperationsEvent? _openedEvent;
  bool _showAgenda = false;

  DateTime _now() => _inMalaysia((widget.clock ?? DateTime.now)());
  DateTime get _today => _civil(_now());
  _CalendarRange get _visibleRange {
    final range = _calendar.visibleDateTimeRange.value;
    return (start: range.start.toUtc(), end: range.end.toUtc());
  }

  DateTime get _scheduleMonth => _month(_inMalaysia(_scheduleRange.start).add(
        Duration(days: _view == _CalendarView.month ? 14 : 0),
      ));
  DateTime get _focusedMonth => _insights ? _month(_selected) : _scheduleMonth;

  @override
  void initState() {
    super.initState();
    _selected = _today;
    _createCalendar();
    unawaited(_loadBranches());
    _queueLoad();
  }

  void _createCalendar() {
    _calendar = KalenderController(
      viewConfiguration: _configuration(_CalendarView.month),
      location: _malaysia,
    );
    _scheduleRange = _visibleRange;
    _calendar.selectDate(_instant(_selected));
    _calendar.visibleDateTimeRange.addListener(_onCalendarRangeChanged);
  }

  ViewConfiguration _configuration(_CalendarView view) {
    FloatingDateTime selectedDate(ViewTransitionContext _) =>
        FloatingDateTime(_selected.year, _selected.month, _selected.day);
    const morning = KalenderTime(hour: 8, minute: 0);
    return switch (view) {
      _CalendarView.month => MonthViewConfiguration.singleMonth(
          initialDateTime: _instant(_selected),
          firstDayOfWeek: DateTime.monday,
          dateResolver: selectedDate,
          nowCallback: _now,
        ),
      _CalendarView.week => MultiDayViewConfiguration.week(
          firstDayOfWeek: DateTime.monday,
          initialTimeOfDay: morning,
          initialHeightPerMinute: 1.05,
          dateResolver: selectedDate,
          nowCallback: _now,
        ),
      _CalendarView.day => MultiDayViewConfiguration.singleDay(
          initialTimeOfDay: morning,
          initialHeightPerMinute: 1.15,
          dateResolver: selectedDate,
          nowCallback: _now,
        ),
    };
  }

  @override
  void didUpdateWidget(covariant OperationsCalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _eventCache.clear();
      _insightCache.clear();
      _branches = null;
      unawaited(_loadBranches());
    }
    if (oldWidget.groupClassesRevision != widget.groupClassesRevision) {
      _eventCache.clear();
    }
    if (oldWidget.initialBranchId != widget.initialBranchId) {
      _branchId = widget.initialBranchId;
    }
    if (oldWidget.repository != widget.repository ||
        oldWidget.groupClassesRevision != widget.groupClassesRevision ||
        oldWidget.initialBranchId != widget.initialBranchId) {
      _queueLoad();
    }
  }

  @override
  void dispose() {
    _pendingLoad?.cancel();
    _calendar.visibleDateTimeRange.removeListener(_onCalendarRangeChanged);
    _calendar.dispose();
    _eventController.dispose();
    _calendarScroll.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    final generation = ++_branchGeneration;
    try {
      final branches = await widget.repository.loadBranches();
      if (!mounted || generation != _branchGeneration) return;
      final sorted = [...branches]..sort((a, b) {
          if (a.active != b.active) return a.active ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      setState(() {
        _branchError = false;
        _branches = sorted;
      });
    } catch (_) {
      if (mounted && generation == _branchGeneration) {
        setState(() => _branchError = true);
      }
    }
  }

  void _onCalendarRangeChanged() {
    // Kalender can publish a range as its PageView attaches in a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _insights || _visibleRange == _scheduleRange) return;
      setState(() {
        _scheduleRange = _visibleRange;
        final selected = _instant(_selected);
        if (selected.isBefore(_scheduleRange.start) ||
            !selected.isBefore(_scheduleRange.end)) {
          _selected = _view == _CalendarView.month
              ? _scheduleMonth
              : _civil(_inMalaysia(_scheduleRange.start));
        }
      });
      _calendar.selectDate(_instant(_selected));
      _queueLoad();
    });
  }

  void _queueLoad({bool force = false}) {
    _pendingLoad?.cancel();
    final generation = ++_generation;
    if (_insights) {
      final month = _month(_selected);
      final scope = (
        range: (start: _instant(month), end: _instant(_moveMonth(month, 1))),
        branch: _branchId,
      );
      final cached = force ? null : _insightCache.read(scope);
      setState(() {
        _insightDays = cached;
        _loading = cached == null;
      });
      if (cached == null) {
        _pendingLoad = Timer(const Duration(milliseconds: 100),
            () => unawaited(_loadInsights(scope, generation)));
      }
      return;
    }
    final types = Set<CalendarEventType>.unmodifiable(_enabled);
    final scope = (
      range: _scheduleRange,
      branch: _branchId,
      types: types.fold<int>(0, (mask, type) => mask | (1 << type.index)),
    );
    final cached = force ? null : _eventCache.read(scope);
    if (types.isEmpty) {
      _presentEvents(const CalendarEventsResult([], {}), loading: false);
    } else {
      _presentEvents(cached, loading: cached == null);
      if (cached == null) {
        _pendingLoad = Timer(const Duration(milliseconds: 100),
            () => unawaited(_loadEvents(scope, types, generation)));
      }
    }
  }

  Future<void> _loadEvents(
      _EventScope scope, Set<CalendarEventType> types, int generation) async {
    CalendarEventsResult result;
    try {
      result = await widget.repository.loadEvents(
        start: scope.range.start,
        end: scope.range.end,
        types: types,
        branchId: scope.branch,
      );
    } catch (_) {
      result = CalendarEventsResult(const [], types);
    }
    if (!mounted || generation != _generation) return;
    if (result.unavailable.isEmpty) _eventCache.put(scope, result);
    _presentEvents(result, loading: false);
  }

  Future<void> _loadInsights(_InsightScope scope, int generation) async {
    CalendarInsightsResult result;
    try {
      result = await widget.repository.loadInsights(
        start: scope.range.start,
        end: scope.range.end,
        branchId: scope.branch,
      );
    } catch (_) {
      result = CalendarInsightsResult(
        const [],
        _Metric.values.map((metric) => metric.source).toSet(),
      );
    }
    if (!mounted || generation != _generation) return;
    if (result.unavailable.isEmpty) _insightCache.put(scope, result);
    setState(() {
      _loading = false;
      _insightDays = result;
    });
  }

  void _presentEvents(CalendarEventsResult? result, {required bool loading}) {
    final deduplicated = <String, OperationsEvent>{};
    for (final event in result?.events ?? const <OperationsEvent>[]) {
      if (event.end.isAfter(event.start) &&
          (_includeInactiveBookings || !_excludedBooking(event))) {
        deduplicated[event.id] = event;
      }
    }
    final events = deduplicated.values.toList()..sort(_compareEvents);
    _eventController
        .replaceEvents(events.map(_KalenderOperationsEvent.new).toList());
    setState(() {
      _events = result;
      _shownEvents = events;
      _loading = loading;
    });
  }

  bool _excludedBooking(OperationsEvent e) =>
      e.type == CalendarEventType.booking &&
      (e.status == 'cancelled' || e.status == 'expired');

  List<OperationsEvent> _agenda(DateTime date) {
    final start = _instant(date);
    final end = _instant(date.add(_day));
    return _shownEvents
        .where((e) => e.start.isBefore(end) && e.end.isAfter(start))
        .toList();
  }

  void _selectDate(DateTime date, {bool navigate = false}) {
    date = _civil(date);
    final changedMonth = _month(date) != _month(_selected);
    setState(() => _selected = date);
    if (_insights) {
      if (changedMonth) _queueLoad();
      return;
    }
    final target = _instant(date);
    _calendar.selectDate(target);
    final outsideRange = target.isBefore(_scheduleRange.start) ||
        !target.isBefore(_scheduleRange.end);
    if (navigate || outsideRange) {
      _calendar.jumpToDate(target);
    }
  }

  void _changeView(_CalendarView view) {
    if (view == _view) return;
    setState(() => _view = view);
    final previousRange = _scheduleRange;
    _calendar.viewConfiguration = _configuration(view);
    if (previousRange == _visibleRange) _queueLoad();
  }

  void _switchMode(bool insights) {
    if (_insights == insights) return;
    setState(() => _insights = insights);
    if (!insights) {
      _calendar.selectDate(_instant(_selected));
      final chosen = _instant(_selected);
      if (chosen.isBefore(_scheduleRange.start) ||
          !chosen.isBefore(_scheduleRange.end) ||
          (_view == _CalendarView.month &&
              _month(_selected) != _scheduleMonth)) {
        _calendar.jumpToDate(chosen);
        _scheduleRange = _visibleRange;
      }
    }
    _queueLoad();
  }

  void _step(int direction) {
    final base = !_insights &&
            _view == _CalendarView.month &&
            _month(_selected) != _scheduleMonth
        ? _scheduleMonth
        : _selected;
    final date = _insights || _view == _CalendarView.month
        ? _moveMonth(base, direction)
        : base.add(
            Duration(days: direction * (_view == _CalendarView.week ? 7 : 1)));
    _selectDate(date, navigate: true);
  }

  void _refresh() {
    _eventCache.clear();
    _insightCache.clear();
    unawaited(_loadBranches());
    _queueLoad(force: true);
  }

  String _branchName(String? id) {
    if (id == null) return 'All branches';
    for (final branch in _branches ?? const <CalendarBranch>[]) {
      if (id == branch.id) return branch.name;
    }
    return 'Branch unavailable';
  }

  String _eventBranch(OperationsEvent event) {
    if (event.branchId != null) return _branchName(event.branchId);
    if (event.type != CalendarEventType.announcement) {
      return 'Branch unavailable';
    }
    if (event.branchIds.isEmpty) return 'All branches';
    return event.branchIds.map(_branchName).toSet().join(', ');
  }

  void _openEvent(OperationsEvent event) {
    setState(() {
      _showAgenda = false;
      _openedEvent = event;
    });
    _scaffold.currentState?.openEndDrawer();
  }

  void _openAgenda(DateTime date) {
    _selectDate(date);
    setState(() {
      _openedEvent = null;
      _showAgenda = true;
    });
    _scaffold.currentState?.openEndDrawer();
  }

  Widget _eventTile(
      BuildContext context, KalenderEvent event, KalenderDateTimeRange range,
      {bool timeline = false}) {
    final source = (event as _KalenderOperationsEvent).data;
    return _EventTile(
      event: source,
      timeline: timeline,
      branch: _eventBranch(source),
      showBranch: _branchId == null,
      onTap: () => _openEvent(source),
    );
  }

  Widget _calendarView({required bool compact}) {
    final horizontalTiles = TileComponents(tileBuilder: _eventTile);
    final timedTiles = TileComponents(
      tileBuilder: (context, event, range) =>
          _eventTile(context, event, range, timeline: true),
    );
    void inspectDate(DateTime date) {
      if (compact && _view == _CalendarView.month) {
        _openAgenda(date);
      } else {
        _selectDate(date);
      }
    }

    return KalenderTheme(
      data: KalenderThemeData(
        monthGridStyle:
            const MonthGridStyle(color: AppColors.hairline, thickness: 0),
        dayCellStyle: DayCellStyle(
          selectedColor: _view == _CalendarView.day
              ? Colors.transparent
              : const Color(0xfff7f2ff),
        ),
        daySeparatorStyle:
            const DaySeparatorStyle(color: AppColors.hairline, width: 1),
        hourLinesStyle:
            const HourLinesStyle(color: AppColors.hairline, thickness: .65),
        weekDayHeaderStyle: const WeekDayHeaderStyle(
          padding: EdgeInsets.symmetric(vertical: 10),
          textStyle: TextStyle(
              color: AppColors.inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: .55),
        ),
        timelineStyle: const TimelineStyle(
          textStyle: TextStyle(color: AppColors.inkSoft, fontSize: 11),
        ),
      ),
      child: KalenderView(
        locale: const Locale('en', 'US'),
        eventsController: _eventController,
        kalenderController: _calendar,
        interaction: KalenderInteraction(
          allowResizing: false,
          allowRescheduling: false,
          allowEventCreation: false,
        ),
        callbacks: KalenderCallbacks(onTapped: inspectDate),
        components: KalenderComponents(
          monthComponents: MonthComponents(
            headerComponents: MonthHeaderComponents(
              weekDayHeaderStringBuilder: (context, date) =>
                  _weekdays[date.weekday - 1],
            ),
            bodyComponents: MonthBodyComponents(
              monthDayHeaderBuilder: (context, date) =>
                  _calendarDate(date, month: true, onTap: inspectDate),
              monthDayCellBuilder: (context, details) => ColoredBox(
                color: details.isSelected
                    ? const Color(0xfff7f2ff)
                    : details.isInFocusedMonth
                        ? AppColors.surface
                        : const Color(0xfffaf9fd),
              ),
            ),
          ),
          multiDayComponents: MultiDayComponents(
            headerComponents: MultiDayHeaderComponents(
              dayHeaderBuilder: (context, date) =>
                  _calendarDate(date, month: false, onTap: inspectDate),
            ),
            bodyComponents:
                MultiDayBodyComponents(timelineWidth: (context, range) => 60),
          ),
          overlayBuilders: OverlayBuilders(
            multiDayOverlayPortalBuilder: (
              context, {
              required date,
              required events,
              required numberOfHiddenRows,
              required tileHeight,
              required overlayBuilders,
            }) =>
                Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => _openAgenda(date),
                borderRadius: BorderRadius.circular(4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('+$numberOfHiddenRows more',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark)),
                  ),
                ),
              ),
            ),
          ),
        ),
        views: [
          MonthViewParts(
            body: MonthBody(
              configuration: const MonthBodyConfiguration(
                tileHeight: 22,
                eventPadding: EdgeInsets.fromLTRB(4, 1, 4, 1),
              ),
              tileComponents: horizontalTiles,
            ),
          ),
          MultiDayViewParts(
            header: MultiDayHeader(
              configuration: const MultiDayHeaderConfiguration(
                tileHeight: 25,
                maximumNumberOfVerticalEvents: 2,
                eventPadding: EdgeInsets.fromLTRB(4, 1, 4, 1),
              ),
              tileComponents: horizontalTiles,
            ),
            body: MultiDayBody(
              configuration: const MultiDayBodyConfiguration(
                  eventLayoutStrategy: EventLayoutStrategy.sideBySide()),
              tileComponents: timedTiles,
            ),
          ),
        ],
      ),
    );
  }

  Widget _calendarDate(
    DateTime date, {
    required bool month,
    required ValueChanged<DateTime> onTap,
  }) {
    final civil = _civil(date);
    final isSelected = civil == _selected;
    final isToday = civil == _today;
    final isAdjacent = month && _month(civil) != _scheduleMonth;
    final local = MaterialLocalizations.of(context);
    return Tooltip(
      message: local.formatFullDate(date),
      child: InkWell(
        key: ValueKey('calendar-day-${_dateKey(date)}'),
        onTap: () => onTap(date),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: EdgeInsets.fromLTRB(6, month ? 2 : 7, 6, 2),
          child: Row(
            mainAxisAlignment:
                month ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              if (!month) ...[
                Flexible(
                    child: Text(_weekdays[date.weekday - 1],
                        style: _small,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 5),
              ],
              _DateNumber(
                date: date.day,
                selected: isSelected,
                today: isToday,
                adjacent: isAdjacent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar() {
    final branchItems = [
      const PopupMenuItem<String?>(value: '', child: Text('All branches')),
      for (final b in _branches ?? const <CalendarBranch>[])
        PopupMenuItem<String?>(
          value: b.id,
          child: Text(b.active ? b.name : '${b.name} (Inactive)'),
        ),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _ModeSwitch(insights: _insights, onChanged: _switchMode),
        _CalendarMenu<String?>(
          icon: Icons.location_on_outlined,
          label: _branchName(_branchId),
          tooltip: 'Branch filter',
          items: branchItems,
          onSelected: (value) {
            final next = value == '' ? null : value;
            if (next == _branchId) return;
            setState(() => _branchId = next);
            _queueLoad();
          },
        ),
        if (_insights)
          _CalendarMenu<_Metric>(
            icon: Icons.insights_rounded,
            label: _metric.title,
            tooltip: 'Heatmap metric',
            items: [
              for (final metric in _Metric.values)
                CheckedPopupMenuItem(
                    value: metric,
                    checked: _metric == metric,
                    child: Text(metric.title))
            ],
            onSelected: (value) => setState(() => _metric = value),
          )
        else ...[
          _CalendarMenu<_EventFilter>(
            icon: Icons.filter_list_rounded,
            label: _enabled.length == CalendarEventType.values.length
                ? 'All event types'
                : 'Event types (${_enabled.length})',
            tooltip: 'Event filters',
            items: [
              for (final type in CalendarEventType.values)
                CheckedPopupMenuItem(
                  value: _EventFilter.values[type.index],
                  checked: _enabled.contains(type),
                  child: Text(type.plural),
                ),
              CheckedPopupMenuItem(
                value: _EventFilter.inactiveBookings,
                checked: _includeInactiveBookings,
                child: const Text('Include cancelled and expired'),
              ),
            ],
            onSelected: (value) {
              if (value == _EventFilter.inactiveBookings) {
                _includeInactiveBookings = !_includeInactiveBookings;
                _presentEvents(_events, loading: _loading);
              } else {
                final type = CalendarEventType.values[value.index];
                setState(() {
                  if (!_enabled.remove(type)) _enabled.add(type);
                });
                _queueLoad();
              }
            },
          ),
          _CalendarMenu<_CalendarView>(
            icon: Icons.calendar_view_month_outlined,
            label: _statusLabel(_view.name),
            tooltip: 'Calendar view',
            items: [
              for (final view in _CalendarView.values)
                CheckedPopupMenuItem(
                  value: view,
                  checked: _view == view,
                  child: Text(_statusLabel(view.name)),
                )
            ],
            onSelected: _changeView,
          ),
        ],
      ],
    );
  }

  String _periodTitle(BuildContext context) {
    final local = MaterialLocalizations.of(context);
    if (_insights || _view == _CalendarView.month) {
      return local.formatMonthYear(_focusedMonth);
    }
    if (_view == _CalendarView.day) return local.formatFullDate(_selected);
    final start = _civil(_inMalaysia(_scheduleRange.start));
    final end = _civil(_inMalaysia(_scheduleRange.end)).subtract(_day);
    return start.year == end.year
        ? '${local.formatShortMonthDay(start)} – ${local.formatShortMonthDay(end)}, ${end.year}'
        : '${local.formatShortDate(start)} – ${local.formatShortDate(end)}';
  }

  Widget _navigation(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(15, 6, 12, 6),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(_periodTitle(context),
                style: Theme.of(context).textTheme.titleLarge),
            Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  style: _compactButton,
                  onPressed: () => _selectDate(_today, navigate: true),
                  child: const Text('Today', style: TextStyle(fontSize: 13)),
                ),
                IconButton(
                  onPressed: () => _step(-1),
                  tooltip: 'Previous period',
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  onPressed: () => _step(1),
                  tooltip: 'Next period',
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                if (!_insights)
                  IconButton(
                    tooltip: 'Daily agenda',
                    onPressed: () => _openAgenda(_selected),
                    icon: const Icon(Icons.view_agenda_outlined, size: 19),
                  ),
                IconButton(
                  tooltip: 'Refresh calendar',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _scheduleCard(double height, {required bool compact}) => _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _navigation(context),
            const Divider(height: 1, color: AppColors.hairline),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            LayoutBuilder(builder: (context, constraints) {
              final calendar = SizedBox(
                  height: height, child: _calendarView(compact: compact));
              if (_view != _CalendarView.week || constraints.maxWidth >= 590) {
                return calendar;
              }
              return Scrollbar(
                controller: _calendarScroll,
                thumbVisibility: true,
                notificationPredicate: (notice) =>
                    notice.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _calendarScroll,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: 590, child: calendar),
                ),
              );
            }),
            const Divider(height: 1, color: AppColors.hairline),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              child: Text(
                _loading
                    ? 'Loading schedule…'
                    : _enabled.isEmpty
                        ? 'Select an event type to show activities.'
                        : '${_shownEvents.length} ${_shownEvents.length == 1 ? 'event' : 'events'} in view',
                style: _small,
              ),
            ),
          ],
        ),
      );

  Widget _agendaCard() => _Surface(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: _Agenda(
            date: _selected,
            today: _selected == _today,
            events: _agenda(_selected),
            loading: _loading,
            expanded: false,
            incomplete: _events?.unavailable.isNotEmpty ?? false,
            branch: _eventBranch,
            onOpenEvent: _openEvent,
            onOpenAll: () => _openAgenda(_selected),
          ),
        ),
      );

  Widget _rail() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Surface(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: _MiniCalendar(
              month: _scheduleMonth,
              today: _today,
              selected: _selected,
              onSelected: (date) =>
                  _selectDate(date, navigate: _month(date) != _scheduleMonth),
            ),
          )),
          const SizedBox(height: 12),
          _agendaCard(),
          const SizedBox(height: 12),
          const _Legend(),
        ],
      );

  Widget _insightsCard() => _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _navigation(context),
            const Divider(height: 1, color: AppColors.hairline),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            _Heatmap(
              month: _focusedMonth,
              metric: _metric,
              selected: _selected,
              today: _today,
              branch: _branchName(_branchId),
              loading: _loading,
              daily: _insightDays?.daily ?? const [],
              onSelect: _selectDate,
              onReport: () => widget.onOpenReport(_branchId, _selected),
            ),
          ],
        ),
      );

  Iterable<Widget> _feedback() sync* {
    if (_branchError) {
      yield _Feedback('The branch directory could not load.',
          retry: _loadBranches);
    } else if (_branches?.isEmpty ?? false) {
      yield const _Feedback('No branches are available in the directory.');
    }
    if (_insights) {
      final unavailable = _insightDays?.unavailable ?? const <String>{};
      if (unavailable.isNotEmpty) {
        final labels = _Metric.values
            .where((metric) => unavailable.contains(metric.source))
            .map((metric) => metric.title);
        yield _Feedback('${labels.join(', ')} could not load.',
            retry: _refresh);
      }
    } else {
      final unavailable = _events?.unavailable ?? const <CalendarEventType>{};
      if (unavailable.isNotEmpty) {
        final labels = CalendarEventType.values
            .where(unavailable.contains)
            .map((type) => type.plural.toLowerCase())
            .join(', ');
        yield _Feedback('${_statusLabel(labels)} could not load.',
            retry: _refresh);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        key: _scaffold,
        backgroundColor: AppColors.bg,
        endDrawer: _CalendarDrawer(
          onClose: () => _scaffold.currentState?.closeEndDrawer(),
          child: switch (_openedEvent) {
            final event? => _EventDetails(
                event: event,
                branch: _eventBranch(event),
                onSource: () {
                  _scaffold.currentState?.closeEndDrawer();
                  widget.onOpenSource(event);
                },
                onCoach: () {
                  _scaffold.currentState?.closeEndDrawer();
                  widget.onOpenCoach(event);
                },
              ),
            null => _showAgenda
                ? _Agenda(
                    date: _selected,
                    today: _selected == _today,
                    events: _agenda(_selected),
                    loading: _loading,
                    expanded: true,
                    incomplete: _events?.unavailable.isNotEmpty ?? false,
                    branch: _eventBranch,
                    onOpenEvent: _openEvent,
                  )
                : const SizedBox.shrink(),
          },
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final showRail = constraints.maxWidth >= 1040;
            final margin = constraints.maxWidth < 540 ? 12.0 : 22.0;
            final calendarHeight = _view == _CalendarView.month
                ? (constraints.maxHeight - 280).clamp(475.0, 620.0)
                : (constraints.maxHeight - 290).clamp(400.0, 610.0);
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(margin, 21, margin, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PageTitle(insights: _insights),
                  const SizedBox(height: 16),
                  _toolbar(),
                  const SizedBox(height: 14),
                  ..._feedback(),
                  if (_insights)
                    _insightsCard()
                  else if (showRail)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 236, child: _rail()),
                        const SizedBox(width: 14),
                        Expanded(
                            child:
                                _scheduleCard(calendarHeight, compact: false)),
                      ],
                    )
                  else ...[
                    _scheduleCard(calendarHeight, compact: true),
                    const SizedBox(height: 12),
                    _agendaCard(),
                    const SizedBox(height: 12),
                    const _Legend(),
                  ],
                ],
              ),
            );
          },
        ),
      );
}

class _KalenderOperationsEvent extends KalenderEvent {
  _KalenderOperationsEvent(this.data, {DateTime? start, DateTime? end})
      : super(
          id: data.id,
          start: start ?? data.start,
          end: end ?? data.end,
          isAllDay: data.allDay,
          interaction: EventInteraction.allowNone(),
          multiDayRule: data.type == CalendarEventType.announcement
              ? const MultiDayRule.calendarDays()
              : null,
        );

  final OperationsEvent data;

  @override
  KalenderEvent copyWithData(
          {required DateTime start, required DateTime end}) =>
      _KalenderOperationsEvent(data, start: start, end: end);
}

class _RangeCache<K, V> {
  final _entries = <K, ({DateTime expires, V value})>{};

  V? read(K key) {
    final entry = _entries.remove(key);
    if (entry == null || !entry.expires.isAfter(DateTime.now())) return null;
    _entries[key] = entry;
    return entry.value;
  }

  void put(K key, V value) {
    _entries.remove(key);
    if (_entries.length == 10) _entries.remove(_entries.keys.first);
    _entries[key] = (
      expires: DateTime.now().add(const Duration(seconds: 30)),
      value: value
    );
  }

  void clear() => _entries.clear();
}
