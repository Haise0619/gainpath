import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/workout.dart';
import '../../domain/admin_workout_program_repository.dart';

String _requestId() => List.generate(16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
    .join();

/// Programs assign existing published routine days. Recognition remains the
/// developer registry's responsibility; targets are authored in Routine Builder.
class WorkoutProgramsScreen extends StatefulWidget {
  const WorkoutProgramsScreen(
      {super.key, this.repository, this.onOpenRoutineBuilder});
  final AdminWorkoutProgramRepository? repository;
  final VoidCallback? onOpenRoutineBuilder;
  @override
  State<WorkoutProgramsScreen> createState() => _WorkoutProgramsScreenState();
}

class _WorkoutProgramsScreenState extends State<WorkoutProgramsScreen> {
  AdminWorkoutProgramRepository? _repository;
  AdminProgramCatalog? _catalog;
  Map<String, dynamic>? _editing;
  final _title = TextEditingController();
  int _revision = 0, _week = 1, _generation = 0;
  bool _busy = false, _dirty = false;
  String? _error, _notice, _saveRequest, _publishRequest;
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  void _resolve() {
    try {
      _repository =
          widget.repository ?? context.read<AdminWorkoutProgramRepository>();
    } catch (_) {
      _repository = null;
    }
    _load();
  }

  @override
  void didUpdateWidget(WorkoutProgramsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _editing = null;
      _catalog = null;
      _resolve();
    }
  }

  @override
  void dispose() {
    _generation++;
    _title.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation, repository = _repository;
    if (repository == null || !repository.current) {
      setState(
          () => _error = 'Program management is unavailable for this session.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final catalog = await repository.load();
      if (!mounted || generation != _generation || !repository.current) return;
      setState(() {
        _catalog = catalog;
        _editing = null;
        _notice = null;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error =
            'Programs could not be loaded. Retry to use confirmed server data.');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  void _edit(WorkoutProgram program, int revision) {
    final data = program.toJson();
    data['version'] = 0;
    data['days'] = (data['days'] as List)
        .map((e) =>
            Map<String, dynamic>.from(e as Map)..remove('routineSnapshot'))
        .toList();
    setState(() {
      _editing = data;
      _title.text = data['title'] as String;
      _revision = revision;
      _week = 1;
      _dirty = revision == 0;
      _error = null;
      _notice = null;
      _saveRequest = null;
      _publishRequest = null;
    });
  }

  void _changed() {
    _dirty = true;
    _saveRequest = null;
    _publishRequest = null;
    _notice = null;
  }

  String _failure(Object error) {
    if (error is FormatException) return error.message;
    return 'The change could not be confirmed. Retry, or reload if another editor changed this Program.';
  }

  Future<void> _save() async {
    final repository = _repository;
    if (_busy || repository == null || !repository.current) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _editing!['title'] = _title.text.trim();
      final program = WorkoutProgram.fromJson(_editing!);
      program.validate();
      final revision = await repository.saveDraft(program,
          expectedRevision: _revision,
          requestId: _saveRequest ??= _requestId());
      if (!mounted || generation != _generation || !repository.current) return;
      setState(() {
        _revision = revision;
        _dirty = false;
        _saveRequest = null;
        _publishRequest = null;
        _notice =
            'Draft saved. Publish when all workout days have a published Routine.';
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = _failure(error));
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    final repository = _repository;
    if (_busy ||
        _dirty ||
        _revision == 0 ||
        repository == null ||
        !repository.current) {
      return;
    }
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      for (final day in _editing!['days'] as List) {
        if (day['kind'] == 'workout' &&
            (day['routineId'] == null || day['routineId'] == '')) {
          throw const FormatException(
              'Assign a published Routine to every workout day before publishing.');
        }
      }
      final result = await repository.publish(_editing!['id'] as String,
          expectedRevision: _revision,
          requestId: _publishRequest ??= _requestId());
      if (!mounted || generation != _generation || !repository.current) return;
      setState(() {
        _revision = result.revision;
        _publishRequest = null;
        _notice =
            'Published version ${result.program.version}. Existing Member versions and progress are preserved.';
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = _failure(error));
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _editDay(int index) async {
    if (_busy) return;
    final original =
        Map<String, dynamic>.from((_editing!['days'] as List)[index] as Map);
    final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) =>
            _ProgramDayDialog(day: original, routines: _catalog!.routines));
    if (result == null || !mounted) return;
    setState(() {
      (_editing!['days'] as List)[index] = result;
      _changed();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_repository != null && !_repository!.current) {
      return const Center(
          child: Text(
              'Your editing session changed. Sign in again to manage Programs.'));
    }
    final editing = _editing;
    return ListView(padding: const EdgeInsets.all(24), children: [
      Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Workout Programs',
                style: Theme.of(context).textTheme.headlineSmall),
            OutlinedButton.icon(
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reload')),
            if (widget.onOpenRoutineBuilder != null)
              OutlinedButton.icon(
                  onPressed: _busy ? null : widget.onOpenRoutineBuilder,
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Routine Builder')),
          ]),
      const SizedBox(height: 12),
      const Text(
          'Build four-week training schedules from published Routines. Exercise order, sets and reps are managed in Routine Builder; Programs choose the routine day and rest target.'),
      if (_busy)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator()),
      if (_error != null)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              if (_catalog == null)
                OutlinedButton(
                    onPressed: _busy ? null : _load,
                    child: const Text('Retry')),
            ])),
      if (_notice != null)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_notice!, semanticsLabel: _notice)),
      if (_catalog != null && editing == null) ..._catalogView(),
      if (editing != null) ..._editorView(editing),
    ]);
  }

  List<Widget> _catalogView() => [
        const SizedBox(height: 24),
        Text('Start a Program', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final program in WorkoutProgram.templates())
            OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () {
                        final data = program.toJson();
                        data['id'] = 'program_${_requestId()}';
                        _edit(WorkoutProgram.fromJson(data), 0);
                      },
                icon: const Icon(Icons.add),
                label: Text(
                    '${program.level} · ${program.level == 'Beginner' ? 3 : program.level == 'Intermediate' ? 4 : 5} days/week')),
        ]),
        const SizedBox(height: 24),
        Text('Saved drafts', style: Theme.of(context).textTheme.titleLarge),
        if (_catalog!.drafts.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No saved Program drafts.')),
        for (final draft in _catalog!.drafts)
          Card(
              child: ListTile(
                  title: Text(draft.program.title),
                  subtitle: Text(
                      '${draft.program.level} · revision ${draft.revision}'),
                  trailing: TextButton(
                      onPressed: () => _edit(draft.program, draft.revision),
                      child: const Text('Edit')))),
        const SizedBox(height: 24),
        Text('Published Programs',
            style: Theme.of(context).textTheme.titleLarge),
        if (_catalog!.programs.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                  'No published Programs. Members see only server-published versions.')),
        for (final program in _catalog!.programs)
          Card(
              child: ListTile(
                  title: Text(program.title),
                  subtitle: Text(
                      '${program.level} · version ${program.version} · four weeks'))),
      ];
  List<Widget> _editorView(Map<String, dynamic> data) => [
        const SizedBox(height: 24),
        TextField(
            controller: _title,
            enabled: !_busy,
            onChanged: (_) => setState(_changed),
            decoration: const InputDecoration(labelText: 'Program title')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
            initialValue: data['level'] as String,
            decoration: const InputDecoration(labelText: 'Training level'),
            items: [
              for (final level in ['Beginner', 'Intermediate', 'Advanced'])
                DropdownMenuItem(value: level, child: Text(level))
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() {
                      data['level'] = value!;
                      _changed();
                    })),
        const SizedBox(height: 16),
        Wrap(spacing: 8, children: [
          for (var week = 1; week <= 4; week++)
            ChoiceChip(
                label: Text('Week $week'),
                selected: _week == week,
                onSelected: _busy ? null : (_) => setState(() => _week = week))
        ]),
        const SizedBox(height: 12),
        for (var index = 0; index < (data['days'] as List).length; index++)
          if ((data['days'] as List)[index]['week'] == _week)
            _dayCard(index, (data['days'] as List)[index]),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: [
          FilledButton(
              onPressed: _busy ? null : _save, child: const Text('Save draft')),
          FilledButton.icon(
              onPressed: _busy || _dirty || _revision == 0 ? null : _publish,
              icon: const Icon(Icons.publish),
              label: const Text('Publish version')),
          OutlinedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      if (_dirty) {
                        final discard = await showDialog<bool>(
                            context: context,
                            builder: (dialog) => AlertDialog(
                                    title:
                                        const Text('Discard unsaved changes?'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialog, false),
                                          child: const Text('Keep editing')),
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialog, true),
                                          child: const Text('Discard'))
                                    ]));
                        if (discard != true || !mounted) return;
                      }
                      await _load();
                    },
              child: const Text('Back to Programs')),
        ]),
        const SizedBox(height: 12),
        const Text(
            'Publication checks routine assignments and consecutive muscle-group recovery. Save changes before publishing. Publishing creates a new version and preserves prior versions.'),
      ];
  Widget _dayCard(int index, Map day) {
    final routine =
        _catalog!.routines.where((e) => e.id == day['routineId']).firstOrNull;
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                        '${weekdays[(day['weekday'] as int) - 1]} · ${day['category']}',
                        style: Theme.of(context).textTheme.titleMedium),
                    TextButton(
                        onPressed: _busy ? null : () => _editDay(index),
                        child: const Text('Edit day')),
                  ]),
              Text(day['kind'] == 'workout'
                  ? '${routine?.title ?? 'Choose a published Routine'} · routine day ${day['routineDay'] ?? 1} · ${day['restSeconds'] ?? 60}s rest'
                  : day['kind'] == 'activeRecovery'
                      ? 'Active Recovery · no workout completion is inferred'
                      : 'Rest Day'),
              if (routine != null && day['kind'] == 'workout') ...[
                const SizedBox(height: 8),
                for (final exercise in (routine.snapshot['exercises'] as List)
                    .where((e) =>
                        (e['dayNumber'] ?? 1) == (day['routineDay'] ?? 1)))
                  Text(
                      '${exercise['name']} · ${exercise['sets']} sets × ${exercise['reps']} reps'),
              ],
            ])));
  }
}

