import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/admin_ai_repository.dart';
import '../../../workout/presentation/admin/exercise_tutorials_screen.dart';
import '../../../workout/presentation/admin/routine_templates_screen.dart';
import '../../../workout/presentation/admin/workout_programs_screen.dart';

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
  const AiContentPlannerPage({super.key, this.repository, this.onApply});
  final AdminAiRepository? repository;
  final Future<void> Function(BuildContext, Map<String, dynamic>)? onApply;
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

  Future<void> _apply(Map<String, dynamic> draft) async {
    if (widget.onApply != null) {
      await widget.onApply!(context, draft);
      return;
    }
    final Widget form = switch (draft['type']) {
      'exercise' => ExerciseTutorialsScreen(initialAiDraft: draft),
      'routine' => RoutineTemplatesScreen(initialAiDraft: draft),
      _ => WorkoutProgramsScreen(initialAiDraft: draft),
    };
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Review AI draft')), body: form)));
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
      for (final (index, draft) in suggestions.indexed)
        if (!_dismissed.contains(index))
          _Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  Chip(label: Text('${draft['type']}'.toUpperCase())),
                  Chip(label: Text('${draft['difficulty']}')),
                  Chip(label: Text('${draft['durationMinutes']} min'))
                ]),
                const SizedBox(height: 8),
                Text('${draft['name']}',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('${draft['description']}'),
                const SizedBox(height: 12),
                Text(
                    '${(draft['muscleGroups'] as List? ?? []).join(' · ')}  •  ${draft['equipment']}'),
                const SizedBox(height: 12),
                Text('Why this suggestion',
                    style: Theme.of(context).textTheme.titleMedium),
                if (draft['whyRecommended'] != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('${draft['whyRecommended']}')),
                for (final fact in draft['evidence'] as List? ?? [])
                  Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text('$fact')),
                ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Preview details'),
                    children: [
                      for (final step in draft['instructions'] as List? ?? [])
                        ListTile(dense: true, title: Text('$step')),
                      for (final e in draft['exercises'] as List? ?? [])
                        ListTile(
                            dense: true,
                            title: Text('${e['name']}'),
                            subtitle: Text(
                                '${e['sets']} sets · ${e['reps']} ${e['executionMode'] == 'videoGuidedTimed' ? 'seconds' : 'reps'} · ${e['restSeconds']}s rest')),
                      for (final id in draft['routineIds'] as List? ?? [])
                        ListTile(
                            dense: true, title: Text('Published routine: $id')),
                    ]),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  FilledButton.icon(
                      onPressed: () => _apply(draft),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Apply suggestion')),
                  TextButton(
                      onPressed: () => setState(() => _dismissed.add(index)),
                      child: const Text('Dismiss'))
                ]),
              ])),
      if (_result != null && _dismissed.length == suggestions.length)
        const _Notice(
            'All suggestions dismissed. Generate again for fresh ideas.'),
    ]);
  }
}

class AiMemberOutreachPage extends StatefulWidget {
  const AiMemberOutreachPage({super.key, this.repository});
  final AdminAiRepository? repository;
  @override
  State<AiMemberOutreachPage> createState() => _AiMemberOutreachPageState();
}

