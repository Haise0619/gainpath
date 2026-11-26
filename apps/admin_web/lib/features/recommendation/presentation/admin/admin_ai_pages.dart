import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/admin_ai_repository.dart';

String _failure(Object error, String fallback) =>
    error is FirebaseFunctionsException &&
            const [
              'failed-precondition',
              'permission-denied',
              'unavailable',
              'aborted',
              'resource-exhausted'
            ].contains(error.code) &&
            error.message != null
        ? error.message!
        : fallback;

class AiContentPlannerPage extends StatefulWidget {
  const AiContentPlannerPage({
    super.key,
    this.repository,
    required this.onApply,
  });
  final AdminAiRepository? repository;
  final Future<void> Function(BuildContext, Map<String, dynamic>) onApply;
  @override
  State<AiContentPlannerPage> createState() => _AiContentPlannerPageState();
}

class _AiContentPlannerPageState extends State<AiContentPlannerPage> {
  final _instructions = TextEditingController();
  String _type = 'exercise';
  int _days = 30;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _result;
  final _dismissed = <int>{};
  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _dismissed.clear();
    });
    try {
      final r = await widget.repository!.call('admin.ai.planner', {
        'type': _type,
        'days': _days,
        'instructions': _instructions.text.trim(),
        'requestId': aiRequestId()
      });
      if (mounted) setState(() => _result = r);
    } catch (error) {
      if (mounted) {
        setState(() => _error = _failure(error,
            'Suggestions could not be generated. Check your access and Gemini configuration, then retry.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions =
        (_result?['suggestions'] as List? ?? []).map(aiMap).toList();
    return _AiScaffold(children: [
      const _AiHeading(
          icon: Icons.auto_awesome_outlined,
          title: 'AI Content Planner',
          subtitle:
              'Discover new fitness content opportunities using AI and workout insights.'),
      _Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('What would you like to create?',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final entry in const {
            'exercise': 'Exercise',
            'routine': 'Routine',
            'program': 'Program'
          }.entries)
            ChoiceChip(
                selectedColor: AppColors.primaryTint,
                checkmarkColor: AppColors.primary,
                side: const BorderSide(color: AppColors.hairline),
                labelStyle: const TextStyle(color: AppColors.primaryDark),
                label: Text(entry.value),
                selected: _type == entry.key,
                onSelected: _busy
                    ? null
                    : (_) => setState(() {
                          _type = entry.key;
                          _result = null;
                        }))
        ]),
        const SizedBox(height: 18),
        _Period(
            value: _days,
            enabled: !_busy,
            onChanged: (v) => setState(() {
                  _days = v;
                  _result = null;
                })),
        const SizedBox(height: 16),
        TextField(
            controller: _instructions,
            enabled: !_busy,
            minLines: 2,
            maxLines: 3,
            maxLength: 600,
            decoration: const InputDecoration(
                labelText: 'Additional instructions (optional)',
                hintText:
                    'Focus on beginner exercises requiring minimal equipment.')),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: _busy || widget.repository == null ? null : _generate,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(_busy ? 'Analyzing…' : 'Generate suggestions')),
      ])),
      if (widget.repository == null)
        const _Notice(
            'AI assistance is unavailable for this session. Sign in with an authorized Admin account.'),
      if (_busy)
        const _Loading(
            'Gemini is analyzing your fitness content and workout trends...'),
      if (_error != null) _Notice(_error!, error: true),
      if (_result != null)
        _Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AI insights', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('${_result!['summary']}'),
          const SizedBox(height: 10),
          Text('${_result!['scope'] ?? ''}'),
          const SizedBox(height: 6),
          const Text(
              'Suggestions use GainPath data. Web research is not enabled.'),
          _AiMetrics(value: _result!['ai']),
        ])),
      if (!_busy && _result == null && _error == null)
        const _Notice(
            'Choose a content type to discover opportunities in your current catalog. You review and edit every draft before saving.'),
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000 &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.3
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(spacing: 16, runSpacing: 16, children: [
          for (final (index, draft) in suggestions.indexed)
            if (!_dismissed.contains(index))
              SizedBox(
                  width: width,
                  child: _PlannerCard(
                      draft: draft,
                      onApply: () => widget.onApply(context, draft),
                      onDismiss: () => setState(() => _dismissed.add(index)))),
        ]);
      }),
      if (_result != null && _dismissed.length == suggestions.length)
        const _Notice(
            'All suggestions dismissed. Generate again for fresh ideas.'),
    ]);
  }
}