class _ProgramDayDialog extends StatefulWidget {
  const _ProgramDayDialog({required this.day, required this.routines});
  final Map<String, dynamic> day;
  final List<ProgramRoutineChoice> routines;
  @override
  State<_ProgramDayDialog> createState() => _ProgramDayDialogState();
}

class _ProgramDayDialogState extends State<_ProgramDayDialog> {
  late final Map<String, dynamic> _day = Map.of(widget.day);
  late final _rest =
      TextEditingController(text: '${_day['restSeconds'] ?? 60}');
  String? _error;
  static const categories = [
    'Full Body',
    'Upper Body',
    'Lower Body',
    'Push',
    'Pull',
    'Legs'
  ];
  @override
  void dispose() {
    _rest.dispose();
    super.dispose();
  }

  void _category(String category) {
    _day['category'] = category;
    _day['muscleGroups'] = switch (category) {
      'Full Body' => ['upperPush', 'upperPull', 'lower'],
      'Upper Body' => ['upperPush', 'upperPull'],
      'Push' => ['upperPush'],
      'Pull' => ['upperPull'],
      'Lower Body' || 'Legs' => ['lower'],
      _ => <String>[],
    };
  }

  void _save() {
    final rest = int.tryParse(_rest.text);
    if (rest == null || rest < 0 || rest > 600) {
      setState(
          () => _error = 'Rest must be a whole number from 0 to 600 seconds.');
      return;
    }
    _day['restSeconds'] = rest;
    Navigator.pop(context, _day);
  }