class _AiMemberOutreachPageState extends State<AiMemberOutreachPage> {
  int _days = 30, _epoch = 0;
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
    super.dispose();
  }

  Future<void> _run(Future<void> Function(int) operation) async {
    if (_busy || widget.repository == null) return;
    final epoch = ++_epoch;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await operation(epoch);
    } catch (error) {
      if (mounted && epoch == _epoch) {
        setState(() => _error = _failure(error,
            'This action could not be completed. Confirm permissions, content availability and cooldown, then retry.'));
      }
    } finally {
      if (mounted && epoch == _epoch) setState(() => _busy = false);
    }
  }

  Future<void> _load() => _run((epoch) async {
        final r =
            await widget.repository!.call('admin.ai.members', {'days': _days});
        if (mounted && epoch == _epoch) {
          setState(() {
            _members = (r['members'] as List).map(aiMap).toList();
            _analysis = null;
            _clearPreview();
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
      });
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
      });
  String _date(dynamic value) => value is num
      ? DateTime.fromMillisecondsSinceEpoch(value.toInt())
          .toLocal()
          .toString()
          .substring(0, 16)
      : 'No recent workout';
  @override
  Widget build(BuildContext context) => _AiScaffold(children: [
        const _AiHeading(
            icon: Icons.people_alt_outlined,
            title: 'AI Member Outreach',
            subtitle:
                'Identify active members and generate personalized fitness recommendations.'),
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
        if (_busy)
          const _Loading(
              'Loading confirmed data. AI runs only when you select Generate.'),
        if (_error != null) _Notice(_error!, error: true),
        if (_success != null) _Notice(_success!),
        _Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Top 10 most active members',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
              'Completed workout summaries · last $_days days · test and synthetic activity excluded'),
          const SizedBox(height: 16),
          if (_members.isEmpty && !_busy)
            const Text(
                'No eligible workout activity in this period. Only authorized, consenting members with real completed summaries appear.'),
          LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth >= 850
                  ? SizedBox(
                      width: double.infinity,
                      child: DataTable(
                          headingTextStyle:
                              Theme.of(context).textTheme.titleMedium,
                          dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                          headingRowHeight: 44,
                          dataRowMinHeight: 60,
                          dataRowMaxHeight: 70,
                          columnSpacing: 22,
                          horizontalMargin: 0,
                          columns: const [
                            DataColumn(label: Text('#')),
                            DataColumn(label: Text('Member / Goal')),
                            DataColumn(label: Text('Workouts')),
                            DataColumn(label: Text('Routine days')),
                            DataColumn(label: Text('Last workout')),
                            DataColumn(label: Text(''))
                          ],
                          rows: [
                            for (final (index, m) in _members.indexed)
                              DataRow(cells: [
                                DataCell(Text('${index + 1}')),
                                DataCell(Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${m['name']}'),
                                      Text(
                                          (m['goals'] as List? ?? [])
                                              .join(', '),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall)
                                    ])),
                                DataCell(Text('${m['workouts']}')),
                                DataCell(Text('${m['completedRoutines']}')),
                                DataCell(Text(_date(m['lastWorkout']))),
                                DataCell(IconButton(
                                    tooltip: 'Analyze member',
                                    onPressed: _busy
                                        ? null
                                        : () => _analyze('${m['memberId']}'),
                                    icon: const Icon(Icons.arrow_forward)))
                              ])
                          ]))
                  : Column(children: [
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
                                    '${(m['goals'] as List? ?? []).join(', ')}\n${m['workouts']} workouts · ${m['completedRoutines']} completed routine days\nLast workout ${_date(m['lastWorkout'])}'),
                                isThreeLine: true,
                                trailing: IconButton(
                                    tooltip: 'Analyze member',
                                    onPressed: _busy
                                        ? null
                                        : () => _analyze('${m['memberId']}'),
                                    icon: const Icon(Icons.arrow_forward)),
                                onTap: _busy
                                    ? null
                                    : () => _analyze('${m['memberId']}'))),
                    ])),
        ])),
        if (_analysis != null)
          _Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('${_analysis!['name']}',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                    '${(_analysis!['goals'] as List? ?? []).join(' · ')}  •  ${_analysis!['experience'] ?? 'Experience not recorded'}'),
                const SizedBox(height: 8),
                Text(
                    '${_analysis!['workouts']} workouts / $_days days · ${_analysis!['completedRoutines']} completed routine days'),
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
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Generate AI recommendations')),
              ])),
        if (_preview != null) ...[
          _AiMetrics(value: _preview!['ai']),
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
                          style: Theme.of(context).textTheme.titleLarge),
                      subtitle: Text(
                          '${r['kind'] == 'content' ? 'Tutorial' : r['kind'] == 'trainer' ? 'Coach' : 'Routine'} · Gemini')),
                  _OutreachImage(
                      key: ValueKey(
                          '${_preview!['previewId']}:$index:${r['target']?['photoPath']}'),
                      target: aiMap(r['target'])),
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
            Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                    onPressed: _busy || _selected.isEmpty ? null : _send,
                    icon: const Icon(Icons.send_outlined, size: 18),
                    label: Text(
                        'Send ${_selected.length} recommendation${_selected.length == 1 ? '' : 's'}'))),
        ],
      ]);
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
  const _OutreachImage({super.key, required this.target});
  final Map<String, dynamic> target;
  @override
  State<_OutreachImage> createState() => _OutreachImageState();
}

class _OutreachImageState extends State<_OutreachImage> {
  late final Future<Uint8List?>? _photo =
      widget.target['photoPath'] is String ? _load() : null;
  Future<Uint8List?> _load() async {
    try {
      return await FirebaseStorage.instance
          .ref(widget.target['photoPath'] as String)
          .getData(5 * 1024 * 1024);
    } catch (_) {
      return null;
    }
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
                          width: 64, height: 64, fit: BoxFit.cover))));
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