class _PlannerCard extends StatelessWidget {
  const _PlannerCard(
      {required this.draft, required this.onApply, required this.onDismiss});
  final Map<String, dynamic> draft;
  final VoidCallback onApply, onDismiss;
  @override
  Widget build(BuildContext context) {
    final type = draft['type'];
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: .12))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            _PlannerTag(type == 'exercise'
                ? 'NEW MOVEMENT'
                : type == 'routine'
                    ? 'WORKOUT ROUTINE'
                    : 'TRAINING PROGRAM'),
            _PlannerTag('${draft['difficulty']}'),
            if (type == 'routine')
              _PlannerTag('${draft['durationMinutes']} min'),
            if (type == 'program') _PlannerTag('${draft['weeks']} weeks'),
          ]),
          const SizedBox(height: 12),
          Text('${draft['name']}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text('${draft['description']}'),
          const SizedBox(height: 14),
          Text('Content gap', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text('${draft['contentGap'] ?? ''}'),
          const SizedBox(height: 12),
          Text('AI recommendation reason',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text('${draft['whyRecommended'] ?? ''}'),
          const SizedBox(height: 12),
          Text('Supporting evidence',
              style: Theme.of(context).textTheme.labelLarge),
          for (final fact in (draft['evidence'] as List? ?? []).toSet())
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• $fact',
                    style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(height: 8),
          switch (type) {
            'exercise' => _ExercisePlannerDetails(draft),
            'routine' => _RoutinePlannerDetails(draft),
            _ => _ProgramPlannerDetails(draft),
          },
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 8, children: [
            FilledButton.icon(
                onPressed: onApply,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Apply suggestion')),
            TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
          ]),
        ]));
  }
}

class _PlannerTag extends StatelessWidget {
  const _PlannerTag(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.primary)));
}

class _ExercisePlannerDetails extends StatelessWidget {
  const _ExercisePlannerDetails(this.draft);
  final Map<String, dynamic> draft;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        Text('${draft['primaryMuscleGroup']} · ${draft['category']}'),
        Text('Equipment: ${draft['equipment']}'),
        if ('${draft['variantDifference'] ?? ''}'.isNotEmpty)
          Text('Distinct variant: ${draft['variantDifference']}'),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Preview details'),
            children: [
              for (final (i, step)
                  in (draft['instructions'] as List? ?? []).indexed)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('${i + 1}. $step'))),
            ]),
      ]);
}

class _RoutinePlannerDetails extends StatelessWidget {
  const _RoutinePlannerDetails(this.draft);
  final Map<String, dynamic> draft;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        Text(
            '${(draft['exercises'] as List? ?? []).length} exercises · ${draft['equipment']}'),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Preview details'),
            children: [
              for (final e in draft['exercises'] as List? ?? [])
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text('${e['name']}'),
                    subtitle: Text(
                        '${e['sets']} sets · ${e['reps']} ${e['executionMode'] == 'videoGuidedTimed' ? 'seconds' : 'reps'} · ${e['restSeconds']}s rest')),
            ]),
      ]);
}

class _ProgramPlannerDetails extends StatelessWidget {
  const _ProgramPlannerDetails(this.draft);
  final Map<String, dynamic> draft;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        Text(
            '${(draft['trainingDays'] as List? ?? []).length} training days per week · remaining days rest'),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Preview details'),
            children: [
              for (final day in draft['trainingDays'] as List? ?? [])
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text('${const [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun'
                    ][(day['weekday'] as int) - 1]} · ${day['routineName']}')),
            ]),
      ]);
}

String _experienceLabel(dynamic value) => switch (value) {
      'beginner' => 'Beginner',
      'intermediate' => 'Intermediate',
      'advanced' => 'Advanced',
      _ => 'Not recorded'
    };
String _goalLabel(dynamic goal) => switch (goal) {
      'increaseFlexibility' => 'Improve Flexibility',
      'generalFitness' => 'General Fitness',
      'buildMuscle' => 'Build Muscle',
      'loseWeight' => 'Lose Weight',
      'improveEndurance' => 'Improve Endurance',
      'reduceStress' => 'Reduce Stress',
      _ => '$goal',
    };

class AiMemberOutreachPage extends StatefulWidget {
  const AiMemberOutreachPage({super.key, this.repository});
  final AdminAiRepository? repository;
  @override
  State<AiMemberOutreachPage> createState() => _AiMemberOutreachPageState();
}

class _AiMemberOutreachPageState extends State<AiMemberOutreachPage> {
  int _days = 30, _epoch = 0;
  String? _homeBranchId;
  List<Map<String, dynamic>> _homeBranches = [];
  final _searchQuery = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searched = false, _nearGenerate = false;
  bool _busy = false;
  String? _error, _success;
  List<Map<String, dynamic>> _members = [];
  Map<String, dynamic>? _analysis, _preview;
  final _messages = <TextEditingController>[];
  final _selected = <int>{};
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _clearPreview() {
    for (final c in _messages) {
      c.dispose();
    }
    _messages.clear();
    _selected.clear();
    _preview = null;
  }

