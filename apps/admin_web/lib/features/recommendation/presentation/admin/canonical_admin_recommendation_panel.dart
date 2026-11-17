import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'recommendation_monitor.dart';
import '../../application/canonical_admin_recommendation_repository.dart';
import '../../application/recommendation_queue.dart' show malaysiaTime;

class CanonicalAdminRecommendationPanel extends StatefulWidget {
  const CanonicalAdminRecommendationPanel(
      {super.key,
      required this.repository,
      this.history = false,
      this.tab,
      this.onUnavailable,
      this.clock});
  final CanonicalAdminRecommendationRepository repository;
  final bool history;
  final RecommendationMonitorTab? tab;
  final VoidCallback? onUnavailable;
  final DateTime Function()? clock;
  @override
  State<CanonicalAdminRecommendationPanel> createState() =>
      _CanonicalAdminRecommendationPanelState();
}

class _CanonicalAdminRecommendationPanelState
    extends State<CanonicalAdminRecommendationPanel> {
  final _records = <CanonicalAdminRecommendation>[];
  String _search = '', _kind = 'all', _status = 'all';
  String _date = 'all';
  DateTimeRange? _dates;
  int _sortColumn = 7;
  int _filterRevision = 0;
  bool _ascending = false;
  String? _next, _error;
  bool _loading = false, _working = false;
  int _generation = 0;
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
      if (!repo.enabled && widget.onUnavailable != null) {
        widget.onUnavailable!();
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

  Future<void> _review(CanonicalAdminRecommendation cached) async {
    if (_working || _loading) {
      return;
    }
    final repo = widget.repository, generation = _generation;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final lead = await repo.detail(cached);
      if (!_current(repo, generation)) {
        _lost();
        return;
      }
      setState(() => _working = false);
      if (!mounted) {
        return;
      }
      await showDialog<void>(
          context: context,
          builder: (ctx) => Dialog(
              alignment: Alignment.centerRight,
              insetPadding: const EdgeInsets.all(12),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _drawerHeader(ctx),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              _badge(lead.typeLabel, AppColors.primary),
                              _badge(lead.aiMethodLabel, AppColors.info),
                              _statusBadge(lead),
                            ]),
                            const SizedBox(height: 16),
                            _detailSection(
                                'Member', lead.memberLabel ?? lead.memberId),
                            _detailSection(
                                'Recommended ${lead.typeLabel.toLowerCase()}',
                                lead.targetLabel),
                            _detailSection(
                                'Exercise / goal', lead.exerciseLabel),
                            _detailSection(
                                'Workout context',
                                lead.ai?.workoutContext ??
                                    lead.evidenceSummary ??
                                    'Workout context was not recorded for this recommendation.'),
                            _detailSection(
                                'Fitness goals',
                                lead.ai?.fitnessGoals.isNotEmpty == true
                                    ? lead.ai!.fitnessGoals.join(' · ')
                                    : 'Fitness goals were not recorded for this recommendation.'),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: AppColors.primaryTint,
                                  borderRadius: BorderRadius.circular(14)),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        lead.ai?.method == 'gemini'
                                            ? 'Gemini personalized reason'
                                            : 'Recommendation reason',
                                        style: Theme.of(ctx)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                color: AppColors.primaryDark)),
                                    const SizedBox(height: 8),
                                    Text(lead.summary,
                                        style:
                                            Theme.of(ctx).textTheme.bodyLarge),
                                  ]),
                            ),
                            if (lead.ai?.factors.isNotEmpty == true) ...[
                              const SizedBox(height: 16),
                              Text('Selection factors',
                                  style: Theme.of(ctx).textTheme.titleMedium),
                              for (final factor in lead.ai!.factors)
                                Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(factor)),
                            ],
                            if (lead.explanations.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text('Supporting context',
                                  style: Theme.of(ctx).textTheme.titleMedium),
                              for (final reason in lead.explanations)
                                Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(reason)),
                            ],
                            const SizedBox(height: 20),
                            _detailSection('AI method', lead.aiMethodLabel),
                            _detailSection('Delivery status', _label(lead)),
                            _detailSection('Created',
                                '${malaysiaTime(lead.createdAt)} MYT'),
                            _detailSection(
                                'Delivered',
                                lead.deliveredAt == null
                                    ? 'Delivery has not been confirmed'
                                    : '${malaysiaTime(lead.deliveredAt!)} MYT'),
                            ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: const Text('Technical Details'),
                                children: [
                                  Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                          'Member account: ${lead.memberId}\nRecord: ${lead.id}\nRevision: ${lead.revision}\nPolicy: ${lead.policyVersion}\nEvidence: ${lead.evidenceFingerprint}\nExpires: ${malaysiaTime(lead.expiresAt)} MYT${lead.ai?.model == null ? '' : '\nModel: ${lead.ai!.model}'}${_aiTechnical(lead)}'))
                                ]),
                            const SizedBox(height: 12),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Close')),
                            ])
                          ])))));
    } catch (_) {
      if (!_current(repo, generation)) {
        _lost();
        return;
      }
      setState(() {
        _working = false;
        _records.clear();
        _next = null;
        _error =
            'Recommendation details could not be verified. Reload records before reviewing again.';
      });
    }
  }

  Widget _detailSection(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.inkSoft)),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ]));

  Widget _drawerHeader(BuildContext context) {
    final title = Text('Recommendation details',
        style: Theme.of(context).textTheme.titleLarge);
    final close = IconButton(
        tooltip: 'Close details',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close_rounded));
    if (MediaQuery.sizeOf(context).width < 600 &&
        MediaQuery.textScalerOf(context).scale(20) > 28) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(alignment: Alignment.centerRight, child: close),
        title,
      ]);
    }
    return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: title), close]);
  }

  String _aiTechnical(CanonicalAdminRecommendation record) {
    final fields = record.ai?.technical ?? const <String, Object?>{};
    const labels = {
      'candidateCount': 'Eligible candidates',
      'latencyMillis': 'AI generation duration (ms)',
      'inputTokens': 'Input tokens',
      'outputTokens': 'Output tokens',
      'changedOrder': 'Changed rule ranking',
      'fallbackReason': 'Fallback reason',
    };
    return fields.entries
        .map((entry) => '\n${labels[entry.key]}: ${entry.value}')
        .join();
  }

  Widget _badge(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600)));

  Widget _statusBadge(CanonicalAdminRecommendation record) => _badge(
      _label(record),
      _issue(record)
          ? AppColors.warning
          : record.status == 'delivered'
              ? AppColors.success
              : AppColors.inkSoft);

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
              decoration: InputDecoration(labelText: label),
              items: choices
                  .map((choice) => DropdownMenuItem(
                      value: choice.$1, child: Text(choice.$2)))
                  .toList(),
              onChanged: _working || _loading ? null : changed));

  Widget _metrics(List<CanonicalAdminRecommendation> records, double width) {
    final columns = width >= 1200
        ? 6
        : width >= 680
            ? 3
            : width >= 260 && MediaQuery.textScalerOf(context).scale(14) < 22
                ? 2
                : 1;
    final cardWidth = (width - (columns - 1) * 12) / columns;
    final values = [
      (
        'Total recommendations',
        records.length,
        Icons.auto_awesome_outlined,
        AppColors.primary
      ),
      (
        'Tutorials',
        records.where((r) => r.kind == 'content').length,
        Icons.play_circle_outline,
        AppColors.info
      ),
      (
        'Coaches',
        records.where((r) => r.kind == 'trainer').length,
        Icons.people_outline_rounded,
        AppColors.primary
      ),
      (
        'Routines',
        records.where((r) => r.kind == 'routine').length,
        Icons.fitness_center_rounded,
        AppColors.primary
      ),
      (
        'Delivered',
        records.where((r) => r.status == 'delivered').length,
        Icons.mark_email_read_outlined,
        AppColors.success
      ),
      (
        'Delivery issues',
        records.where(_issue).length,
        Icons.error_outline_rounded,
        AppColors.warning
      ),
    ];
    return Wrap(spacing: 12, runSpacing: 12, children: [
      for (final value in values)
        Container(
            width: cardWidth,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.hairline)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(value.$3, color: value.$4, size: 22),
              const SizedBox(height: 14),
              Text(_loading && records.isEmpty ? '—' : '${value.$2}',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 2),
              Text(value.$1, style: Theme.of(context).textTheme.bodySmall),
            ])),
    ]);
  }

  void _sort(int column, bool ascending) => setState(() {
        _sortColumn = column;
        _ascending = ascending;
      });

  Widget _cell(String text, double width, {int lines = 2}) => SizedBox(
      width: width,
      child: Tooltip(
          message: text,
          child: Text(text, maxLines: lines, overflow: TextOverflow.ellipsis)));

  Widget _table(List<CanonicalAdminRecommendation> visible) => Container(
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
              sortColumnIndex: _sortColumn,
              sortAscending: _ascending,
              headingRowColor:
                  const WidgetStatePropertyAll(AppColors.surfaceAlt),
              headingTextStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkSoft, fontWeight: FontWeight.w700),
              dataTextStyle: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.ink),
              horizontalMargin: 16,
              columnSpacing: 18,
              dataRowMinHeight: 86,
              dataRowMaxHeight: 100,
              columns: [
                DataColumn(label: _cell('Member', 110), onSort: _sort),
                DataColumn(label: _cell('Type', 80), onSort: _sort),
                DataColumn(label: _cell('Exercise / Goal', 100), onSort: _sort),
                DataColumn(
                    label: _cell('Recommended content', 150), onSort: _sort),
                DataColumn(label: _cell('Reason', 180)),
                DataColumn(label: _cell('AI Method', 110), onSort: _sort),
                DataColumn(label: _cell('Status', 128), onSort: _sort),
                DataColumn(
                    label: _cell('Created Date · MYT', 120), onSort: _sort),
                DataColumn(label: _cell('Details', 60)),
              ],
              rows: [
                for (final record in visible)
                  DataRow(key: ValueKey(record.id), cells: [
                    DataCell(_cell(record.memberLabel ?? record.memberId, 110)),
                    DataCell(SizedBox(
                        width: 80,
                        child: _badge(record.typeLabel, AppColors.primary))),
                    DataCell(_cell(_contextLabel(record), 100)),
                    DataCell(_cell(record.targetLabel, 150)),
                    DataCell(_cell(record.summary, 180, lines: 3)),
                    DataCell(SizedBox(
                        width: 110,
                        child: _badge(record.aiMethodLabel, AppColors.info))),
                    DataCell(SizedBox(width: 128, child: _statusBadge(record))),
                    DataCell(_cell(malaysiaTime(record.createdAt), 120)),
                    DataCell(TextButton(
                        onPressed:
                            _working || _loading ? null : () => _review(record),
                        child: const Text('View'))),
                  ]),
              ])));

  Widget _card(CanonicalAdminRecommendation record) => Container(
      key: ValueKey(record.id),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(record.memberLabel ?? record.memberId,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _badge(record.typeLabel, AppColors.primary),
          _badge(record.aiMethodLabel, AppColors.info),
          _statusBadge(record),
        ]),
        const SizedBox(height: 14),
        Text(record.targetLabel,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(_contextLabel(record)),
        const SizedBox(height: 8),
        Text(record.summary),
        const SizedBox(height: 12),
        Text('${malaysiaTime(record.createdAt)} MYT',
            style: Theme.of(context).textTheme.bodySmall),
        Align(
            alignment: Alignment.centerRight,
            child: TextButton(
                onPressed: _working || _loading ? null : () => _review(record),
                child: const Text('View'))),
      ]));

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final current = widget.repository.isCurrent;
        final records = current ? _records : <CanonicalAdminRecommendation>[];
        final tab = widget.tab ??
            (widget.history
                ? RecommendationMonitorTab.history
                : RecommendationMonitorTab.overview);
        final visible = records
            .where((record) =>
                (tab != RecommendationMonitorTab.attention || _issue(record)) &&
                (_kind == 'all' || record.kind == _kind) &&
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
        final width = constraints.maxWidth - 40;
        final wide =
            width >= 1100 && MediaQuery.textScalerOf(context).scale(14) < 22;
        final filterWidth = width < 240 ? width : 210.0;
        final dateLabel = _dates == null
            ? 'Custom dates'
            : '${_dates!.start.toIso8601String().split('T').first} – ${_dates!.end.toIso8601String().split('T').first}';
        return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!current)
                const Text(
                    'Your Admin session changed. Reopen Recommendations.')
              else if (!_loading && !widget.repository.enabled)
                const Text(
                    'Recommendations are unavailable while evidence, permission and delivery policies await review.')
              else ...[
                _metrics(records, width),
                const SizedBox(height: 12),
                Text(
                    'Statistics cover ${records.length} loaded, currently authorized records. Filters apply to the list below.',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 28),
                Text(
                    tab == RecommendationMonitorTab.attention
                        ? 'Delivery issues'
                        : tab == RecommendationMonitorTab.history
                            ? 'Recommendation history'
                            : 'Recent recommendations',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                    tab == RecommendationMonitorTab.attention
                        ? 'Prepared, expired before delivery or no longer eligible records.'
                        : 'Automatically generated recommendations and their saved delivery outcomes.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  SizedBox(
                      width: width < 300 ? width : 300,
                      child: TextField(
                          decoration: const InputDecoration(
                              labelText: 'Search member or content',
                              prefixIcon: Icon(Icons.search_rounded)),
                          onChanged: (value) => setState(
                              () => _search = value.trim().toLowerCase()))),
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
                      (value) => setState(() => _status = value ?? 'all'),
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
                      onPressed: _loading || _working ? null : () => _load(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh')),
                ]),
                const SizedBox(height: 12),
                Text(
                    '${visible.length} shown · ${records.length} records loaded · dates in Malaysia time',
                    style: Theme.of(context).textTheme.bodySmall),
                if (!wide)
                  TextButton.icon(
                      onPressed: () =>
                          _sort(7, _sortColumn == 7 ? !_ascending : false),
                      icon: Icon(
                          _ascending
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 16),
                      label:
                          Text(_ascending ? 'Oldest first' : 'Newest first')),
                const SizedBox(height: 16),
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
                  wide
                      ? _table(visible)
                      : Column(children: visible.map(_card).toList()),
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
