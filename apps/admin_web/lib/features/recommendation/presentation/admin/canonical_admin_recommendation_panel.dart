import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'recommendation_monitor.dart';
import '../../application/canonical_admin_recommendation_repository.dart';
import '../../application/recommendation_queue.dart' show malaysiaTime;

part 'recommendation_details_drawer.dart';

class CanonicalAdminRecommendationPanel extends StatefulWidget {
  const CanonicalAdminRecommendationPanel(
      {super.key,
      required this.repository,
      this.tab,
      this.clock,
      this.relatedLinks = const {}});
  final CanonicalAdminRecommendationRepository repository;
  final RecommendationMonitorTab? tab;
  final DateTime Function()? clock;
  final Map<String, VoidCallback> relatedLinks;
  @override
  State<CanonicalAdminRecommendationPanel> createState() =>
      _CanonicalAdminRecommendationPanelState();
}

class _CanonicalAdminRecommendationPanelState
    extends State<CanonicalAdminRecommendationPanel> {
  final _records = <CanonicalAdminRecommendation>[];
  final _searchController = TextEditingController();
  DialogRoute<bool>? _detailsRoute;
  String _search = '', _kind = 'all', _status = 'all';
  String _date = 'all', _source = 'all';
  DateTimeRange? _dates;
  int _sortColumn = 7;
  int _filterRevision = 0;
  bool _ascending = false;
  String? _next, _error;
  bool _loading = false, _working = false;
  int _generation = 0, _reviewEpoch = 0;
  bool _active = true;
  DateTime get _now => (widget.clock ?? DateTime.now)().toUtc();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CanonicalAdminRecommendationPanel old) {
    super.didUpdateWidget(old);
    if (!identical(old.repository, widget.repository)) {
      _dismissDetails();
      _working = false;
      _records.clear();
      _next = null;
      _load();
    }
  }

  bool _current(CanonicalAdminRecommendationRepository repo, int generation) =>
      mounted &&
      identical(repo, widget.repository) &&
      generation == _generation &&
      repo.isCurrent;
  void _lost() {
    if (!mounted) {
      return;
    }
    setState(() {
      _records.clear();
      _next = null;
      _loading = false;
      _working = false;
      _error = 'Your Admin session changed. Reopen Recommendations.';
    });
  }

  Future<void> _load({bool append = false}) async {
    final repo = widget.repository, generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await repo.list(afterId: append ? _next : null);
      if (!_current(repo, generation)) {
        if (mounted && identical(repo, widget.repository) && !repo.isCurrent) {
          _lost();
        }
        return;
      }
      if (append &&
          page.records.any((r) => _records.any((old) => old.id == r.id))) {
        throw const FormatException('Repeated queue page.');
      }
      setState(() {
        if (!append) _records.clear();
        _records.addAll(page.records);
        _next = page.nextAfterId;
        _loading = false;
      });
    } catch (_) {
      if (!mounted ||
          !identical(repo, widget.repository) ||
          generation != _generation) {
        return;
      }
      if (!repo.isCurrent) {
        _lost();
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Recommendations could not be verified. Retry.';
      });
    }
  }

  String _label(CanonicalAdminRecommendation r) =>
      ['pending', 'prepared'].contains(r.status) && !r.expiresAt.isAfter(_now)
          ? 'Expired'
          : const {
              'pending': 'Awaiting delivery',
              'prepared': 'Delivery unverified',
              'delivered': 'Delivered',
              'dismissed': 'Dismissed',
              'withdrawn': 'Withdrawn / no longer eligible'
            }[r.status]!;

  bool _issue(CanonicalAdminRecommendation r) => const [
        'Delivery unverified',
        'Expired',
        'Withdrawn / no longer eligible'
      ].contains(_label(r));

  String _contextLabel(CanonicalAdminRecommendation record) => [
        record.exerciseLabel,
        ...record.ai?.fitnessGoals ?? const <String>[],
      ].join(' · ');

  bool _matchesDate(CanonicalAdminRecommendation r) {
    if (_date == 'all') return true;
    final local = _now.add(const Duration(hours: 8));
    final end = _dates?.end ?? DateTime(local.year, local.month, local.day);
    final start =
        _dates?.start ?? end.subtract(Duration(days: int.parse(_date) - 1));
    final first = DateTime.utc(start.year, start.month, start.day)
        .subtract(const Duration(hours: 8));
    final last = DateTime.utc(end.year, end.month, end.day)
        .add(const Duration(hours: 16));
    return !r.createdAt.isBefore(first) && r.createdAt.isBefore(last);
  }

  Future<void> _calendar() async {
    final local = _now.add(const Duration(hours: 8));
    final range = await showDateRangePicker(
        context: context,
        initialDateRange: _dates,
        firstDate: DateTime(2020),
        lastDate: DateTime(local.year, local.month, local.day),
        helpText: 'Malaysia dates · maximum 90 days');
    if (!mounted) return;
    setState(() => _filterRevision++);
    if (range == null) return;
    if (range.end.difference(range.start).inDays > 89) {
      setState(() => _error = 'Choose a range of at most 90 days.');
      return;
    }
    setState(() {
      _date = 'custom';
      _dates = range;
      _error = null;
    });
  }

  int _compare(CanonicalAdminRecommendation a, CanonicalAdminRecommendation b) {
    final result = switch (_sortColumn) {
      0 => (a.memberLabel ?? a.memberId).compareTo(b.memberLabel ?? b.memberId),
      1 => a.typeLabel.compareTo(b.typeLabel),
      2 => _contextLabel(a).compareTo(_contextLabel(b)),
      3 => a.targetLabel.compareTo(b.targetLabel),
      5 => a.aiMethodLabel.compareTo(b.aiMethodLabel),
      6 => _label(a).compareTo(_label(b)),
      _ => a.createdAt.compareTo(b.createdAt),
    };
    final stable = result == 0 ? a.id.compareTo(b.id) : result;
    return _ascending ? stable : -stable;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = RecommendationMonitorActivity.of(context);
    if (_active && !active) {
      _reviewEpoch++;
      _working = false;
      _dismissDetails();
    }
    _active = active;
  }

  void _dismissDetails() {
    final route = _detailsRoute;
    _detailsRoute = null;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = route.navigator;
      if (navigator?.mounted == true && route.isActive) {
        navigator!.removeRoute(route);
      }
    });
  }

  @override
  void dispose() {
    _dismissDetails();
    _searchController.dispose();
    super.dispose();
  }

  Future<bool> _review(CanonicalAdminRecommendation cached) async {
    if (!_active || _working || _loading || _detailsRoute != null) return false;
    final repo = widget.repository,
        generation = _generation,
        epoch = _reviewEpoch;
    bool reviewCurrent() =>
        _active && epoch == _reviewEpoch && _current(repo, generation);
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final record = await repo.detail(cached);
      if (!reviewCurrent()) {
        if (mounted && identical(repo, widget.repository) && !repo.isCurrent) {
          _lost();
        }
        return false;
      }
      final navigator = Navigator.of(context);
      final route = DialogRoute<bool>(
        context: context,
        barrierColor: const Color(0x55312644),
        builder: (_) => reviewCurrent()
            ? _RecommendationDetailsDrawer(
                record: record,
                status: _label(record),
                issue: _issue(record),
                onDeliveryIssues: widget.relatedLinks['Delivery Issues'],
              )
            : const SizedBox.shrink(),
      );
      setState(() {
        _detailsRoute = route;
        _working = false;
      });
      try {
        final navigated = await navigator.push(route);
        return navigated != true && reviewCurrent();
      } finally {
        if (mounted && identical(_detailsRoute, route)) {
          setState(() => _detailsRoute = null);
        }
      }
    } catch (_) {
      if (!reviewCurrent()) {
        if (mounted && identical(repo, widget.repository) && !repo.isCurrent) {
          _lost();
        }
        return false;
      }
      setState(() {
        _working = false;
        _records.clear();
        _next = null;
        _error =
            'Recommendation details could not be verified. Reload records before reviewing again.';
      });
      return false;
    }
  }

  bool get _hasFilters =>
      _search.isNotEmpty ||
      _kind != 'all' ||
      _source != 'all' ||
      _status != 'all' ||
      _date != 'all';

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _kind = _source = _status = _date = 'all';
      _search = '';
      _dates = null;
      _filterRevision++;
    });
  }

  InputDecoration _filterDecoration(String label,
          {Widget? prefix, String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefix,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
      );

  Widget _filter(
          String key,
          String label,
          String value,
          List<(String, String)> choices,
          ValueChanged<String?> changed,
          double width) =>
      SizedBox(
          key: ValueKey('monitor-$key'),
          width: width,
          child: DropdownButtonFormField<String>(
              initialValue: value,
              key: ValueKey('$key-$value-$_filterRevision'),
              isExpanded: true,
              decoration: _filterDecoration(label),
              items: choices
                  .map((choice) => DropdownMenuItem(
                      value: choice.$1, child: Text(choice.$2)))
                  .toList(),
              onChanged: _working || _loading ? null : changed));

  Widget _metrics(List<CanonicalAdminRecommendation> records, double width) {
    final layout = width >= 600 ? (width - 24) / 3 : width;
    final loading = _loading && records.isEmpty;
    final delivered =
        records.where((record) => record.status == 'delivered').length;
    final issues = records.where(_issue).length;
    final values = [
      (
        'Total recommendations',
        records.length,
        Icons.auto_awesome_outlined,
        AppColors.primaryDark
      ),
      (
        'Delivered',
        delivered,
        Icons.mark_email_read_outlined,
        const Color(0xff21734c)
      ),
      (
        'Delivery issues',
        issues,
        Icons.error_outline_rounded,
        const Color(0xff865014)
      ),
    ];
    final types = [
      (
        'Tutorials',
        records.where((r) => r.kind == 'content').length,
        const Color(0xff7041cf)
      ),
      (
        'Coaches',
        records.where((r) => r.kind == 'trainer').length,
        const Color(0xff4280cf)
      ),
      (
        'Routines',
        records.where((r) => r.kind == 'routine').length,
        const Color(0xff598d77)
      ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final value in values)
          SizedBox(
              width: layout,
              child: _surface(
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(value.$1,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                              const SizedBox(height: 5),
                              Text(loading ? '—' : '${value.$2}',
                                  key: ValueKey(
                                      'recommendation-metric-${value.$1}'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.ink)),
                            ])),
                        const SizedBox(width: 8),
                        DecoratedBox(
                          decoration: BoxDecoration(
                              color: value.$4.withValues(alpha: .09),
                              borderRadius: BorderRadius.circular(8)),
                          child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(value.$3, color: value.$4, size: 19)),
                        ),
                      ]),
                ),
              )),
      ]),
      const SizedBox(height: 12),
      _surface(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(
                spacing: 20,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Recommendation types',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.ink, fontWeight: FontWeight.w700)),
                  for (final type in types)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.circle, size: 8, color: type.$3),
                      const SizedBox(width: 6),
                      Text(type.$1),
                      const SizedBox(width: 6),
                      Text(loading ? '—' : '${type.$2}',
                          key: ValueKey('recommendation-metric-${type.$1}'),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                ]),
            if (records.isNotEmpty &&
                types.fold(0, (sum, type) => sum + type.$2) ==
                    records.length) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                    height: 6,
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final type in types)
                            if (type.$2 > 0)
                              Expanded(
                                  flex: type.$2,
                                  child: ColoredBox(color: type.$3)),
                        ])),
              ),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Statistics cover ${records.length} loaded, currently authorized records. Filters apply to the list below.',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.inkSoft),
      ),
    ]);
  }

  Widget _surface(Widget child) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(11),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );

  void _sort(int column, bool ascending) => setState(() {
        _sortColumn = column;
        _ascending = ascending;
      });

  Widget _textCell(String text, {bool strong = false, int lines = 2}) =>
      Tooltip(
        message: text,
        child: Text(text,
            maxLines: lines,
            overflow: TextOverflow.ellipsis,
            style:
                strong ? const TextStyle(fontWeight: FontWeight.w700) : null),
      );

  Widget _detailsAction(CanonicalAdminRecommendation record) =>
      _RecommendationDetailsAction(
        key: ValueKey('recommendation-open-${record.id}'),
        target: record.targetLabel,
        onReview: _working || _loading || _detailsRoute != null
            ? null
            : () => _review(record),
      );

  Widget _typeBadge(CanonicalAdminRecommendation record) =>
      _recommendationBadge(record.typeLabel, AppColors.primaryDark);

  Widget _statusBadge(CanonicalAdminRecommendation record) {
    final status = _label(record);
    return Tooltip(
      message: status,
      child: _recommendationBadge(status, _statusColor(_issue(record), record),
          icon: record.status == 'delivered'
              ? Icons.check_circle_outline_rounded
              : _issue(record)
                  ? Icons.error_outline_rounded
                  : Icons.schedule_rounded),
    );
  }

  Widget _sourceCell(CanonicalAdminRecommendation record) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _textCell(_recommendationSource(record), strong: true, lines: 1),
            _textCell(record.aiMethodLabel, lines: 1),
          ]);

  Widget _table(List<CanonicalAdminRecommendation> visible, double width) {
    final columns = [
      ('Member', .155, 0),
      ('Recommended content', .197, 3),
      ('Type', .095, 1),
      ('Source / AI method', .15, 5),
      ('Delivery status', .17, 6),
      ('Created Date · MYT', .125, 7),
      ('Details', .108, null),
    ];
    final activeColumn =
        columns.indexWhere((column) => column.$3 == _sortColumn);
    return KeyedSubtree(
      key: const ValueKey('recommendation-table'),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerTheme: const DividerThemeData(color: AppColors.hairline),
        ),
        child: DataTable(
          dividerThickness: .8,
          sortColumnIndex: activeColumn < 0 ? null : activeColumn,
          sortAscending: _ascending,
          headingRowColor: const WidgetStatePropertyAll(AppColors.surfaceAlt),
          headingTextStyle: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.inkSoft, fontWeight: FontWeight.w700),
          dataTextStyle: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.ink),
          horizontalMargin: 12,
          columnSpacing: 10,
          headingRowHeight: 49,
          dataRowMinHeight: 63,
          dataRowMaxHeight: 72,
          columns: [
            for (final column in columns)
              DataColumn(
                columnWidth: FixedColumnWidth((width - 2) * column.$2),
                label: Flexible(
                    child: Text(column.$1,
                        maxLines: 2, overflow: TextOverflow.ellipsis)),
                onSort: column.$3 == null
                    ? null
                    : (_, ascending) => _sort(column.$3!, ascending),
              ),
          ],
          rows: [
            for (final record in visible)
              DataRow(
                key: ValueKey(record.id),
                color: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.hovered)
                        ? AppColors.surfaceAlt
                        : null),
                cells: [
                  DataCell(
                      _textCell(_recommendationMember(record), strong: true)),
                  DataCell(Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _textCell(record.targetLabel, strong: true, lines: 1),
                      _textCell(record.exerciseLabel, lines: 1),
                    ],
                  )),
                  DataCell(_typeBadge(record)),
                  DataCell(_sourceCell(record)),
                  DataCell(_statusBadge(record)),
                  DataCell(_textCell(malaysiaTime(record.createdAt))),
                  DataCell(_detailsAction(record)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _card(CanonicalAdminRecommendation record) => Container(
        key: ValueKey(record.id),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 6),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.hairline))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _textCell(record.targetLabel, strong: true),
          const SizedBox(height: 2),
          _textCell(_recommendationMember(record)),
          _textCell(record.exerciseLabel),
          const SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 6, children: [
            _typeBadge(record),
            _statusBadge(record),
          ]),
          const SizedBox(height: 8),
          Text('${_recommendationSource(record)} · ${record.aiMethodLabel}',
              style: Theme.of(context).textTheme.bodySmall),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${malaysiaTime(record.createdAt)} MYT',
                  style: Theme.of(context).textTheme.bodySmall),
              _detailsAction(record),
            ],
          ),
        ]),
      );

  Widget _sortMenu() => PopupMenuButton<int>(
        tooltip: 'Sort recommendations',
        onSelected: (column) =>
            _sort(column, column == _sortColumn ? !_ascending : column != 7),
        itemBuilder: (_) => [
          for (final option in const [
            (7, 'Created date'),
            (0, 'Member'),
            (3, 'Recommended content'),
            (1, 'Type'),
            (2, 'Exercise / Goal'),
            (5, 'AI method'),
            (6, 'Delivery status')
          ])
            PopupMenuItem(value: option.$1, child: Text(option.$2)),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Text(_sortColumn == 7
              ? (_ascending ? 'Oldest first' : 'Newest first')
              : (_ascending ? 'Sort ↑' : 'Sort ↓')),
        ),
      );

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final current = widget.repository.isCurrent;
        if (!current && _detailsRoute != null) _dismissDetails();
        final records = current ? _records : <CanonicalAdminRecommendation>[];
        final tab = widget.tab ?? RecommendationMonitorTab.overview;
        final visible = records
            .where((record) =>
                (tab != RecommendationMonitorTab.attention || _issue(record)) &&
                (_kind == 'all' || record.kind == _kind) &&
                (_source == 'all' ||
                    _recommendationSourceKey(record) == _source) &&
                (_status == 'all' ||
                    (_status == 'expired'
                        ? _label(record) == 'Expired'
                        : record.status == _status)) &&
                _matchesDate(record) &&
                '${record.memberLabel ?? ''} ${record.memberId} ${record.title} ${record.exerciseLabel} ${record.objective} ${record.targetLabel} ${record.summary} ${record.ai?.fitnessGoals.join(' ') ?? ''} ${record.aiMethodLabel}'
                    .toLowerCase()
                    .contains(_search))
            .toList()
          ..sort(_compare);
        final padding = constraints.maxWidth >= 650 ? 28.0 : 14.0;
        final width = constraints.maxWidth - 2 * padding;
        final wide =
            width >= 1030 && MediaQuery.textScalerOf(context).scale(14) < 18;
        final filterWidth = width < 240
            ? width - 26
            : width >= 850
                ? 174.0
                : 198.0;
        final dateLabel = _dates == null
            ? 'Custom dates'
            : '${_dates!.start.toIso8601String().split('T').first} – ${_dates!.end.toIso8601String().split('T').first}';
        return SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (current) ...[
                Text(
                    tab == RecommendationMonitorTab.attention
                        ? 'Delivery Issues'
                        : 'Recommendations Overview',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
                const SizedBox(height: 5),
                Text(
                    tab == RecommendationMonitorTab.attention
                        ? 'Inspect unresolved or ineligible recommendation delivery.'
                        : 'Monitor AI recommendations, delivery outcomes and recommendation sources.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.inkSoft)),
                if (tab == RecommendationMonitorTab.overview &&
                    widget.relatedLinks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 9, runSpacing: 2, children: [
                    for (final link in widget.relatedLinks.entries)
                      TextButton.icon(
                          onPressed: link.value,
                          icon:
                              const Icon(Icons.arrow_outward_rounded, size: 15),
                          label: Text(link.key)),
                  ]),
                ],
                const SizedBox(height: 18),
              ],
              if (!current)
                const Text(
                    'Your Admin session changed. Reopen Recommendations.')
              else if (!_loading && !widget.repository.enabled)
                const Text(
                    'Recommendations are unavailable while evidence, permission and delivery policies await review.')
              else ...[
                _metrics(records, width),
                const SizedBox(height: 21),
                Text(
                    tab == RecommendationMonitorTab.attention
                        ? 'Delivery issues'
                        : 'Recent recommendations',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                _surface(Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                        spacing: 9,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                              width: width < 264 ? width - 26 : 238,
                              child: TextField(
                                  controller: _searchController,
                                  decoration: _filterDecoration('Search',
                                      hint: 'Member or content',
                                      prefix: const Icon(Icons.search_rounded,
                                          size: 18)),
                                  onChanged: (value) => setState(() =>
                                      _search = value.trim().toLowerCase()))),
                          _filter(
                              'type',
                              'Type',
                              _kind,
                              const [
                                ('all', 'All types'),
                                ('routine', 'Routine'),
                                ('content', 'Tutorial'),
                                ('trainer', 'Coach')
                              ],
                              (value) => setState(() => _kind = value ?? 'all'),
                              filterWidth),
                          _filter(
                              'source',
                              'Source',
                              _source,
                              const [
                                ('all', 'All sources'),
                                ('automatic', 'Automatic'),
                                ('admin_outreach', 'Admin Outreach'),
                                ('withheld', 'Withheld'),
                              ],
                              (value) =>
                                  setState(() => _source = value ?? 'all'),
                              filterWidth),
                          _filter(
                              'status',
                              'Status',
                              _status,
                              const [
                                ('all', 'All statuses'),
                                ('pending', 'Awaiting delivery'),
                                ('prepared', 'Delivery unverified'),
                                ('expired', 'Expired before delivery'),
                                ('delivered', 'Delivered'),
                                ('dismissed', 'Dismissed'),
                                ('withdrawn', 'Withdrawn')
                              ],
                              (value) =>
                                  setState(() => _status = value ?? 'all'),
                              filterWidth),
                          _filter('date', 'Created date · MYT', _date, [
                            const ('all', 'All dates'),
                            const ('7', 'Last 7 days'),
                            const ('30', 'Last 30 days'),
                            const ('90', 'Last 90 days'),
                            ('custom', dateLabel)
                          ], (value) {
                            if (value == 'custom') {
                              _calendar();
                            } else {
                              setState(() {
                                _date = value ?? 'all';
                                _dates = null;
                              });
                            }
                          }, filterWidth),
                          OutlinedButton.icon(
                              onPressed:
                                  _loading || _working ? null : () => _load(),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Refresh')),
                          if (_hasFilters)
                            TextButton(
                                onPressed: _resetFilters,
                                child: const Text('Reset filters')),
                        ]))),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text(
                      '${visible.length} shown · ${records.length} records loaded · dates in Malaysia time',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (visible.isNotEmpty) _sortMenu(),
                  ],
                ),
                const SizedBox(height: 5),
                if (_loading || _working)
                  const LinearProgressIndicator(
                      semanticsLabel: 'Loading recommendations'),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Semantics(
                          liveRegion: true,
                          child: Text(_error!,
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.error)))),
                if (!_loading && visible.isEmpty)
                  Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(14)),
                      child: Column(children: [
                        Icon(
                            tab == RecommendationMonitorTab.attention
                                ? Icons.task_alt_rounded
                                : Icons.search_off_rounded,
                            color: AppColors.primary,
                            size: 32),
                        const SizedBox(height: 12),
                        Text(
                            tab == RecommendationMonitorTab.attention
                                ? 'No delivery issues match these filters'
                                : 'No recommendations match these filters.',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        const Text(
                            'Adjust the filters or refresh to check for automatically generated records.',
                            textAlign: TextAlign.center),
                      ])),
                if (visible.isNotEmpty)
                  _surface(wide
                      ? _table(visible, width)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: visible.map(_card).toList())),
                const SizedBox(height: 16),
                if (_next != null)
                  OutlinedButton.icon(
                      onPressed: _working || _loading
                          ? null
                          : () => _load(append: true),
                      icon: const Icon(Icons.expand_more_rounded),
                      label: const Text('Load more')),
              ],
              if (_error != null && !widget.repository.enabled)
                TextButton(
                    onPressed: _loading ? null : () => _load(),
                    child: const Text('Retry')),
            ]));
      });
}