  @override
  void dispose() {
    _clearPreview();
    _searchQuery.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(int) operation,
      {bool generation = false}) async {
    if (_busy || widget.repository == null) return;
    final epoch = ++_epoch;
    setState(() {
      _busy = true;
      _nearGenerate = generation;
      _error = null;
      _success = null;
    });
    try {
      await operation(epoch);
    } catch (error) {
      if (mounted && epoch == _epoch) {
        setState(() => _error = _failure(error,
            'This action could not be completed. Check permissions and content availability. Your loaded analysis is retained.'));
      }
    } finally {
      if (mounted && epoch == _epoch) setState(() => _busy = false);
    }
  }

  Future<void> _load() => _run((epoch) async {
        final r = await widget.repository!.call('admin.ai.members', {
          'days': _days,
          if (_homeBranchId != null) 'branchId': _homeBranchId,
        });
        if (mounted && epoch == _epoch) {
          setState(() {
            _members = (r['members'] as List).map(aiMap).toList();
            _homeBranches = (r['branches'] as List? ?? []).map(aiMap).toList();
            _analysis = null;
            _clearPreview();
          });
        }
      });
  Future<void> _search() => _run((epoch) async {
        if (_searchQuery.text.trim().length < 2) {
          throw StateError('Enter at least two characters.');
        }
        final r = await widget.repository!.call('admin.ai.member.search', {
          'query': _searchQuery.text.trim(),
          if (_homeBranchId != null) 'branchId': _homeBranchId,
        });
        if (mounted && epoch == _epoch) {
          setState(() {
            _searched = true;
            _searchResults = (r['members'] as List? ?? []).map(aiMap).toList();
          });
        }
      });
  Future<void> _analyze(String member) => _run((epoch) async {
        setState(() {
          _analysis = null;
          _clearPreview();
        });
        final r = await widget.repository!
            .call('admin.ai.member', {'memberId': member, 'days': _days});
        if (mounted && epoch == _epoch) setState(() => _analysis = r);
      });
  Future<void> _generate() => _run((epoch) async {
        setState(_clearPreview);
        final r = await widget.repository!.call('admin.ai.outreach.generate', {
          'memberId': _analysis!['memberId'],
          'days': _days,
          'requestId': aiRequestId()
        });
        if (mounted && epoch == _epoch) {
          setState(() {
            _preview = r;
            for (final item in r['recommendations'] as List? ?? []) {
              _messages.add(TextEditingController(text: '${item['message']}'));
            }
          });
        }
      }, generation: true);
  Future<void> _send() => _run((epoch) async {
        await widget.repository!.call('admin.ai.outreach.send', {
          'previewId': _preview!['previewId'],
          'selections': [
            for (final i in _selected)
              {'index': i, 'message': _messages[i].text.trim()}
          ]
        });
        if (mounted && epoch == _epoch) {
          setState(() {
            _success =
                'Recommendations delivered to the member’s For You and Inbox.';
            _clearPreview();
          });
        }
      }, generation: true);
  String _date(dynamic value) => value is num
      ? DateTime.fromMillisecondsSinceEpoch(value.toInt())
          .toLocal()
          .toString()
          .substring(0, 16)
      : 'No recent workout';
  @override
  Widget build(BuildContext context) => _OutreachWorkspace(
        toolbar: _SharedAnalysisToolbar(
          days: _days,
          busy: _busy,
          homeBranchId: _homeBranchId,
          homeBranches: _homeBranches,
          onDaysChanged: (v) {
            setState(() => _days = v);
            _load();
          },
          onBranchChanged: (value) {
            setState(() {
              _homeBranchId = value == '' ? null : value;
              _searched = false;
              _searchResults = [];
              _members = [];
              _analysis = null;
              _clearPreview();
            });
            _load();
          },
          onRefresh: _busy ? null : _load,
        ),
        left: [
          _MemberDirectoryPanel(
            controller: _searchQuery,
            busy: _busy,
            nearGenerate: _nearGenerate,
            searched: _searched,
            searchResults: _searchResults,
            members: _members,
            days: _days,
            selectedMemberId: _analysis?['memberId']?.toString(),
            error: (_error != null && (!_nearGenerate || _analysis == null))
                ? _error
                : null,
            success: _success,
            onSearch: _search,
            onClearSearch: () => setState(() {
              _searched = false;
              _searchResults = [];
              _searchQuery.clear();
            }),
            onAnalyze: (id) => _analyze(id),
            dateFormatter: _date,
          ),
        ],
        right: [
          if (_analysis == null)
            const _Notice(
                'Select a member to review workout activity and generate recommendations.'),
          if (_analysis != null) ...[
            _MemberOverviewHeader(analysis: _analysis!, days: _days),
            _WorkoutMetricsGrid(
              workouts: (_analysis!['workouts'] as num?)?.toInt() ?? 0,
              completedRoutines:
                  (_analysis!['completedRoutines'] as num?)?.toInt() ?? 0,
              lastWorkout: _analysis!['lastWorkout'],
              days: _days,
              activityNote: _analysis!['activityNote'] is String
                  ? _analysis!['activityNote'] as String
                  : null,
              dateFormatter: _date,
            ),
            _ExerciseActivitySection(
              exercises: _analysis!['exercises'] as List? ?? [],
              routines: _analysis!['routines'] as List? ?? [],
              days: _days,
            ),
            _MuscleGroupActivitySection(
              muscleGroups: (_analysis!['muscleGroups'] is Map)
                  ? Map<String, dynamic>.from(
                      _analysis!['muscleGroups'] as Map)
                  : {},
            ),
            _ExistingRecommendationsSection(
                items: _analysis!['existing'] as List? ?? []),
            _GenerateAiActionCard(
              busy: _busy,
              nearGenerate: _nearGenerate,
              error: _error,
              onGenerate: _generate,
            ),
          ],
          if (_preview != null) ...[
            _RecommendationPreviewSection(
              preview: _preview!,
              selected: _selected,
              messages: _messages,
              busy: _busy,
              repository: widget.repository!,
              onToggleSelection: (index, selected) {
                setState(() {
                  selected ? _selected.add(index) : _selected.remove(index);
                });
              },
              onSend: _send,
            ),
            _AiMetrics(value: _preview!['ai']),
          ],
        ],
      );
}

