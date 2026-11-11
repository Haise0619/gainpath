import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/workout_program_controller.dart';
import '../../domain/published_routine_view.dart';
import '../workout_presentation.dart';
import '../../domain/program_enrollment.dart';
import '../../domain/routine_attempt.dart';
import 'widgets/program_enrollment_cards.dart';

class WorkoutProgramScreen extends StatefulWidget {
  const WorkoutProgramScreen(
      {super.key,
      required this.controller,
      required this.loadPrograms,
      required this.onOpenRoutine,
      required this.today,
      this.onOpenSummary,
      this.clock});
  final WorkoutProgramController controller;
  final Future<List<WorkoutProgram>> Function() loadPrograms;
  final Future<void> Function(ProgramRoutineLaunch) onOpenRoutine;
  final ValueChanged<RoutineAttempt>? onOpenSummary;
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

  static const _weekdayNames = kProgramWeekdayNames;

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

  Future<void> _enrollSelectedProgram() => _act(() async {
        final choice = _choice!;
        final start = _start!;
        final weekdays = Set<int>.of(_weekdays);
        final available = await widget.loadPrograms();
        if (!mounted || !c.authorized) return;
        final current = available
            .where((p) => p.id == choice.id && p.version == choice.version)
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
      });

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

        final isEnrolling = e == null || _choosing;
        final requiredCount = _choice == null
            ? 0
            : _choice!.days
                .where((d) => d.week == 1 && d.kind == 'workout')
                .length;
        final validationError = _choice == null
            ? null
            : validateProgramSchedule(
                program: _choice,
                startDate: _start,
                today: _today,
                weekdays: _weekdays,
              );
        final canSubmit =
            !c.busy && !_acting && validationError == null && _choice != null;

        final showStickyFooter = isEnrolling &&
            _choice != null &&
            _catalogError == null &&
            !_loading &&
            _programs.isNotEmpty;

        return Scaffold(
            appBar: AppBar(
                title: Text((!isEnrolling && selected != null)
                    ? _dayHeading(selected)
                    : 'Training plan'),
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
            bottomNavigationBar: showStickyFooter
                ? SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: ProgramEnrollmentStickyFooter(
                      selectedCount: _weekdays.length,
                      requiredCount: requiredCount,
                      canSubmit: canSubmit,
                      acting: _acting || c.busy,
                      onStartProgram: _enrollSelectedProgram,
                    ),
                  )
                : null,
            body: ListView(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    showStickyFooter
                        ? 140
                        : 16 + MediaQuery.paddingOf(context).bottom),
                children: [
                  if (c.busy || _loading) const LinearProgressIndicator(),
                  if (_catalogError != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _catalogError!,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                              onPressed: _load,
                              child: const Text('Retry programs'))
                        ],
                      ),
                    ),
                  ],
                  if (_actionError != null || c.error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.dangerTint,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x4DDC2626)),
                      ),
                      child: Text(
                        _actionError ?? c.error!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (e != null && !_choosing) ...[
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
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                        onPressed: c.busy
                            ? null
                            : () {
                                if (_scroll.hasClients) _scroll.jumpTo(0);
                                setState(() => _choosing = true);
                              },
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Choose another program')),
                    const SizedBox(height: 8),
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
                  if (isEnrolling) _buildOnboardingSection(e),
                ]));
      });

  Widget _buildOnboardingSection(ProgramEnrollment? activeEnrollment) {
    if (!_loading && _programs.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.hairline),
        ),
        child: const Text(
          'No programs are available yet. Check back later.',
          style: TextStyle(color: AppColors.inkSoft, fontSize: 13.5),
        ),
      );
    }
    if (_choice == null) return const SizedBox.shrink();

    final validationError = validateProgramSchedule(
      program: _choice,
      startDate: _start,
      today: _today,
      weekdays: _weekdays,
    );
    final previewData = computeSchedulePreview(
      program: _choice,
      startDate: _start,
      weekdays: _weekdays,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (activeEnrollment != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: () {
                if (_scroll.hasClients) _scroll.jumpTo(0);
                setState(() => _choosing = false);
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Return to active plan'),
            ),
          ),
        ],
        ChooseProgramCard(
          selectedProgram: _choice!,
          availablePrograms: _programs,
          onSelectProgram: (p) => setState(() => _selectProgram(p)),
          disabled: c.busy || _acting,
        ),
        const SizedBox(height: 14),
        ProgramOverviewCard(
          program: _choice!,
        ),
        const SizedBox(height: 14),
        ScheduleSetupCard(
          program: _choice!,
          startDate: _start,
          weekdays: _weekdays,
          onPickStartDate: _pickStart,
          onToggleWeekday: (weekday) {
            setState(() {
              if (_weekdays.contains(weekday)) {
                _weekdays.remove(weekday);
              } else {
                _weekdays.add(weekday);
              }
            });
          },
          validationError: validationError,
          disabled: c.busy || _acting,
        ),
        const SizedBox(height: 14),
        SchedulePreviewCard(
          previewData: previewData,
          validationError: validationError,
        ),
      ],
    );
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
                  if (a?.isComplete == true && widget.onOpenSummary != null)
                    FilledButton(
                        onPressed:
                            c.busy ? null : () => widget.onOpenSummary!(a!),
                        child: const Text('View workout summary')),
                  if (d.kind == 'workout' && !c.isComplete(day.key)) ...[
                    FilledButton(
                        onPressed: c.busy ? null : () => _startDay(day),
                        child: Text(c.enrollment!.progress[day.key]?.skipped ==
                                true
                            ? 'Make up workout'
                            : c.enrollment!.progress[day.key]?.attemptId == null
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
