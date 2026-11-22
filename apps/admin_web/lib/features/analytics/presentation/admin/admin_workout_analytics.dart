import 'dart:math' as math;
import 'report_metric_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../application/admin_reporting_gateway.dart';
import '../../application/admin_workout_reporting.dart';
import 'admin_remaining_analytics.dart';
import 'admin_workout_summary.dart';

enum FitnessTab {
  overview,
  exerciseAnalytics,
  aiFormInsights,
}

class AdminWorkoutAnalytics extends StatefulWidget {
  const AdminWorkoutAnalytics({
    super.key,
    required this.query,
    this.controller,
    this.compact = false,
    this.refreshToken = 0,
    this.anchorKey,
    this.postureSection,
    this.initialTab = FitnessTab.overview,
  });

  final AdminWorkoutReportingCubit? controller;
  final AdminReportQuery query;
  final bool compact;
  final int refreshToken;
  final GlobalKey? anchorKey;
  final Widget? postureSection;
  final FitnessTab initialTab;

  @override
  State<AdminWorkoutAnalytics> createState() => _AdminWorkoutAnalyticsState();
}

class _AdminWorkoutAnalyticsState extends State<AdminWorkoutAnalytics> {
  AdminWorkoutReportingCubit? _cubit;
  bool _weekly = false;
  late FitnessTab _selectedTab;
  String _exerciseSearchQuery = '';
  String _exerciseSort = 'sessions'; // 'sessions', 'name', 'reps'