class _SharedAnalysisToolbar extends StatelessWidget {
  const _SharedAnalysisToolbar({
    required this.days,
    required this.busy,
    required this.homeBranchId,
    required this.homeBranches,
    required this.onDaysChanged,
    required this.onBranchChanged,
    required this.onRefresh,
  });

  final int days;
  final bool busy;
  final String? homeBranchId;
  final List<Map<String, dynamic>> homeBranches;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<String?> onBranchChanged;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              ConstrainedBox(
                constraints:
                    const BoxConstraints(minWidth: 150, maxWidth: 190),
                child: _Period(
                  value: days,
                  enabled: !busy,
                  onChanged: onDaysChanged,
                ),
              ),
              if (homeBranches.isNotEmpty)
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 160, maxWidth: 220),
                  child: DropdownButtonFormField<String>(
                    initialValue: homeBranches
                            .any((branch) => branch['id'] == homeBranchId)
                        ? homeBranchId
                        : '',
                    decoration: const InputDecoration(labelText: 'Home branch'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('All Branches')),
                      for (final branch in homeBranches)
                        DropdownMenuItem(
                          value: branch['id'] as String,
                          child: Text(branch['name'] as String,
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: busy ? null : onBranchChanged,
                  ),
                ),
              IconButton(
                onPressed: onRefresh,
                tooltip: 'Reload members',
                icon: const Icon(Icons.refresh, color: AppColors.primary),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.hairline),
            ),
            child: const Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.verified_user_outlined,
                          size: 14, color: AppColors.primary),
                    ),
                  ),
                  TextSpan(
                    text: 'Consenting Active Cohort · Synthetic Excluded',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberDirectoryPanel extends StatelessWidget {
  const _MemberDirectoryPanel({
    required this.controller,
    required this.busy,
    required this.nearGenerate,
    required this.searched,
    required this.searchResults,
    required this.members,
    required this.days,
    required this.selectedMemberId,
    this.error,
    this.success,
    required this.onSearch,
    required this.onClearSearch,
    required this.onAnalyze,
    required this.dateFormatter,
  });

  final TextEditingController controller;
  final bool busy;
  final bool nearGenerate;
  final bool searched;
  final List<Map<String, dynamic>> searchResults;
  final List<Map<String, dynamic>> members;
  final int days;
  final String? selectedMemberId;
  final String? error;
  final String? success;
  final VoidCallback onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onAnalyze;
  final String Function(dynamic) dateFormatter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_alt_outlined,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Members',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: searched ? AppColors.infoTint : AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  searched
                      ? '${searchResults.length} results'
                      : '${members.length} active',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: searched ? AppColors.info : AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: TextField(
              controller: controller,
              enabled: !busy,
              maxLength: 80,
              buildCounter: (context,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  null,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
              style: const TextStyle(fontSize: 13, color: AppColors.ink),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                hintText: 'Search name, email or ID',
                hintStyle:
                    const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: AppColors.inkSoft),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 34, minHeight: 34),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (searched || controller.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close,
                            size: 15, color: AppColors.inkSoft),
                        splashRadius: 16,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 26, minHeight: 26),
                        onPressed: onClearSearch,
                      ),
                    IconButton(
                      tooltip: 'Search members',
                      icon: busy
                          ? const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Icon(Icons.arrow_forward_rounded,
                              size: 16, color: AppColors.primary),
                      splashRadius: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 26, minHeight: 26),
                      onPressed: busy ? null : onSearch,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                suffixIconConstraints: const BoxConstraints(minHeight: 34),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (busy && !nearGenerate)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Loading members...',
                      style: TextStyle(
                          fontSize: 11.5, color: AppColors.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
          if (error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.dangerTint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 14, color: AppColors.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          if (success != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.successTint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 14, color: AppColors.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      success!,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.success),
                    ),
                  ),
                ],
              ),
            ),
          if (searched)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Search Results',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
                TextButton(
                  onPressed: onClearSearch,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    visualDensity: VisualDensity.compact,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Back to Top 10',
                      style: TextStyle(fontSize: 11.5)),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Top 10 Most Active',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
                Text(
                  'Last $days days',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          if (searched) ...[
            if (searchResults.isEmpty && !busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                child: Center(
                  child: Text(
                    'No members matched your search.\nTry another name, email or ID.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.inkSoft, height: 1.4),
                  ),
                ),
              ),
            for (final m in searchResults)
              _SearchResultRow(
                member: m,
                isSelected: selectedMemberId == '${m['memberId']}',
                busy: busy,
                onAnalyze: onAnalyze,
              ),
          ] else ...[
            if (members.isEmpty && !busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                child: Center(
                  child: Text(
                    'No eligible workout activity in this period.\nOnly consenting members appear.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.inkSoft, height: 1.4),
                  ),
                ),
              ),
            for (final (index, m) in members.indexed)
              _TopActiveMemberRow(
                rank: index + 1,
                member: m,
                isSelected: selectedMemberId == '${m['memberId']}',
                busy: busy,
                onAnalyze: onAnalyze,
                dateFormatter: dateFormatter,
              ),
          ],
        ],
      ),
    );
  }
}

