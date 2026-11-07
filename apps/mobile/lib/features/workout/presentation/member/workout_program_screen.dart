import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/workout.dart';
import '../../application/workout_program_controller.dart';
import '../../domain/published_routine_view.dart';
import '../workout_presentation.dart';
import '../../domain/program_enrollment.dart';

class WorkoutProgramScreen extends StatefulWidget {
  const WorkoutProgramScreen(
      {super.key,
      required this.controller,
      required this.loadPrograms,
      required this.onOpenRoutine,
      required this.today,
      this.clock});
  final WorkoutProgramController controller;
  final Future<List<WorkoutProgram>> Function() loadPrograms;
  final Future<void> Function(ProgramRoutineLaunch) onOpenRoutine;
  final DateTime today;

  /// Optional current instant. Calendar dates are always Malaysia civil dates.
  final DateTime Function()? clock;
  @override
  State<WorkoutProgramScreen> createState() => _WorkoutProgramScreenState();
}

class _WorkoutProgramScreenState extends State<WorkoutProgramScreen>
    with WidgetsBindingObserver {
  List<WorkoutProgram> _programs = [];
  WorkoutProgram? _choice;
  DateTime? _start;
  Set<int> _weekdays = {};
  bool _loading = true, _choosing = false;
  bool _acting = false;
  String? _catalogError, _actionError, _selectedKey;
  late DateTime _today;
  Timer? _dayTimer;
  final _scroll = ScrollController();
  WorkoutProgramController get c => widget.controller;
  static const _weekdayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];
  @override
  void initState() {
    super.initState();
    _today = _civilNow();
    _start = _today;
    WidgetsBinding.instance.addObserver(this);
    _dayTimer =
        Timer.periodic(const Duration(minutes: 1), (_) => _refreshDay());
    _load();
  }

  DateTime _civilNow() {
    final instant = widget.clock?.call().toUtc().add(const Duration(hours: 8));
    final date = instant ?? widget.today;
    return DateTime.utc(date.year, date.month, date.day);
  }

  void _refreshDay() {
    final now = _civilNow();
    if (!mounted || now == _today) return;
    setState(() {
      _today = now;
      _selectedKey = null;
      if (_start!.isBefore(now)) _start = now;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDay();
      if (c.authorized) unawaited(_act(c.open));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _dayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _catalogError = null;
    });
    try {
      final programs = await widget.loadPrograms();
      if (!mounted || !c.authorized) return;
      setState(() {
        _programs = programs;
        if (programs.isNotEmpty) _selectProgram(programs.first);
      });
    } catch (_) {
      if (mounted && c.authorized) {
        setState(() => _catalogError =
            'Published programs are unavailable. Your saved schedule is retained.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectProgram(WorkoutProgram program) {
    _choice = program;
    _weekdays = program.days
        .where((d) => d.week == 1 && d.kind == 'workout')
        .map((d) => d.weekday)
        .toSet();
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_acting || c.busy) return;
    setState(() {
      _actionError = null;
      _acting = true;
    });
    try {
      await action();
    } catch (error) {
      if (mounted && c.authorized) {
        setState(() => _actionError = error is FormatException
            ? error.message.toString()
            : 'Could not update the program. Reload and retry; saved progress is retained.');
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  Future<void> _pickStart() async {
    final chosen = await showDatePicker(
        context: context,
        initialDate: _start ?? _today,
        firstDate: _today,
        lastDate: _today.add(const Duration(days: 365)));
    if (chosen != null && mounted) {
      setState(
          () => _start = DateTime.utc(chosen.year, chosen.month, chosen.day));
    }
  }

  Future<void> _startDay(ScheduledProgramDay day) => _act(() async {
        final launch = await c.begin(day.key);
        if (!mounted || !c.authorized) return;
        await widget.onOpenRoutine(launch);
        if (!mounted || !c.authorized) return;
        await c.open();
      });
  Future<void> _skip(ScheduledProgramDay day) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Skip this workout?'),
                content: const Text(
                    'It will remain skipped, without completion credit. You can resume it later.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep workout')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Skip day'))
                ]));
    if (confirmed == true && mounted) await _act(() => c.skip(day.key));
  }

  Future<void> _reschedule(ScheduledProgramDay day) async {
    final chosen = await showDatePicker(
        context: context,
        initialDate: day.date.isBefore(_today) ? _today : day.date,
        firstDate: _today,
        lastDate: _today.add(const Duration(days: 365)));
    if (chosen != null && mounted) {
      await _act(() => c.reschedule(
          day.key, DateTime.utc(chosen.year, chosen.month, chosen.day)));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (!c.authorized) {
          return const Scaffold(
              body:
                  Center(child: Text('Sign in to view your workout program.')));
        }
        final e = c.enrollment;
        final today = _today;
        final selected =
            e?.schedule.where((d) => d.key == _selectedKey).firstOrNull ??
                e?.schedule.where((d) => d.date == today).firstOrNull ??
                c.nextWorkout();
        return Scaffold(
            appBar: AppBar(
                title: Text(
                    selected == null ? 'Training plan' : _dayHeading(selected)),
                actions: [
                  IconButton(
                      tooltip: 'Reload program and progress',
                      onPressed: c.busy
                          ? null
                          : () => _act(() async {
                                _refreshDay();
                                await c.open();
                                await _load();
                              }),
                      icon: const Icon(Icons.refresh))
                ]),
            body: ListView(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(
                    16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
                children: [
                  if (c.busy || _loading) const LinearProgressIndicator(),
                  if (_catalogError != null) ...[
                    Text(_catalogError!),
                    TextButton(
                        onPressed: _load, child: const Text('Retry programs'))
                  ],
                  if (_actionError != null || c.error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(_actionError ?? c.error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  if (e != null) ...[
                    const Text('CURRENT PLAN',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(e.program.title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: const Color(0xFF211A2E))),
                    Text(
                        '${e.program.level} · 4 weeks · Version ${e.program.version}'),
                    const Text(
                        'Schedule saved on this device for your account. Open a day to start or resume.'),
                    if (c.journal!.enrollments.length > 1)
                      DropdownButtonFormField<String>(
                          key: ValueKey(e.id),
                          initialValue: e.id,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Resume a saved enrollment'),
                          items: c.journal!.enrollments
                              .map((item) => DropdownMenuItem(
                                  value: item.id,
                                  child: Text(
                                      '${item.program.title} · ${_date(item.schedule.first.date)}',
                                      overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: c.busy
                              ? null
                              : (id) {
                                  if (id != null) {
                                    setState(() => _selectedKey = null);
                                    _act(() => c.selectEnrollment(id));
                                  }
                                }),
                    if (selected != null)
                      _dayCard(selected)
                    else
                      const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                              'No pending scheduled workouts. Your completed and skipped days remain below.')),
                    const SizedBox(height: 12),
                    Text('Weekly progress',
                        style: Theme.of(context).textTheme.titleLarge),
                    for (var week = 1; week <= 4; week++) _week(e, week),
                    OutlinedButton.icon(
                        onPressed: c.busy
                            ? null
                            : () => setState(() => _choosing = !_choosing),
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Choose another program')),
                    TextButton.icon(
                        onPressed: c.busy
                            ? null
                            : () async {
                                final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                            title:
                                                const Text('End current plan?'),
                                            content: const Text(
                                                'This clears your active plan selection. Your saved enrollment, workout results and history stay on this device. You can choose a new program afterward.'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child:
                                                      const Text('Keep plan')),
                                              FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  child: const Text(
                                                      'End current plan'))
                                            ]));
                                if (!mounted ||
                                    confirmed != true ||
                                    !c.authorized) {
                                  return;
                                }
                                await _act(() async {
                                  await c.endCurrentPlan();
                                  if (mounted) {
                                    setState(() {
                                      _selectedKey = null;
                                      _choosing = false;
                                    });
                                  }
                                });
                              },
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('End current plan')),
                  ],
                  if (e == null || _choosing) _onboarding(),
                ]));
      });
  Widget _onboarding() {
    if (!_loading && _programs.isEmpty) {
      return const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No programs are available yet. Check back later.'));
    }
    if (_choice == null) return const SizedBox.shrink();
    final count =
        _choice!.days.where((d) => d.week == 1 && d.kind == 'workout').length;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Choose your program',
                      style: Theme.of(context).textTheme.titleLarge),
                  DropdownButtonFormField<String>(
                      initialValue: _choice!.id,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Program and level'),
                      items: _programs
                          .map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text('${p.level} · ${p.title}',
                                  overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: c.busy
                          ? null
                          : (id) => setState(() => _selectProgram(
                              _programs.singleWhere((p) => p.id == id)))),
                  const SizedBox(height: 16),
                  Text('$count workouts per week · ${_choice!.weeks} weeks',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final day in _choice!.days
                      .where((d) => d.week == 1 && d.kind == 'workout'))
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.fitness_center_outlined),
                        title: Text(day.routineSnapshot?['title'] as String? ??
                            day.category),
                        subtitle: Text(
                            '${day.category}${day.routineSnapshot?['estimatedMinutes'] == null ? '' : ' · Estimated ${day.routineSnapshot!['estimatedMinutes']} min'}')),
                  const Text(
                      'Recovery days separate training sessions. Your chosen weekdays must preserve the published recovery spacing.'),
                  TextButton.icon(
                      onPressed: c.busy ? null : _pickStart,
                      icon: const Icon(Icons.event),
                      label: Text('Start date: ${_date(_start!)}')),
                  Text(
                      'Choose $count training days each week (${_weekdays.length}/$count selected). We check recovery spacing before saving.'),
                  Wrap(spacing: 6, children: [
                    for (var i = 1; i <= 7; i++)
                      FilterChip(
                          label: Text(_weekdayNames[i - 1]),
                          selected: _weekdays.contains(i),
                          onSelected: c.busy
                              ? null
                              : (selected) => setState(() {
                                    if (selected) {
                                      _weekdays.add(i);
                                    } else {
                                      _weekdays.remove(i);
                                    }
                                  }))
                  ]),
                  if (_weekdays.length != count)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                            'Select exactly $count training days to continue.',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  FilledButton(
                      onPressed: c.busy || _acting || _weekdays.length != count
                          ? null
                          : () => _act(() async {
                                final choice = _choice!;
                                final start = _start!;
                                final weekdays = Set<int>.of(_weekdays);
                                final available = await widget.loadPrograms();
                                if (!mounted || !c.authorized) return;
                                final current = available
                                    .where((p) =>
                                        p.id == choice.id &&
                                        p.version == choice.version)
                                    .firstOrNull;
                                if (current == null ||
                                    canonicalProgramJson(current.toJson()) !=
                                        canonicalProgramJson(choice.toJson())) {
                                  setState(() => _catalogError =
                                      'This program is no longer available for new enrollment. Reload programs to choose another. Your saved history is retained.');
                                  return;
                                }
                                await c.enroll(current, start, weekdays);
                                if (mounted) {
                                  if (_scroll.hasClients) _scroll.jumpTo(0);
                                  setState(() {
                                    _choosing = false;
                                    _selectedKey = null;
                                  });
                                }
                              }),
                      child: const Text('Start program')),
                  const Text(
                      'Choosing another program keeps your previous enrollment and workout history.'),
                ])));
  }

  Widget _week(ProgramEnrollment e, int week) {
    final days = e.schedule.where((d) => d.definition.week == week).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final targets = days.where((d) => d.definition.kind == 'workout').length;
    return ExpansionTile(
        key: ValueKey('program-week-$week'),
        title: Text(
            'Week $week · ${c.completedDays(week)}/$targets workouts completed'),
        children: [
          for (final d in days)
            ListTile(
                key: ValueKey('program-day-${d.key}'),
                title: Text(
                    '${_weekdayNames[d.date.weekday - 1]} ${_date(d.date)} · ${d.definition.category}'),
                subtitle: Text(c.status(d.key, _today)),
                leading: Icon(c.isComplete(d.key)
                    ? Icons.check_circle
                    : d.definition.kind == 'workout'
                        ? Icons.fitness_center
                        : Icons.spa),
                onTap: () => setState(() => _selectedKey = d.key))
        ]);
  }

  String _dayHeading(ScheduledProgramDay day) {
    if (day.definition.kind == 'rest') {
      return day.date == _today ? "Today's rest day" : 'Rest day';
    }
    if (day.definition.kind != 'workout') {
      return day.date == _today ? "Today's recovery" : 'Active recovery day';
    }
    if (day.date == _today) return "Today's workout";
    if (day.date.isAfter(_today)) return 'Upcoming workout';
    if (day.definition.kind == 'workout' &&
        !c.isComplete(day.key) &&
        c.status(day.key, _today).startsWith('Missed')) {
      return 'Missed workout';
    }
    return 'Scheduled day';
  }

  Widget _dayCard(ScheduledProgramDay day) {
    final d = day.definition, a = c.attempt(day.key);
    final exercises = d.routineSnapshot == null
        ? <PublishedRoutineExercise>[]
        : PublishedRoutine.fromDocument(
                d.routineId!, Map<String, dynamic>.from(d.routineSnapshot!))
            .exercises
            .where((e) => e.dayNumber == d.routineDay)
            .toList();
    final next = c.nextWorkout(afterKey: day.key);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      'Week ${d.week} · ${_weekdayNames[day.date.weekday - 1]} ${_date(day.date)}',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(d.category,
                      style: Theme.of(context).textTheme.headlineSmall),
                  Text(c.status(day.key, _today)),
                  if (d.kind != 'workout')
                    Text(d.kind == 'rest'
                        ? 'Rest day. No workout is required.'
                        : 'Active recovery: keep activity gentle. No workout completion is required.'),
                  for (final exercise in exercises) ...[
                    const Divider(),
                    Text(exercise.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(ExercisePresentation.forExercise(exercise,
                            organizationId: c.scope.organizationId)
                        .targetsWithRest),
                    Text(ExercisePresentation.forExercise(exercise,
                            organizationId: c.scope.organizationId)
                        .label),
                  ],
                  if (a != null) ...[
                    const Divider(),
                    Text('Summary · ${workoutAttemptLabel(a)}'),
                    Text(
                        '${a.completedExercises}/${a.entries.length} exercises completed'),
                    for (final result in a.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child:
                            Text('${a.routine.exercises[result.index].name}: '
                                '${exerciseStatusLabel(result.status)} · '
                                '${exerciseResultSummary(result)}'),
                      ),
                  ],
                  if (d.kind == 'workout' && !c.isComplete(day.key)) ...[
                    FilledButton(
                        onPressed: c.busy ? null : () => _startDay(day),
                        child: Text(
                            c.enrollment!.progress[day.key]?.attemptId == null
                                ? 'Start scheduled routine'
                                : 'Resume scheduled routine')),
                    Wrap(spacing: 8, children: [
                      TextButton(
                          onPressed: c.busy ? null : () => _skip(day),
                          child: const Text('Skip day')),
                      TextButton(
                          onPressed: c.busy ? null : () => _reschedule(day),
                          child: const Text('Reschedule'))
                    ]),
                  ],
                  if (next != null)
                    OutlinedButton(
                        onPressed: () =>
                            setState(() => _selectedKey = next.key),
                        child:
                            Text('Next scheduled day · ${_date(next.date)}')),
                ])));
  }
}