  @override
  void initState({Key? key}) {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.controller != null) {
      _cubit = widget.controller;
      return;
    }
    final gateway = context.read<AdminReportingGateway>();
    if (gateway is AdminWorkoutReportingGateway &&
        !identical(_cubit?.gateway, gateway)) {
      _cubit?.close();
      _cubit = AdminWorkoutReportingCubit(
          gateway: gateway as AdminWorkoutReportingGateway, query: widget.query)
        ..load();
    }
  }

  @override
  void didUpdateWidget(AdminWorkoutAnalytics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null) {
      _cubit = widget.controller;
      return;
    }
    if (widget.query != oldWidget.query ||
        widget.refreshToken != oldWidget.refreshToken) {
      _cubit?.load(widget.query);
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _cubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cubit == null) return const SizedBox.shrink();
    return BlocBuilder<AdminWorkoutReportingCubit, AdminWorkoutReportingState>(
      bloc: _cubit,
      builder: (context, state) {
        final report = state.report;
        final controls = Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              label: Text(report?.mixedSources == true
                  ? 'Workout observations'
                  : report?.fictional == true
                      ? 'Workout observations'
                      : 'Provisional backups'),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: 'Refresh workout analytics',
              onPressed: state.loading ? null : () => _cubit!.load(),
              icon: const Icon(Icons.refresh_rounded),
            ),
            if (widget.compact)
              IconButton(
                tooltip: 'Export workout CSV',
                onPressed: report == null
                    ? null
                    : () => downloadCsv(
                        'gainpath-workout-activity.csv', report.toCsv()),
                icon: const Icon(Icons.download_rounded),
              ),
          ],
        );

        final content = state.loading && report == null
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Expanded(child: Text('Loading workout analytics…')),
                  ],
                ),
              )
            : report == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.error ?? 'Workout analytics is unavailable.'),
                      TextButton.icon(
                        onPressed: () => _cubit!.load(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry workout analytics'),
                      ),
                      if (widget.postureSection != null) widget.postureSection!,
                    ],
                  )
                : _data(context, report);

        if (widget.compact) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Workout activity',
                      style: Theme.of(context).textTheme.titleMedium),
                  controls,
                  if (state.loading && report != null)
                    const LinearProgressIndicator(),
                  if (state.error != null && report != null)
                    Text(state.error!),
                  const SizedBox(height: 10),
                  content,
                ],
              ),
            ),
          );
        }

        return ReportSection(
          anchorKey: widget.anchorKey ?? _fallbackAnchor,
          title: 'Workout activity',
          subtitle: report?.mixedSources == true
              ? 'Recorded workout activity · performance estimates are not physical verification'
              : report?.fictional == true
                  ? 'Recorded workout activity'
                  : 'Saved device measurements and routine attempt outcomes · organization-wide',
          live: true,
          tagLabel: report == null
              ? (state.loading ? 'Loading' : 'Unavailable')
              : report.fypSourceUnavailable
                  ? 'Partial'
                  : report.mixedSources
                      ? 'Workout activity'
                      : report.fictional
                          ? 'Recorded observations'
                          : 'Provisional backups',
          exportFilename: 'gainpath-workout-activity.csv',
          exportEnabled: report != null,
          exportRows: report?.toCsv,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  _buildTabBar(),
                  controls,
                ],
              ),
              if (state.loading && report != null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                ),
              if (state.error != null && report != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(state.error!,
                      style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 16),
              content,
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTabItem(FitnessTab.overview, 'Overview', Icons.dashboard_outlined),
            const SizedBox(width: 4),
            _buildTabItem(FitnessTab.exerciseAnalytics, 'Exercise Analytics',
                Icons.fitness_center_outlined),
            const SizedBox(width: 4),
            _buildTabItem(FitnessTab.aiFormInsights, 'AI Form Insights',
                Icons.auto_awesome_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(FitnessTab tab, String label, IconData icon) {
    final isSelected = _selectedTab == tab;
    return InkWell(
      onTap: () => setState(() => _selectedTab = tab),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primary : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  final _fallbackAnchor = GlobalKey();

  Widget _data(BuildContext context, AdminWorkoutReport r) {
    if (widget.compact) {
      return _buildCompactView(context, r);
    }

    switch (_selectedTab) {
      case FitnessTab.overview:
        return _buildOverviewTab(context, r);
      case FitnessTab.exerciseAnalytics:
        return _buildExerciseAnalyticsTab(context, r);
      case FitnessTab.aiFormInsights:
        return _buildAiFormInsightsTab(context, r);
    }
  }

  Widget _buildCompactView(BuildContext context, AdminWorkoutReport r) {
    final t = r.totals, text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.fypSourceUnavailable)
          const Text(
              'Partial report. Canonical backups are available. Refresh to retry the FYP source.'),
        ReportMetricGrid(children: [
          SizedBox(
              width: 175,
              child: StatTile('${t.sessions}', r.sessionLabel, compact: true)),
          SizedBox(
              width: 175,
              child: StatTile('${t.completedRoutineDays}',
                  'Completed routine attempts',
                  compact: true)),
          SizedBox(
              width: 175,
              child: StatTile(
                  '${t.fullReps}',
                  r.mixedSources || r.fictional
                      ? 'Recorded full reps'
                      : 'Measured full reps',
                  compact: true)),
          SizedBox(
              width: 175,
              child: StatTile(_duration(t.trackedMicros), 'Tracked duration',
                  compact: true)),
        ]),
        const SizedBox(height: 12),
        Text(
          '${r.coverage['membersWithBackups']} / ${r.coverage['activeMembers']} current active Members have ${r.mixedSources ? 'source observations' : r.fictional ? 'fictional observations' : 'backup records'} · '
          '${r.coverage['membersWithActivity']} with activity in range.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 6),
        Text(
          r.mixedSources
              ? 'Recorded observations do not establish verified camera performance, attendance or rewards.'
              : r.fictional
                  ? 'Recorded observations from recorded fixtures. These are read-only educational data, not physical camera captures, accepted workouts or rewards.'
                  : 'Backup coverage only. Missing or device-only workouts are excluded. Counts are provisional; manual sets are self-reported. Backup presence does not mean backup is currently enabled.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(
          '${t.inProgressRoutineDays} in progress · ${t.partialRoutineDays} finished incomplete · ${t.unknownCompletionDays} completion dates unknown',
          style: text.bodySmall,
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 1: OVERVIEW
  // =========================================================================
  Widget _buildOverviewTab(BuildContext context, AdminWorkoutReport r) {
    final t = r.totals, text = Theme.of(context).textTheme;

    Widget stat(String value, String label, {Color? color}) => SizedBox(
          width: 195,
          child: StatTile(value, label, compact: true, valueColor: color),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.fypSourceUnavailable)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.amber.shade800, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Partial report. Canonical backups are available. Refresh to retry the FYP source.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 4 Primary KPI cards
        ReportMetricGrid(children: [
          stat('${t.sessions}', r.sessionLabel, color: AppColors.primary),
          stat('${t.completedRoutineDays}', 'Completed routine attempts',
              color: const Color(0xFF16A34A)),
          stat(
            '${t.fullReps}',
            r.mixedSources || r.fictional
                ? 'Recorded full reps'
                : 'Measured full reps',
            color: const Color(0xFF2563EB),
          ),
          stat(
            '${t.partialReps}',
            r.mixedSources || r.fictional
                ? 'Recorded partial reps'
                : 'Measured partial reps',
            color: const Color(0xFFD97706),
          ),
        ]),

        const SizedBox(height: 10),
        // 2 Secondary Metrics
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 220,
              child: _buildSecondaryMetricTile(
                context,
                label: 'Tracked duration',
                value: _duration(t.trackedMicros),
                icon: Icons.timer_outlined,
              ),
            ),
            SizedBox(
              width: 220,
              child: _buildSecondaryMetricTile(
                context,
                label: 'Manual sets',
                value: '${t.manualSets}',
                icon: Icons.edit_note_rounded,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),
        // Active members coverage disclosure
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.people_outline,
                  size: 18, color: Color(0xFF64748B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${r.coverage['membersWithBackups']} / ${r.coverage['activeMembers']} current active Members have ${r.mixedSources ? 'source observations' : r.fictional ? 'fictional observations' : 'backup records'} · '
                  '${r.coverage['membersWithActivity']} with activity in range.',
                  style: text.bodySmall?.copyWith(color: const Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),
        Text(
          r.mixedSources
              ? 'Recorded observations do not establish verified camera performance, attendance or rewards.'
              : r.fictional
                  ? 'Recorded observations from recorded fixtures. These are read-only educational data, not physical camera captures, accepted workouts or rewards.'
                  : 'Backup coverage only. Missing or device-only workouts are excluded. Counts are provisional; manual sets are self-reported. Backup presence does not mean backup is currently enabled.',
          style: text.bodySmall?.copyWith(color: const Color(0xFF64748B)),
        ),

        const SizedBox(height: 18),
        // Two-column responsive layout: Workout Activity Trend & Routine Attempt Outcomes
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 950;
            final trendCard = Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Workout activity trend', style: text.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Daily'),
                        selected: !_weekly,
                        onSelected: (_) => setState(() => _weekly = false),
                      ),
                      ChoiceChip(
                        label: const Text('Weekly'),
                        selected: _weekly,
                        onSelected: (_) => setState(() => _weekly = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (r.daily.isNotEmpty)
                    _trend(r.trend(weekly: _weekly), sessionLabel: r.sessionLabel)
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: NoFilteredData(message: 'No activity dates to chart.'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    _weekly
                        ? 'Weeks start Monday; boundary weeks include only the selected date range.'
                        : 'Malaysia calendar dates with recorded activity. Gaps have no source activity.',
                    style: text.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            );

            final outcomesCard = Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Routine attempt outcomes', style: text.titleMedium),
                  const SizedBox(height: 12),
                  _buildRoutineOutcomesBar(t),
                  const SizedBox(height: 16),
                  _buildOutcomeDetailRow(
                    label: 'Completed',
                    count: t.completedRoutineDays,
                    total: t.routineAttempts,
                    color: const Color(0xFF10B981),
                  ),
                  const Divider(height: 14),
                  _buildOutcomeDetailRow(
                    label: 'Finished incomplete',
                    count: t.partialRoutineDays,
                    total: t.routineAttempts,
                    color: const Color(0xFFF59E0B),
                  ),
                  const Divider(height: 14),
                  _buildOutcomeDetailRow(
                    label: 'In progress',
                    count: t.inProgressRoutineDays,
                    total: t.routineAttempts,
                    color: AppColors.primary,
                  ),
                  const Divider(height: 14),
                  _buildOutcomeDetailRow(
                    label: 'Completion date unknown',
                    count: t.unknownCompletionDays,
                    total: t.routineAttempts,
                    color: const Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Completion is device-reported and requires all day targets, including manual targets. Routine dates use finish time, or last update when unfinished/unknown. Resuming can move a record between periods. Sessions use end time and are counted once, separately from routine summaries.',
                    style: text.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            );

            if (isNarrow) {
              return Column(
                children: [
                  trendCard,
                  const SizedBox(height: 16),
                  outcomesCard,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: trendCard),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: outcomesCard),
              ],
            );
          },
        ),

        const SizedBox(height: 18),
        // Overview Summary Cards: AI Tracking Exercises & AI Form Insights Preview
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Six AI tracking exercises',
                          style: text.titleMedium),
                      Text(
                        'Current supported variants · selected reporting dates',
                        style: text.bodySmall
                            ?.copyWith(color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => setState(
                        () => _selectedTab = FitnessTab.exerciseAnalytics),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Explore Exercise Analytics →'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildAiExercisesCompactTable(r),
            ],
          ),
        ),

        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estimated form by compatible version',
                          style: text.titleMedium),
                      Text(
                        'Mean of scored session estimates within each exercise/rule/model/view/arm group. No platform-wide accuracy or clinical assessment is inferred.',
                        style: text.bodySmall
                            ?.copyWith(color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => setState(
                        () => _selectedTab = FitnessTab.aiFormInsights),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Explore AI Form Insights →'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildMiniBadge(
                    'Eligible scored sessions: ${r.forms.fold<int>(0, (count, group) => count + group.scoredSessions)}',
                    const Color(0xFFEDE9FE),
                    AppColors.primary,
                  ),
                  _buildMiniBadge(
                    'Not assessed: ${t.sessions - r.forms.fold<int>(0, (count, group) => count + group.scoredSessions)}',
                    const Color(0xFFF1F5F9),
                    const Color(0xFF475569),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (r.forms.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No compatible scored measurements in range.'),
                )
              else
                for (final f in r.forms.take(3))
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reportExerciseName(f.exerciseId, r),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                              Text(
                                '${f.cameraView.toUpperCase()} VIEW · ${f.scoredSessions} scored sessions',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${f.average.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        // Methodology & Data Coverage ExpansionTile
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.verified_user_outlined,
                  size: 18, color: Color(0xFF64748B)),
              title: const Text(
                'Methodology & Data Coverage Disclosure',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              subtitle: const Text(
                'Data integrity, observation qualifications, and aggregation parameters',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.mixedSources
                            ? 'Current active membership is not attendance. Records use the latest eligible revisions within the selected dates.'
                            : r.fictional
                                ? 'Recorded dates do not prove physical camera activity or attendance.'
                                : 'Latest backups only; archived revisions are excluded. Current active Member census is not historical attendance. Source scan ${r.scanStartedAt.toUtc().toIso8601String()} to ${r.capturedAt.toUtc().toIso8601String()}; these bounded reads are not one atomic snapshot.',
                        style: text.bodySmall?.copyWith(color: const Color(0xFF475569)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Workout results are device-reported and self-contained within each member attempt.\n'
                        '• Movement observations are descriptive and do not constitute physical camera verification or attendance.\n'
                        '• AI form score estimates are provisional and calculated exclusively within compatible rule/model/view groups.\n'
                        '• Routine attempt completion requires meeting all assigned day targets, including manual entries.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 2: EXERCISE ANALYTICS
  // =========================================================================
  Widget _buildExerciseAnalyticsTab(
      BuildContext context, AdminWorkoutReport r) {
    final text = Theme.of(context).textTheme;
    final byId = {
      for (final exercise in r.exercises) exercise.exerciseId: exercise
    };

    // Filter and sort the movement library
    var filtered = r.exercises.where((e) {
      if (_exerciseSearchQuery.isEmpty) return true;
      return e.name.toLowerCase().contains(_exerciseSearchQuery.toLowerCase()) ||
          e.exerciseId
              .toLowerCase()
              .contains(_exerciseSearchQuery.toLowerCase());
    }).toList();

    if (_exerciseSort == 'sessions') {
      filtered.sort((a, b) => b.sessions.compareTo(a.sessions));
    } else if (_exerciseSort == 'reps') {
      filtered.sort((a, b) => b.fullReps.compareTo(a.fullReps));
    } else if (_exerciseSort == 'name') {
      filtered.sort((a, b) => a.name.compareTo(b.name));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab Header banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF8FF),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fitness_center_rounded,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Exercise Movement Intelligence',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Supported AI-tracking exercise variants and catalog movement performance across active workout sessions.',
                      style: text.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        // Section: Six AI Tracking Exercises
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Six AI tracking exercises', style: text.titleMedium),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 12, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Computer Vision',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Current supported variants · selected reporting dates',
                style: text.bodySmall?.copyWith(color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Exercise Movement')),
                    DataColumn(label: Text('Sessions'), numeric: true),
                    DataColumn(label: Text('Full reps'), numeric: true),
                    DataColumn(label: Text('Partial reps'), numeric: true),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: [
                    for (final entry in currentAiReportExercises.entries)
                      DataRow(
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    size: 16, color: Color(0xFF10B981)),
                                const SizedBox(width: 8),
                                Text(
                                  entry.value,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text('${byId[entry.key]?.sessions ?? 0}')),
                          DataCell(Text('${byId[entry.key]?.fullReps ?? 0}')),
                          DataCell(Text('${byId[entry.key]?.partialReps ?? 0}')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'AI-Tracked',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Other and historical exercises remain in the exercise details and CSV.',
                style: text.bodySmall?.copyWith(color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        // Section: Other Exercise Details / Movement Library
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Other exercise details', style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Ranked by ${r.sessionLabel.toLowerCase()}. Snapshot names may differ from the current catalog. Top ${filtered.length > 10 ? 10 : filtered.length} of ${r.exercises.length}; CSV includes all.',
                style: text.bodySmall?.copyWith(color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),

              // Search & Sort Controls
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    height: 40,
                    child: TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 18),
                        hintText: 'Search movements by name...',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      onChanged: (val) =>
                          setState(() => _exerciseSearchQuery = val),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButton<String>(
                          value: _exerciseSort,
                          items: const [
                            DropdownMenuItem(
                                value: 'sessions',
                                child: Text('Sort by Sessions',
                                    style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(
                                value: 'reps',
                                child: Text('Sort by Full Reps',
                                    style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(
                                value: 'name',
                                child: Text('Sort by Name',
                                    style: TextStyle(fontSize: 13))),
                          ],
                          onChanged: (val) =>
                              setState(() => _exerciseSort = val ?? 'sessions'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No measured sessions or manual sets in range.'),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('Exercise Name')),
                      DataColumn(label: Text('Sessions'), numeric: true),
                      DataColumn(label: Text('Full reps'), numeric: true),
                      DataColumn(label: Text('Partial reps'), numeric: true),
                      DataColumn(label: Text('Tracked duration')),
                      DataColumn(label: Text('Manual sets'), numeric: true),
                      DataColumn(label: Text('Details')),
                    ],
                    rows: [
                      for (final e in filtered.take(15))
                        DataRow(
                          cells: [
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    e.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  if (currentAiReportExercises
                                      .containsKey(e.exerciseId))
                                    const Text(
                                      'AI-Supported Movement',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            DataCell(Text('${e.sessions}')),
                            DataCell(Text('${e.fullReps}')),
                            DataCell(Text('${e.partialReps}')),
                            DataCell(Text(_duration(e.trackedMicros))),
                            DataCell(Text('${e.manualSets}')),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.info_outline, size: 18),
                                tooltip: 'View exercise breakdown',
                                onPressed: () =>
                                    _showExerciseDetailsDialog(context, e, r),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showExerciseDetailsDialog(
      BuildContext context, WorkoutExerciseUsage e, AdminWorkoutReport r) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.fitness_center_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(e.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildDialogRow('Stable Exercise ID', e.exerciseId),
                    const Divider(height: 12),
                    _buildDialogRow('Recorded Sessions', '${e.sessions}'),
                    const Divider(height: 12),
                    _buildDialogRow('Full Repetitions', '${e.fullReps}'),
                    const Divider(height: 12),
                    _buildDialogRow('Partial Repetitions', '${e.partialReps}'),
                    const Divider(height: 12),
                    _buildDialogRow(
                        'Tracked Duration', _duration(e.trackedMicros)),
                    const Divider(height: 12),
                    _buildDialogRow('Manual Sets', '${e.manualSets}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Snapshot names reflect the catalog version recorded at observation time. Exercise records are preserved across catalog updates and exported without aggregation mutation.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // =========================================================================
  // TAB 3: AI FORM INSIGHTS
  // =========================================================================
  Widget _buildAiFormInsightsTab(BuildContext context, AdminWorkoutReport r) {
    final t = r.totals, text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab Header banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF8FF),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Form Insights',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Provisional movement-form estimates from compatible scoring groups.',
                      style: text.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        // Score coverage metrics
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 220,
              child: _buildSecondaryMetricTile(
                context,
                label: 'Eligible scored sessions',
                value:
                    '${r.forms.fold<int>(0, (count, group) => count + group.scoredSessions)}',
                icon: Icons.check_circle_outline,
              ),
            ),
            SizedBox(
              width: 220,
              child: _buildSecondaryMetricTile(
                context,
                label: 'Not assessed',
                value:
                    '${t.sessions - r.forms.fold<int>(0, (count, group) => count + group.scoredSessions)}',
                icon: Icons.help_outline_rounded,
              ),
            ),
            SizedBox(
              width: 220,
              child: _buildSecondaryMetricTile(
                context,
                label: 'Saved camera captures',
                value: '${t.sessions}',
                icon: Icons.videocam_outlined,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        // Embedded Posture Section (or fallback)
        if (widget.postureSection != null)
          widget.postureSection!
        else
          AdminPostureSection(
            controller: _cubit,
            query: widget.query,
            anchorKey: GlobalKey(),
          ),
      ],
    );
  }

  // =========================================================================
  // HELPER WIDGETS
  // =========================================================================

  Widget _buildSecondaryMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF475569)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineOutcomesBar(WorkoutTotals t) {
    final total = t.routineAttempts;
    if (total == 0) {
      return Container(
        height: 12,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }

    final compFlex = math.max(1, (t.completedRoutineDays * 100 ~/ total));
    final partFlex = math.max(1, (t.partialRoutineDays * 100 ~/ total));
    final inProgFlex = math.max(1, (t.inProgressRoutineDays * 100 ~/ total));
    final unkFlex = math.max(1, (t.unknownCompletionDays * 100 ~/ total));

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            if (t.completedRoutineDays > 0)
              Expanded(
                flex: compFlex,
                child: Container(color: const Color(0xFF10B981)),
              ),
            if (t.partialRoutineDays > 0)
              Expanded(
                flex: partFlex,
                child: Container(color: const Color(0xFFF59E0B)),
              ),
            if (t.inProgressRoutineDays > 0)
              Expanded(
                flex: inProgFlex,
                child: Container(color: AppColors.primary),
              ),
            if (t.unknownCompletionDays > 0)
              Expanded(
                flex: unkFlex,
                child: Container(color: const Color(0xFF94A3B8)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutcomeDetailRow({
    required String label,
    required int count,
    required int total,
    required Color color,
  }) {
    final percentage = total == 0 ? 0.0 : (count / total * 100);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
          ),
        ),
        Text(
          '$count',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 48,
          child: Text(
            '${percentage.toStringAsFixed(1)}%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }

  Widget _buildAiExercisesCompactTable(AdminWorkoutReport r) {
    final byId = {
      for (final exercise in r.exercises) exercise.exerciseId: exercise
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 38,
        dataRowMinHeight: 38,
        dataRowMaxHeight: 44,
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
        columns: const [
          DataColumn(label: Text('Exercise')),
          DataColumn(label: Text('Sessions'), numeric: true),
          DataColumn(label: Text('Full reps'), numeric: true),
          DataColumn(label: Text('Partial reps'), numeric: true),
        ],
        rows: [
          for (final entry in currentAiReportExercises.entries)
            DataRow(
              cells: [
                DataCell(Text(entry.value,
                    style: const TextStyle(fontWeight: FontWeight.w500))),
                DataCell(Text('${byId[entry.key]?.sessions ?? 0}')),
                DataCell(Text('${byId[entry.key]?.fullReps ?? 0}')),
                DataCell(Text('${byId[entry.key]?.partialReps ?? 0}')),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textCol,
        ),
      ),
    );
  }

  Widget _trend(List<WorkoutReportDay> days, {required String sessionLabel}) =>
      SizedBox(
        height: 250,
        child: SfCartesianChart(
          plotAreaBorderWidth: 0,
          primaryXAxis: CategoryAxis(
            maximumLabels: 5,
            majorGridLines: const MajorGridLines(width: 0),
            labelIntersectAction: AxisLabelIntersectAction.hide,
            axisLabelFormatter: (details) => ChartAxisLabel(
              details.text.length == 10
                  ? details.text.substring(5)
                  : details.text,
              details.textStyle,
            ),
          ),
          primaryYAxis: NumericAxis(
            minimum: 0,
            decimalPlaces: 0,
            interval: days.every((day) =>
                    day.sessions <= 5 &&
                    day.totals.completedRoutineDays <= 5)
                ? 1
                : null,
          ),
          legend: const Legend(
            isVisible: true,
            position: LegendPosition.bottom,
            overflowMode: LegendItemOverflowMode.wrap,
          ),
          tooltipBehavior: TooltipBehavior(enable: true),
          series: <CartesianSeries<WorkoutReportDay, String>>[
            ColumnSeries<WorkoutReportDay, String>(
              name: sessionLabel == 'Saved camera sessions'
                  ? 'Camera sessions'
                  : sessionLabel,
              dataSource: days,
              xValueMapper: (d, _) => d.date,
              yValueMapper: (d, _) => d.sessions,
              color: AppColors.primary,
            ),
            ColumnSeries<WorkoutReportDay, String>(
              name: 'Completed routine attempts',
              dataSource: days,
              xValueMapper: (d, _) => d.date,
              yValueMapper: (d, _) => d.totals.completedRoutineDays,
              color: AppColors.success,
            ),
          ],
        ),
      );
}

String _duration(int micros) {
  final seconds = micros ~/ 1000000;
  return '${seconds ~/ 60}m ${seconds % 60}s';
}