class _TopActiveMemberRow extends StatelessWidget {
  const _TopActiveMemberRow({
    required this.rank,
    required this.member,
    required this.isSelected,
    required this.busy,
    required this.onAnalyze,
    required this.dateFormatter,
  });

  final int rank;
  final Map<String, dynamic> member;
  final bool isSelected;
  final bool busy;
  final ValueChanged<String> onAnalyze;
  final String Function(dynamic) dateFormatter;

  @override
  Widget build(BuildContext context) {
    final memberId = '${member['memberId']}';
    final name = '${member['name']}';
    final workouts = (member['workouts'] as num?)?.toInt() ?? 0;
    final routines = (member['completedRoutines'] as num?)?.toInt() ?? 0;
    final lastWorkout = dateFormatter(member['lastWorkout']);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryTint.withValues(alpha: 0.6)
            : AppColors.surfaceAlt.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? AppColors.primarySoft
              : AppColors.hairline.withValues(alpha: 0.5),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: busy ? null : () => onAnalyze(memberId),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      isSelected ? AppColors.primary : AppColors.surfaceAlt,
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.ink,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Selected member',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$workouts workouts · $routines routine days',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.inkSoft,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Last: $lastWorkout',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.inkSoft,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Analyze member',
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  color: isSelected ? AppColors.primary : AppColors.inkSoft,
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: busy ? null : () => onAnalyze(memberId),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.member,
    required this.isSelected,
    required this.busy,
    required this.onAnalyze,
  });

  final Map<String, dynamic> member;
  final bool isSelected;
  final bool busy;
  final ValueChanged<String> onAnalyze;

  @override
  Widget build(BuildContext context) {
    final memberId = '${member['memberId']}';
    final name = '${member['name']}';
    final isTest = member['isTest'] == true;
    final canAnalyze = member['canAnalyze'] != false;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'M';
    final workouts = member['workouts'] as num?;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryTint.withValues(alpha: 0.6)
            : AppColors.surfaceAlt.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? AppColors.primarySoft
              : AppColors.hairline.withValues(alpha: 0.5),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: (busy || !canAnalyze) ? null : () => onAnalyze(memberId),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isSelected
                      ? AppColors.primary
                      : isTest
                          ? AppColors.warning.withValues(alpha: 0.15)
                          : AppColors.surfaceAlt,
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : isTest
                              ? AppColors.warning
                              : AppColors.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.ink,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Selected member',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (workouts != null)
                        Text(
                          '$workouts workouts · ${(member['completedRoutines'] as num?)?.toInt() ?? 0} routine days',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.inkSoft,
                          ),
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Text(
                          isTest
                              ? 'TEST account · excluded from ranking'
                              : !canAnalyze
                                  ? '${member['reason']}'
                                  : 'Available for analysis',
                          style: TextStyle(
                            fontSize: 11,
                            color: isTest
                                ? AppColors.warning
                                : AppColors.inkSoft,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Analyze search result',
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  color: isSelected ? AppColors.primary : AppColors.inkSoft,
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: (busy || !canAnalyze)
                      ? null
                      : () => onAnalyze(memberId),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberOverviewHeader extends StatelessWidget {
  const _MemberOverviewHeader({required this.analysis, required this.days});
  final Map<String, dynamic> analysis;
  final int days;

  @override
  Widget build(BuildContext context) {
    final name = '${analysis['name']}';
    final initials = name
        .trim()
        .split(' ')
        .map((s) => s.isNotEmpty ? s[0] : '')
        .take(2)
        .join()
        .toUpperCase();
    final goals = (analysis['goals'] as List? ?? []).map(_goalLabel).toList();
    final experience = _experienceLabel(analysis['experience']);
    final homeBranch = analysis['homeBranchName'] ?? 'Unassigned';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryTint,
                child: Text(
                  initials.isNotEmpty ? initials : 'M',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.primaryDark),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Branch: $homeBranch  •  Analysis window: $days days',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (goals.isNotEmpty || experience.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (experience.isNotEmpty)
                  _InfoBadge(
                    icon: Icons.fitness_center_rounded,
                    label: experience,
                    color: AppColors.primary,
                    bg: AppColors.primaryTint,
                  ),
                for (final g in goals)
                  _InfoBadge(
                    icon: Icons.track_changes_rounded,
                    label: g,
                    color: AppColors.info,
                    bg: AppColors.infoTint,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color == AppColors.inkSoft ? AppColors.ink : color,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutMetricsGrid extends StatelessWidget {
  const _WorkoutMetricsGrid({
    required this.workouts,
    required this.completedRoutines,
    required this.lastWorkout,
    required this.days,
    this.activityNote,
    required this.dateFormatter,
  });

  final int workouts;
  final int completedRoutines;
  final dynamic lastWorkout;
  final int days;
  final String? activityNote;
  final String Function(dynamic) dateFormatter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 500;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricKpiCard(
                width: isNarrow
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 24) / 3,
                icon: Icons.fitness_center_rounded,
                value: '$workouts',
                label: 'Recorded Workouts',
                sublabel: '$workouts workouts in window',
                iconColor: AppColors.primary,
                iconBg: AppColors.primaryTint,
              ),
              _MetricKpiCard(
                width: isNarrow
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 24) / 3,
                icon: Icons.event_available_rounded,
                value: '$completedRoutines',
                label: 'Completed Routine Days',
                sublabel: 'Structured schedules',
                iconColor: AppColors.info,
                iconBg: AppColors.infoTint,
              ),
              _MetricKpiCard(
                width: isNarrow
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 24) / 3,
                icon: Icons.history_rounded,
                value: dateFormatter(lastWorkout),
                label: 'Last Workout',
                sublabel: 'Verified session',
                iconColor: AppColors.accent,
                iconBg: AppColors.accentTint,
                valueSize: 13,
              ),
            ],
          );
        }),
        if (activityNote != null && activityNote!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activityNote!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.inkSoft, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricKpiCard extends StatelessWidget {
  const _MetricKpiCard({
    required this.width,
    required this.icon,
    required this.value,
    required this.label,
    required this.sublabel,
    required this.iconColor,
    required this.iconBg,
    this.valueSize = 22,
  });

  final double width;
  final IconData icon;
  final String value;
  final String label;
  final String sublabel;
  final Color iconColor;
  final Color iconBg;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: valueSize,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _ExerciseActivitySection extends StatelessWidget {
  const _ExerciseActivitySection({
    required this.exercises,
    required this.routines,
    required this.days,
  });

  final List<dynamic> exercises;
  final List<dynamic> routines;
  final int days;

  @override
  Widget build(BuildContext context) {
    final list = exercises.map(aiMap).toList();
    final maxCount = list
        .map((e) => (e['count'] as num?)?.toInt() ?? 0)
        .fold<int>(1, math.max);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fitness_center_rounded,
                      size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Recorded Exercise Activity',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.ink),
                  ),
                ],
              ),
              Text(
                'Last $days days',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Exercise workout session counts. Represents recorded appearances in verified workouts.',
            style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 14),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No recorded exercise activity in this period.',
                  style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
            )
          else
            Column(
              children: [
                for (final e in list) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${e['name']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                  color: AppColors.ink,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${e['count']} workouts',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            height: 7,
                            width: double.infinity,
                            color: AppColors.surfaceAlt,
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: (((e['count'] as num?)?.toInt() ?? 0) /
                                      maxCount)
                                  .clamp(0.04, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          if (routines.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.hairline),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.playlist_play_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Routine usage',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in routines.map(aiMap))
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Text(
                      '${r['name']}: ${r['count']} completed days',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MuscleGroupActivitySection extends StatelessWidget {
  const _MuscleGroupActivitySection({required this.muscleGroups});

  final Map<String, dynamic> muscleGroups;

  static const _palette = [
    Color(0xFF6D28D9), // Primary purple
    Color(0xFF8B5CF6), // Primary soft
    Color(0xFF2563EB), // Info blue
    Color(0xFF16A34A), // Success green
    Color(0xFFF59E0B), // Amber
    Color(0xFF0D9488), // Teal
    Color(0xFFEC4899), // Pink
    Color(0xFF64748B), // Slate
  ];

  Color _colorForIndex(int index) => _palette[index % _palette.length];

  @override
  Widget build(BuildContext context) {
    if (muscleGroups.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.hairline),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart_outline_rounded,
                    size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Muscle Group Activity',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.ink),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'No muscle group activity recorded in this period.',
              style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
            ),
          ],
        ),
      );
    }

    final entries = muscleGroups.entries
        .map((e) =>
            MapEntry(e.key.toString(), (e.value as num?)?.toInt() ?? 0))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pie_chart_outline_rounded,
                      size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Muscle Group Activity',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.ink),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$total recorded workouts',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Distribution of completed workout sessions across targeted muscle groups.',
            style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (final (index, entry) in entries.indexed)
                    if (entry.value > 0)
                      Expanded(
                        flex: entry.value,
                        child: Tooltip(
                          message:
                              '${entry.key}: ${entry.value} (${total > 0 ? (entry.value / total * 100).toStringAsFixed(0) : 0}%)',
                          child: Container(
                            color: _colorForIndex(index),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (index, entry) in entries.indexed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _colorForIndex(index),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.key,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.ink),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.value}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.primary),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${total > 0 ? (entry.value / total * 100).toStringAsFixed(0) : 0}%)',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExistingRecommendationsSection extends StatelessWidget {
  const _ExistingRecommendationsSection({required this.items});

  final List<dynamic> items;

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
      case 'delivered':
        return AppColors.success;
      case 'attention':
        return AppColors.warning;
      case 'dismissed':
      case 'expired':
        return AppColors.inkSoft;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = items.map(aiMap).toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.history_rounded,
                size: 18, color: AppColors.primary),
          ),
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Text(
                'Existing recommendations',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: AppColors.ink),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${list.length}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark),
                ),
              ),
            ],
          ),
          subtitle: const Text(
            'Past recommendations issued to this member',
            style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
          children: [
            const Divider(height: 1, color: AppColors.hairline),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Center(
                  child: Text(
                      'No previous recommendations recorded for this member.',
                      style:
                          TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
                ),
              )
            else
              for (final r in list) ...[
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  title: Text('${r['title']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13.5)),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor('${r['status']}')
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${r['status']}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _statusColor('${r['status']}'),
                      ),
                    ),
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _GenerateAiActionCard extends StatelessWidget {
  const _GenerateAiActionCard({
    required this.busy,
    required this.nearGenerate,
    required this.error,
    required this.onGenerate,
  });

  final bool busy;
  final bool nearGenerate;
  final String? error;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personalized AI Outreach',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Generate AI recommendations tailored to member activity, goals, and eligible content.',
                      style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : onGenerate,
            style: FilledButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: busy && nearGenerate
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Generate AI recommendations'),
          ),
          if (error != null && nearGenerate)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _Notice(error!, error: true),
            ),
        ],
      ),
    );
  }
}

