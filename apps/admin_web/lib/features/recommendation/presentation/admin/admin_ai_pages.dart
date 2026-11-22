import 'package:flutter/material.dart';
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
  Widget build(BuildContext context) => _OutreachWorkspace(left: [
        Row(children: [
          Expanded(
              child: _Period(
                  value: _days,
                  enabled: !_busy,
                  onChanged: (v) {
                    setState(() => _days = v);
                    _load();
                  })),
          const SizedBox(width: 12),
          IconButton(
              onPressed: _busy ? null : _load,
              tooltip: 'Reload members',
              icon: const Icon(Icons.refresh))
        ]),
        if (_homeBranches.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: _homeBranches.any((branch) => branch['id'] == _homeBranchId)
                ? _homeBranchId
                : '',
            decoration: const InputDecoration(labelText: 'Home branch'),
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: '', child: Text('All Branches')),
              for (final branch in _homeBranches)
                DropdownMenuItem(
                  value: branch['id'] as String,
                  child: Text(branch['name'] as String, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _busy ? null : (value) {
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
          ),
        _Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Search members',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Search by name, email or member ID.'),
          const SizedBox(height: 12),
          TextField(
              controller: _searchQuery,
              enabled: !_busy,
              maxLength: 80,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(
                  labelText: 'Member name, email or ID',
                  prefixIcon: Icon(Icons.search))),
          const SizedBox(height: 8),
          OutlinedButton.icon(
              onPressed: _busy ? null : _search,
              icon: const Icon(Icons.search),
              label: const Text('Search members')),
          if (_searched && _searchResults.isEmpty)
            const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                    'No active members matched. Try another name, email or member ID.')),
          for (final m in _searchResults)
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${m['name']}'),
                subtitle: Text(m['isTest'] == true
                    ? 'TEST account · excluded from activity ranking'
                    : m['canAnalyze'] == false
                        ? '${m['reason']}'
                        : 'Available for analysis'),
                trailing: IconButton(
                    tooltip: 'Analyze search result',
                    onPressed: _busy || m['canAnalyze'] == false
                        ? null
                        : () => _analyze('${m['memberId']}'),
                    icon: const Icon(Icons.arrow_forward))),
        ])),
        if (_busy)
          const _Loading(
              'Loading confirmed data. AI runs only when you select Generate.'),
        if (_error != null && (!_nearGenerate || _analysis == null))
          _Notice(_error!, error: true),
        if (_success != null) _Notice(_success!),
        _Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Top 10 most active members',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
              'Completed workout summaries · last $_days days · test and synthetic activity excluded'),
          const SizedBox(height: 16),
          if (_members.isEmpty && !_busy)
            const Text(
                'No eligible workout activity in this period. Only authorized, consenting members with real completed summaries appear.'),
          Column(children: [
            for (final (index, m) in _members.indexed)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                          backgroundColor: AppColors.surfaceAlt,
                          child: Text('${index + 1}')),
                      title: Text('${m['name']}'),
                      subtitle: Text(
                          '${(m['goals'] as List? ?? []).map(_goalLabel).join(', ')}\n${m['workouts']} workouts · ${m['completedRoutines']} completed routine days\nLast workout ${_date(m['lastWorkout'])}'),
                      isThreeLine: true,
                      trailing: IconButton(
                          tooltip: 'Analyze member',
                          onPressed:
                              _busy ? null : () => _analyze('${m['memberId']}'),
                          icon: const Icon(Icons.arrow_forward)),
                      onTap:
                          _busy ? null : () => _analyze('${m['memberId']}'))),
          ]),
        ])),
        if (_analysis != null)
          _Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Selected member',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Text('${_analysis!['name']}',
                    style: Theme.of(context).textTheme.titleMedium),
                Text('Home branch: ${_analysis!['homeBranchName'] ?? 'Unassigned'}'),
                Text(
                    'Goal: ${(_analysis!['goals'] as List? ?? []).map(_goalLabel).join(', ')}'),
                Text(
                    'Experience: ${_experienceLabel(_analysis!['experience'])}'),
              ])),
      ], right: [
        if (_analysis == null)
          const _Notice(
              'Select a member to review workout activity and generate recommendations.'),
        if (_analysis != null)
          _Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('${_analysis!['name']}',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                    '${(_analysis!['goals'] as List? ?? []).map(_goalLabel).join(' · ')}  •  ${_experienceLabel(_analysis!['experience'])}'),
                const SizedBox(height: 8),
                Text(
                    '${_analysis!['workouts']} workouts / $_days days · ${_analysis!['completedRoutines']} completed routine days'),
                if (_analysis!['activityNote'] is String)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('${_analysis!['activityNote']}',
                          style: Theme.of(context).textTheme.bodySmall)),
                for (final e in _analysis!['exercises'] as List? ?? [])
                  ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${e['name']}'),
                      trailing: Text('${e['count']} workouts')),
                if ((_analysis!['routines'] as List? ?? []).isNotEmpty)
                  const Text('Routine usage'),
                for (final r in _analysis!['routines'] as List? ?? [])
                  Text('${r['name']}: ${r['count']} completed days'),
                if ((_analysis!['muscleGroups'] as Map? ?? {}).isNotEmpty)
                  Text('Muscle group activity: ${_analysis!['muscleGroups']}'),
                ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Existing recommendations'),
                    children: [
                      for (final r in _analysis!['existing'] as List? ?? [])
                        ListTile(
                            dense: true,
                            title: Text('${r['title']}'),
                            subtitle: Text('${r['status']}'))
                    ]),
                const SizedBox(height: 12),
                FilledButton.icon(
                    onPressed: _busy ? null : _generate,
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16)),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Generate AI recommendations')),
                if (_error != null && _nearGenerate)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _Notice(_error!, error: true)),
              ])),
        if (_preview != null) ...[
          if ((_preview!['availabilityNotes'] as List? ?? []).isNotEmpty)
            Text((_preview!['availabilityNotes'] as List).join(' '),
                style: Theme.of(context).textTheme.bodySmall),
          if (_messages.isEmpty)
            _Notice(
                '${_preview!['message'] ?? 'No eligible recommendations are available.'}'),
          for (final (index, r)
              in (_preview!['recommendations'] as List? ?? []).indexed)
            _Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _selected.contains(index),
                      onChanged: _busy
                          ? null
                          : (v) => setState(() {
                                v == true
                                    ? _selected.add(index)
                                    : _selected.remove(index);
                              }),
                      title: Text('${r['title']}',
                          style: Theme.of(context).textTheme.titleMedium),
                      subtitle: Text(
                          '${r['kind'] == 'content' ? 'Tutorial' : r['kind'] == 'trainer' ? 'Coach' : 'Routine'} · Gemini')),
                  _OutreachImage(
                      key: ValueKey(
                          '${_preview!['previewId']}:$index:${r['target']?['photoPath']}'),
                      target: aiMap(r['target']),
                      repository: widget.repository!),
                  TextField(
                      controller: _messages[index],
                      enabled: !_busy,
                      maxLength: 400,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                          labelText: 'Message to member')),
                  Text('${r['context'] ?? ''}'),
                  for (final why in r['why'] as List? ?? [])
                    Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text('$why')),
                  if (r['kind'] == 'trainer')
                    const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                            'Booking requires Basic or Premium membership. This recommendation does not create a booking.')),
                  TextButton.icon(
                      onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => AlertDialog(
                                  title: Text('${r['title']}'),
                                  content: SingleChildScrollView(
                                      child: Text(
                                          '${r['target']?['specialization'] ?? ''}\n${r['context']}\n${r['why']}')),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Close'))
                                  ])),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Preview details')),
                ])),
          if (_messages.isNotEmpty)
            Text('${_selected.length} selected',
                style: Theme.of(context).textTheme.labelLarge),
          if (_messages.isNotEmpty)
            Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                    onPressed: _busy || _selected.isEmpty ? null : _send,
                    icon: const Icon(Icons.send_outlined, size: 18),
                    label: Text(
                        'Send ${_selected.length} recommendation${_selected.length == 1 ? '' : 's'}'))),
          _AiMetrics(value: _preview!['ai']),
        ],
      ]);
}

class _OutreachWorkspace extends StatelessWidget {
  const _OutreachWorkspace({required this.left, required this.right});
  final List<Widget> left, right;
  Widget _column(List<Widget> children) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final child in children)
          Padding(padding: const EdgeInsets.only(bottom: 14), child: child)
      ]);
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
        final wide = size.maxWidth >= 1000 &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.3;
        return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('AI Member Outreach',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  const Text(
                      'Review member activity, personalize recommendations and send selected guidance.'),
                  const SizedBox(height: 18),
                  if (wide)
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 340, child: _column(left)),
                          const SizedBox(width: 20),
                          Expanded(child: _column(right)),
                        ])
                  else ...[_column(left), _column(right)],
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
