import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../application/exercise_insights.dart';
import '../../application/exercise_insights_repository.dart';

class ExerciseInsightsPanel extends StatefulWidget {
  const ExerciseInsightsPanel(
      {super.key, this.repository, this.clock, this.onExport});
  final ExerciseInsightsRepository? repository;
  final DateTime Function()? clock;
  final void Function(String, List<List<Object?>>)? onExport;
  @override
  State<ExerciseInsightsPanel> createState() => _ExerciseInsightsPanelState();
}

class _ExerciseInsightsPanelState extends State<ExerciseInsightsPanel> {
  ExerciseInsightsRepository get _repo =>
      widget.repository ?? const UnavailableExerciseInsightsRepository();
  DateTime get _now => (widget.clock ?? DateTime.now)().toUtc();
  late ExerciseInsightsQuery _query;
  ExerciseInsightsSnapshot? _snapshot;
  String? _error, _category, _exerciseId;
  int _generation = 0, _days = 30;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _query = ExerciseInsightsQuery.recent(_repo.organizationId, _now, 30);
    _load();
  }

  @override
  void didUpdateWidget(covariant ExerciseInsightsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _query = ExerciseInsightsQuery.recent(_repo.organizationId, _now, 30);
      _category = null;
      _exerciseId = null;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation, repo = _repo, query = _query;
    setState(() {
      _snapshot = null;
      _loading = repo.enabled && repo.isCurrent;
      _error = null;
    });
    if (!repo.isCurrent) {
      setState(() {
        _error = 'Your Admin session changed. Reopen Exercise Insights.';
        _loading = false;
      });
      return;
    }
    if (!repo.enabled) return;
    try {
      final raw = await repo.load(query);
      if (!mounted || generation != _generation) return;
      if (!repo.isCurrent) throw const ExerciseInsightsUnavailable();
      final data = ExerciseInsightsSnapshot.parse(raw, query);
      setState(() {
        _snapshot = data;
        _loading = false;
        if (!data.content.any((c) => c.category == _category)) _category = null;
        if (!data.content.any((c) => c.exerciseId == _exerciseId)) {
          _exerciseId = null;
        }
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _snapshot = null;
        _loading = false;
        _error = repo.isCurrent
            ? 'Exercise insights could not be loaded. Retry.'
            : 'Your Admin session changed. Reopen Exercise Insights.';
      });
    }
  }

  void _range(int days) {
    setState(() {
      _days = days;
      _query = ExerciseInsightsQuery.recent(_repo.organizationId, _now, days);
    });
    _load();
  }

  Future<void> _calendar() async {
    final local = _now.add(const Duration(hours: 8));
    final dates = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(local.year, local.month, local.day),
        helpText: 'Malaysia dates · maximum 90 days');
    if (!mounted || dates == null) return;
    try {
      final query = ExerciseInsightsQuery.calendar(
          _repo.organizationId, _now, dates.start, dates.end);
      setState(() {
        _query = query;
        _days = 0;
      });
      _load();
    } on FormatException {
      if (mounted) {
        showToast(context, 'Choose a valid range of at most 90 days.');
      }
    }
  }

  Future<void> _configure() async {
    if (!_repo.enabled) {
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('Threshold configuration'),
                  content: const Text(
                      'No approved group policy is available in this release. Descriptive statistics do not enable recommendations. Production settings remain disabled.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'))
                  ]));
      return;
    }
    try {
      final repo = _repo, options = await _repo.configuration();
      if (!mounted || !repo.isCurrent) return;
      final selected = options.selectedPolicyIds.toSet();
      var saving = false;
      String? error;
      final saved = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
              builder: (context, update) => AlertDialog(
                    title: const Text('Threshold configuration'),
                    content: SizedBox(
                        width: 520,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  'Revision ${options.revision} · select server-reviewed exact group policies only.'),
                              const SizedBox(height: 12),
                              const Text(
                                  'Sample minimums, score-below attention and recommendation eligibility are separate. No universal threshold is applied.'),
                              if (repo.fixtureOnly)
                                const Text(
                                    'Fictional dataset policy selection'),
                              if (options.availablePolicies.isEmpty)
                                const Text(
                                    'No approved group policies are available. Descriptive-only mode remains active.'),
                              ...options.availablePolicies
                                  .map((p) => CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(p.title),
                                      subtitle: Text(p.definition),
                                      value: selected.contains(p.policyId),
                                      onChanged: saving
                                          ? null
                                          : (value) => update(() {
                                                if (value == true) {
                                                  selected.add(p.policyId);
                                                } else {
                                                  selected.remove(p.policyId);
                                                }
                                              }))),
                              if (error != null)
                                Text(error!,
                                    style: const TextStyle(
                                        color: AppColors.danger)),
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: saving
                              ? null
                              : () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: saving || options.availablePolicies.isEmpty
                              ? null
                              : () async {
                                  update(() {
                                    saving = true;
                                    error = null;
                                  });
                                  try {
                                    if (!repo.isCurrent) {
                                      throw const ExerciseInsightsUnavailable();
                                    }
                                    await repo.saveConfiguration(
                                        options.revision,
                                        selected.toList()..sort());
                                    if (!repo.isCurrent) {
                                      throw const ExerciseInsightsUnavailable();
                                    }
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext, true);
                                    }
                                  } catch (_) {
                                    if (dialogContext.mounted) {
                                      update(() {
                                        saving = false;
                                        error =
                                            'Settings changed or are unavailable. Reopen before retrying.';
                                      });
                                    }
                                  }
                                },
                          child: Text(
                              saving ? 'Saving…' : 'Save reviewed selection'))
                    ],
                  )));
      if (mounted && saved == true) await _load();
    } catch (_) {
      if (mounted) {
        showToast(
            context, 'Configuration is unavailable. Reopen before retrying.');
      }
    }
  }

  void _export(String filename, List<List<Object?>> Function() rows) {
    if (!_repo.isCurrent || _snapshot == null || _loading) {
      setState(() {
        _snapshot = null;
        _error = 'Your Admin session changed. Reopen Exercise Insights.';
      });
      return;
    }
    final result = rows();
    if (widget.onExport != null) {
      widget.onExport!(filename, result);
    } else {
      downloadCsv(filename, result);
    }
  }

  Widget _section(
          String title,
          String subtitle,
          String exportKey,
          String filename,
          bool enabled,
          List<List<Object?>> Function() rows,
          Widget body) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium)
              ])),
          IconButton(
              key: ValueKey(exportKey),
              tooltip: enabled ? 'Export $title CSV' : 'Export unavailable',
              onPressed: enabled ? () => _export(filename, rows) : null,
              icon: const Icon(Icons.download_rounded))
        ]),
        const SizedBox(height: 12),
        body,
        const SizedBox(height: 24),
      ]);
  Widget _insightColumns(Widget main, Widget rail) => LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 900
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: main),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: rail),
            ])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [main, const SizedBox(height: 20), rail]));
  @override
  Widget build(BuildContext context) {
    final current = _repo.isCurrent, data = current ? _snapshot : null;
    final groups =
        data?.filteredGroups(category: _category, exerciseId: _exerciseId) ??
            const <ExerciseInsightGroup>[];
    final content =
        data?.filteredContent(category: _category, exerciseId: _exerciseId) ??
            const <ContentCoverage>[];
    final gaps = content
        .where((c) => c.coverage == 'missing_published_tutorial')
        .toList();
    final categories = (data?.content.map((c) => c.category).toSet().toList() ??
        <String>[])
      ..sort();
    final failure = !current
        ? 'Your Admin session changed. Reopen Exercise Insights.'
        : _error;
    return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Exercises Needing Attention',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(_repo.fixtureOnly
              ? 'Exercise evidence · educational review'
              : 'Production processing is not activated.'),
          const SizedBox(height: 12),
          Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    data?.mode == 'approved_group_attention'
                        ? 'Reviewed group attention'
                        : 'Descriptive-only mode',
                    style: Theme.of(context).textTheme.titleMedium),
                const Text(
                    'Estimated Form Scores use compatible exercise, rule, model, view and mode groups. Not a clinical injury-risk measurement.'),
                const Text(
                    'Coverage = tracked / (tracked + rejected); unmeasured time is excluded. Missing scores, unscored exercises and missing histories are not poor performance or inactivity.'),
                const Text(
                    'Distinct Member counts are per group and must not be added. Suppressed or unavailable groups are not reported as zero. Recommendation eligibility is not evaluated.'),
                const SizedBox(height: 8),
                Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                          'Configuration revision ${data?.configurationRevision ?? '—'}'),
                      TextButton.icon(
                          onPressed: current && !(_repo is InsightsReadOnlyPresentation&&(_repo as InsightsReadOnlyPresentation).readOnly) ? _configure : null,
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text('Threshold configuration'))
                    ]),
              ])),
          const SizedBox(height: 16),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final days in [7, 30, 90])
                  ChoiceChip(
                      label: Text('$days days'),
                      selected: _days == days,
                      onSelected: _loading ? null : (_) => _range(days)),
                OutlinedButton.icon(
                    onPressed: _loading ? null : _calendar,
                    icon: const Icon(Icons.date_range_rounded),
                    label: const Text('Custom dates')),
                Text('${_query.malaysiaLabel} · Malaysia'),
                IconButton(
                    tooltip: 'Refresh insights',
                    onPressed: _repo.enabled && !_loading ? _load : null,
                    icon: const Icon(Icons.refresh_rounded)),
              ]),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                    key: const ValueKey('insights-category'),
                    isExpanded: true,
                    initialValue: data == null ? null : _category,
                    decoration:
                        const InputDecoration(labelText: 'Exercise category'),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('All categories')),
                      ...categories.map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)))
                    ],
                    onChanged: data == null
                        ? null
                        : (v) => setState(() {
                              _category = v;
                              _exerciseId = null;
                            }))),
            SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                    key: ValueKey('insights-exercise-$_category'),
                    isExpanded: true,
                    initialValue: data == null ? null : _exerciseId,
                    decoration: const InputDecoration(labelText: 'Exercise'),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('All exercises')),
                      ...data?.content
                              .where((c) =>
                                  _category == null || c.category == _category)
                              .map((c) => DropdownMenuItem(
                                  value: c.exerciseId,
                                  child: Text(c.name,
                                      overflow: TextOverflow.ellipsis))) ??
                          []
                    ],
                    onChanged: data == null
                        ? null
                        : (v) => setState(() => _exerciseId = v))),
          ]),
          const SizedBox(height: 18),
          if (_loading) const LinearProgressIndicator(),
          if (failure != null) Panel(child: Text(failure)),
          if (!_repo.enabled)
            const Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Exercise insights are unavailable in this release.'),
                  Text('—'),
                  Text(
                      'Privacy policy, source readiness and release approval are required before production reads.')
                ])),
          if (data?.privacyState == 'review_required')
            const Panel(
                child: Text(
                    'Aggregate disclosure policy requires review. All observed counts and scores are withheld.')),
          const SizedBox(height: 12),
          _insightColumns(
              _section(
                  'Compatible exercise groups',
                  'Separate estimated-form evidence; no comparison of raw scores across exercise rubrics.',
                  'export-exercise-insights',
                  'exercise_insights.csv',
                  data != null && groups.isNotEmpty,
                  () => data!.insightsCsv(
                      category: _category,
                      exerciseId: _exerciseId,
                      synthetic: _repo.fixtureOnly),
                  groups.isEmpty
                      ? const Panel(
                          child: Text(
                              'No disclosed compatible groups for these filters. Values may be withheld or unavailable.'))
                      : Column(children: [
                          SizedBox(
                              height: 220,
                              child: SfCartesianChart(
                                  plotAreaBorderWidth: 0,
                                  primaryXAxis: const CategoryAxis(
                                      labelIntersectAction:
                                          AxisLabelIntersectAction.wrap),
                                  primaryYAxis: const NumericAxis(
                                      minimum: 0,
                                      maximum: 100,
                                      decimalPlaces: 0),
                                  tooltipBehavior:
                                      TooltipBehavior(enable: true),
                                  series: <CartesianSeries<ExerciseInsightGroup,
                                      String>>[
                                    ColumnSeries<ExerciseInsightGroup, String>(
                                        color: AppColors.primary,
                                        dataSource: groups.take(12).toList(),
                                        xValueMapper: (g, i) =>
                                            '${i + 1}. ${g.name}',
                                        yValueMapper: (g, _) => g.score)
                                  ])),
                          const Text(
                              'Estimated Form Score per compatible group · first 12 filtered groups. Missing scores are not plotted; different rubrics are not directly comparable.'),
                          const SizedBox(height: 12),
                          ...groups.map((g) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Panel(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text('${groups.indexOf(g) + 1}. ${g.name}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    Text(g.category),
                                    const SizedBox(height: 8),
                                    Wrap(spacing: 18, runSpacing: 6, children: [
                                      Text(g.scoreLabel,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700)),
                                      Text(
                                          '${g.scoredSessions} scored sessions · ${g.members} distinct Members'),
                                      Text(
                                          '${g.coverage == null ? 'Unknown' : '${(g.coverage! * 100).toStringAsFixed(1)}%'} tracking coverage'),
                                      Text(
                                          '${g.missingScores} missing scores · ${g.unscoredSessions} unscored sessions')
                                    ]),
                                    Text(
                                        'Evidence: ${g.evidenceLabel} · Attention: ${g.attentionLabel}'),
                                    ExpansionTile(
                                        tilePadding: EdgeInsets.zero,
                                        title:
                                            const Text('Compatibility details'),
                                        children: [
                                          Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                  '${g.displayGroup}\nModel ${g.compatibility['detectorVersion']}')),
                                        ]),
                                  ])))),
                        ])),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                      child: StatTile(data == null ? '—' : '${groups.length}',
                          'Disclosed groups',
                          compact: true)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: StatTile(data == null ? '—' : '${gaps.length}',
                          'Instruction gaps',
                          compact: true)),
                ]),
                const SizedBox(height: 16),
                _section(
                    'Published content coverage',
                    'Active catalog exercises joined by ID to published tutorial projections; media reachability is not verified.',
                    'export-content-coverage',
                    'content_coverage.csv',
                    data != null && content.isNotEmpty,
                    () => data!.contentCsv(
                        category: _category,
                        exerciseId: _exerciseId,
                        synthetic: _repo.fixtureOnly),
                    Panel(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: content.isEmpty
                                ? [
                                    const Text(
                                        'Content coverage is unavailable or no exercises match these filters.')
                                  ]
                                : content
                                    .map((c) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 5),
                                        child: Text(
                                            '${c.name} · ${c.category} · ${c.publishedTutorials} published projection(s) · ${c.coverageLabel}')))
                                    .toList()))),
                _section(
                    'Content Gap Report',
                    'Catalog instruction gaps are separate from attention-linked gaps, which require an approved compatible policy.',
                    'export-content-gaps',
                    'content_gaps.csv',
                    data != null && gaps.isNotEmpty,
                    () => data!.gapsCsv(
                        category: _category,
                        exerciseId: _exerciseId,
                        synthetic: _repo.fixtureOnly),
                    Panel(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          if (data == null)
                            const Text(
                                'Content gap analysis is unavailable in this release.')
                          else if (gaps.isEmpty)
                            const Text(
                                'No catalog instruction gaps in the current filtered publication snapshot.')
                          else
                            ...gaps.map((c) => Text(
                                '${c.name} · No published tutorial · Attention-linked gap: ${c.attentionLabel}')),
                        ]))),
              ])),
        ]));
  }
}