class _RecommendationPreviewSection extends StatelessWidget {
  const _RecommendationPreviewSection({
    required this.preview,
    required this.selected,
    required this.messages,
    required this.busy,
    required this.repository,
    required this.onToggleSelection,
    required this.onSend,
  });

  final Map<String, dynamic> preview;
  final Set<int> selected;
  final List<TextEditingController> messages;
  final bool busy;
  final AdminAiRepository repository;
  final void Function(int index, bool selected) onToggleSelection;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final availabilityNotes = preview['availabilityNotes'] as List? ?? [];
    final recommendations =
        (preview['recommendations'] as List? ?? []).map(aiMap).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (availabilityNotes.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentTint,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.accentDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    availabilityNotes.join(' '),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.accentDark),
                  ),
                ),
              ],
            ),
          ),
        if (messages.isEmpty)
          _Notice(
              '${preview['message'] ?? 'No eligible recommendations are available.'}'),
        for (final (index, r) in recommendations.indexed) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            child: _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: selected.contains(index),
                        onChanged: busy
                            ? null
                            : (v) => onToggleSelection(index, v == true),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r['title']}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${r['kind'] == 'content' ? 'Tutorial' : r['kind'] == 'trainer' ? 'Coach' : 'Routine'} · Gemini',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _OutreachImage(
                    key: ValueKey(
                        '${preview['previewId']}:$index:${r['target']?['photoPath']}'),
                    target: aiMap(r['target']),
                    repository: repository,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messages[index],
                    enabled: !busy,
                    maxLength: 400,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Message to member',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${r['context'] ?? ''}',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.inkSoft)),
                  for (final why in r['why'] as List? ?? [])
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text('$why',
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.ink)),
                    ),
                  if (r['kind'] == 'trainer')
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Booking requires Basic or Premium membership. This recommendation does not create a booking.',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.inkSoft),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('${r['title']}'),
                        content: SingleChildScrollView(
                          child: Text(
                              '${r['target']?['specialization'] ?? ''}\n${r['context']}\n${r['why']}'),
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close')),
                        ],
                      ),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Preview details'),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (messages.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Text('${selected.length} selected',
                    style: Theme.of(context).textTheme.labelLarge),
                FilledButton.icon(
                  onPressed: busy || selected.isEmpty ? null : onSend,
                  icon: const Icon(Icons.send_outlined, size: 18),
                  label: Text(
                      'Send ${selected.length} recommendation${selected.length == 1 ? '' : 's'}'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _OutreachWorkspace extends StatelessWidget {
  const _OutreachWorkspace({
    this.toolbar,
    required this.left,
    required this.right,
  });

  final Widget? toolbar;
  final List<Widget> left, right;

  Widget _column(List<Widget> children) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final child in children)
          Padding(padding: const EdgeInsets.only(bottom: 14), child: child)
      ]);

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final wide = (size.maxWidth / scale) >= 860;
        return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_awesome,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Member Outreach',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Review member activity, personalize recommendations and send selected guidance.',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.inkSoft),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (toolbar != null) ...[
                    const SizedBox(height: 16),
                    toolbar!,
                  ],
                  const SizedBox(height: 18),
                  if (wide)
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 316, child: _column(left)),
                          const SizedBox(width: 20),
                          Expanded(child: _column(right)),
                        ])
                  else ...[
                    _column(left),
                    _column(right),
                  ],
                ]));
      });
}