  @override
  Widget build(BuildContext context) {
    final routine =
        widget.routines.where((r) => r.id == _day['routineId']).firstOrNull;
    return AlertDialog(
        title: const Text('Schedule day'),
        content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                  initialValue: _day['kind'] as String,
                  decoration: const InputDecoration(labelText: 'Day type'),
                  items: [
                    for (final e in const {
                      'workout': 'Workout Day',
                      'activeRecovery': 'Active Recovery',
                      'rest': 'Rest Day'
                    }.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value))
                  ],
                  onChanged: (value) => setState(() {
                        _day['kind'] = value!;
                        if (value == 'workout') {
                          _category('Full Body');
                        } else {
                          _day['category'] =
                              value == 'rest' ? 'Rest' : 'Active Recovery';
                          _day['muscleGroups'] = <String>[];
                          _day.remove('routineId');
                          _day.remove('routineSnapshot');
                          _day['routineDay'] = 1;
                        }
                      })),
              if (_day['kind'] == 'workout') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                    key: ValueKey('category-${_day['kind']}'),
                    initialValue: categories.contains(_day['category'])
                        ? _day['category'] as String
                        : 'Full Body',
                    decoration:
                        const InputDecoration(labelText: 'Workout category'),
                    items: [
                      for (final c in categories)
                        DropdownMenuItem(value: c, child: Text(c))
                    ],
                    onChanged: (v) => setState(() => _category(v!))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                    initialValue: routine?.id,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Published Routine'),
                    items: [
                      for (final r in widget.routines)
                        DropdownMenuItem(
                            value: r.id,
                            child:
                                Text(r.title, overflow: TextOverflow.ellipsis))
                    ],
                    onChanged: (v) => setState(() {
                          _day['routineId'] = v;
                          _day['routineDay'] = widget.routines
                              .firstWhere((r) => r.id == v)
                              .days
                              .first;
                        })),
                if (routine != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                      key: ValueKey(routine.id),
                      initialValue: routine.days.contains(_day['routineDay'])
                          ? _day['routineDay'] as int
                          : routine.days.first,
                      decoration:
                          const InputDecoration(labelText: 'Routine day'),
                      items: [
                        for (final d in routine.days)
                          DropdownMenuItem(value: d, child: Text('Day $d'))
                      ],
                      onChanged: (v) =>
                          setState(() => _day['routineDay'] = v!)),
                ],
                const SizedBox(height: 12),
                TextField(
                    controller: _rest,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: 'Rest between sets (seconds)',
                        errorText: _error)),
                const SizedBox(height: 12),
                const Text(
                    'Set exercise order, sets and reps in Routine Builder, publish that Routine, then select it here. AI availability follows the existing tracker registry.'),
              ],
            ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(onPressed: _save, child: const Text('Apply'))
        ]);
  }
}