class _AiScaffold extends StatelessWidget {
  const _AiScaffold({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(24), children: [
        Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final child in children)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: child)
                    ])))
      ]);
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.hairline)),
      child: child);
}

class _AiHeading extends StatelessWidget {
  const _AiHeading(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 4),
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge)
      ]);
}

class _Period extends StatelessWidget {
  const _Period(
      {required this.value, required this.enabled, required this.onChanged});
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Analysis period'),
      items: const [
        DropdownMenuItem(value: 7, child: Text('Last 7 days')),
        DropdownMenuItem(value: 30, child: Text('Last 30 days'))
      ],
      onChanged: enabled
          ? (v) {
              if (v != null) onChanged(v);
            }
          : null);
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.error = false});
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      child: _Panel(
          child: Text(text,
              style: TextStyle(
                  color: error ? Theme.of(context).colorScheme.error : null))));
}

class _Loading extends StatelessWidget {
  const _Loading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      child: Row(children: [
        const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 14),
        Expanded(child: Text(text))
      ]));
}

class _AiMetrics extends StatelessWidget {
  const _AiMetrics({required this.value});
  final dynamic value;
  @override
  Widget build(BuildContext context) => value is Map
      ? Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
              '${value['providerSource'] == 'mock_or_recorded' ? 'Fixture · ' : ''}${value['model']} · ${value['latencyMillis']} ms · ${value['totalTokens'] ?? 'Unknown'} tokens',
              style: Theme.of(context).textTheme.bodySmall))
      : const SizedBox.shrink();
}

class _OutreachImage extends StatefulWidget {
  const _OutreachImage(
      {super.key,
      required this.target,
      required this.repository});
  final Map<String, dynamic> target;
  final AdminAiRepository repository;
  @override
  State<_OutreachImage> createState() => _OutreachImageState();
}

class _OutreachImageState extends State<_OutreachImage> {
  late final Future<Uint8List?>? _photo =
      widget.target['photoPath'] is String ? _load() : null;
  Future<Uint8List?> _load() async {
    final nestedTarget = widget.target['target'];
    if (nestedTarget != null && nestedTarget is! Map) return null;
    final coachId =
        (nestedTarget as Map?)?['coachId'] ?? widget.target['coachId'];
    if (coachId is! String) return null;
    return widget.repository
        .loadCoachPhoto(coachId, widget.target['photoPath'] as String);
  }

  Widget get _placeholder => SizedBox(
      height: 68,
      child: Center(
          child: Icon(
              _photo == null ? Icons.fitness_center : Icons.person_outline,
              color: AppColors.primary)));
  @override
  Widget build(BuildContext context) {
    if (_photo != null) {
      return FutureBuilder<Uint8List?>(
          future: _photo,
          builder: (context, snapshot) => snapshot.data == null
              ? _placeholder
              : Align(
                  alignment: Alignment.centerLeft,
                  child: ClipOval(
                      child: Image.memory(snapshot.data!,
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder))));
    }
    final url = widget.target['imageUrl'];
    if (url is! String || url.isEmpty) return _placeholder;
    return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(url,
            height: 140,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder));
  }
}
