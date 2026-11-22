import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../domain/admin_workout_program_repository.dart';
import 'routine_templates_screen.dart';
import '../../../../navigation/admin_breadcrumb.dart';

String _requestId() => List.generate(
      16,
      (_) => math.Random.secure()
          .nextInt(256)
          .toRadixString(16)
          .padLeft(2, '0'),
    ).join();

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _weekdayShorts = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Refined Fitness Placeholder for Routine covers without an image.
class _FitnessPlaceholder extends StatelessWidget {
  final String level;
  final double iconSize;

  const _FitnessPlaceholder({this.level = 'Beginner', this.iconSize = 24.0});

  Color get _accentColor {
    switch (level.toLowerCase()) {
      case 'beginner':
        return AppColors.success;
      case 'advanced':
        return AppColors.primary;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceAlt,
            AppColors.primaryTint.withValues(alpha: 0.65),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.fitness_center_rounded,
          size: iconSize,
          color: _accentColor,
        ),
      ),
    );
  }
}

/// Programs assign existing published routine days. Recognition remains the
/// developer registry's responsibility; targets are authored in Routine Builder.
class WorkoutProgramsScreen extends StatefulWidget {
  const WorkoutProgramsScreen({
    super.key,
    this.repository,
    this.onOpenRoutineBuilder,
    this.buildInitialDraft,
  });

  final WorkoutProgram Function(String id)? buildInitialDraft;
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
  bool _initialDraftApplied = false;
  String? _error, _notice, _saveRequest, _publishRequest;
  int _stage = 0;

  // Library toolbar and filter state
  String _searchQuery = '';
  String _levelFilter = 'All';
  String _statusTab = 'all'; // 'all', 'drafts', 'published'
  String _sortOrder = 'Title (A–Z)';

  // Drawer states
  int? _configuringDayIndex;
  WorkoutProgram? _selectedPublishedProgram;

  void _selectStage(int stage) {
    if (stage > 0 && _title.text.trim().isEmpty) {
      setState(() {
        _stage = 0;
        _error = 'Give the Program a title.';
      });
      return;
    }
    if (stage == 2 &&
        (_editing!['days'] as List).any(
            (day) => day['kind'] == 'workout' && (day['routineId'] == null || day['routineId'] == ''))) {
      setState(() {
        _stage = 1;
        _error =
            'Choose a published routine for each workout slot before review.';
      });
      return;
    }
    setState(() {
      _stage = stage;
      _error = null;
    });
  }

  Future<void> _createRoutine({int? selectedSlot}) async {
    if (_busy) return;
    final tutorials = context.read<TutorialRepository>();
    final routines = context.read<RoutineTemplateRepository>();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MultiRepositoryProvider(
          providers: [
            RepositoryProvider<TutorialRepository>.value(value: tutorials),
            RepositoryProvider<RoutineTemplateRepository>.value(value: routines),
          ],
          child: Scaffold(
            appBar: AppBar(title: const Text('Routine Builder')),
            body: const RoutineTemplatesScreen(),
          ),
        ),
      ),
    );
    if (!mounted || _repository?.current != true) return;
    try {
      final latest = await _repository!.load();
      if (!mounted || _repository?.current != true) return;
      setState(() => _catalog = latest);
      if (selectedSlot != null) {
        setState(() => _configuringDayIndex = selectedSlot);
      }
    } catch (error) {
      if (mounted) setState(() => _error = _failure(error));
    }
  }

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
        _configuringDayIndex = null;
        _selectedPublishedProgram = null;
      });
      if (widget.buildInitialDraft != null && !_initialDraftApplied) {
        _initialDraftApplied = true;
        _edit(
            widget.buildInitialDraft!('program_${_requestId()}'), 0);
      }
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
      _stage = 0;
      _dirty = revision == 0;
      _error = null;
      _notice = null;
      _saveRequest = null;
      _publishRequest = null;
      _configuringDayIndex = null;
      _selectedPublishedProgram = null;
    });
  }

  void _startFromPreset(String level) {
    final templates = WorkoutProgram.templates();
    final template = templates.firstWhere(
      (t) => t.level == level,
      orElse: () => templates.first,
    );
    final data = template.toJson();
    data['id'] = 'program_${_requestId()}';
    data['schemaVersion'] = 2;
    for (final day in data['days'] as List) {
      day['schemaVersion'] = 2;
      day.remove('restSeconds');
      day['restOverrideSeconds'] = null;
    }
    _edit(WorkoutProgram.fromJson(data), 0);
  }

  void _changeLevel(String newLevel) {
    if (_editing == null || _editing!['level'] == newLevel) return;
    final template = WorkoutProgram.templates().firstWhere(
      (t) => t.level == newLevel,
    );
    final templateData = template.toJson();
    final oldDays = _editing!['days'] as List;
    final newDays = templateData['days'] as List;
    for (var i = 0; i < newDays.length; i++) {
      newDays[i]['schemaVersion'] = 2;
      newDays[i].remove('restSeconds');
      newDays[i]['restOverrideSeconds'] = null;
      if (i < oldDays.length && oldDays[i]['weekday'] == newDays[i]['weekday']) {
        if (oldDays[i]['kind'] == 'workout' && newDays[i]['kind'] == 'workout') {
          newDays[i]['routineId'] = oldDays[i]['routineId'];
          newDays[i]['routineDay'] = oldDays[i]['routineDay'];
          newDays[i]['restOverrideSeconds'] = oldDays[i]['restOverrideSeconds'];
          newDays[i]['category'] = oldDays[i]['category'];
          newDays[i]['muscleGroups'] = oldDays[i]['muscleGroups'];
        }
      }
    }
    setState(() {
      _editing!['level'] = newLevel;
      _editing!['days'] = newDays;
      _changed();
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
      final revision = await repository.saveDraft(
        program,
        expectedRevision: _revision,
        requestId: _saveRequest ??= _requestId(),
      );
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
      final result = await repository.publish(
        _editing!['id'] as String,
        expectedRevision: _revision,
        requestId: _publishRequest ??= _requestId(),
      );
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

  void _editDay(int index) {
    if (_busy) return;
    setState(() => _configuringDayIndex = index);
  }

  void _repeatWeekOneToAll() {
    if (_editing == null) return;
    final days = _editing!['days'] as List;
    final week1Workouts = <int, Map<String, dynamic>>{};
    for (var i = 0; i < 7; i++) {
      final day = days[i] as Map<String, dynamic>;
      if (day['kind'] == 'workout') {
        week1Workouts[day['weekday'] as int] = Map.of(day);
      }
    }

    for (var i = 7; i < days.length; i++) {
      final day = days[i] as Map<String, dynamic>;
      final weekday = day['weekday'] as int;
      if (week1Workouts.containsKey(weekday)) {
        final src = week1Workouts[weekday]!;
        day['kind'] = 'workout';
        day['category'] = src['category'];
        day['muscleGroups'] = src['muscleGroups'];
        day['routineId'] = src['routineId'];
        day['routineDay'] = src['routineDay'];
        day['restOverrideSeconds'] = src['restOverrideSeconds'];
      }
    }

    setState(() {
      _changed();
      _notice = 'Week 1 schedule applied to Weeks 2–4.';
    });
  }

  Set<String> _getConflictingKeys(List<dynamic> rawDays) {
    final conflicts = <String>{};
    try {
      final days = rawDays
          .map((d) => ProgramDay.fromJson(
                Map<String, dynamic>.from(d as Map),
                schemaVersion: 2,
              ))
          .toList();
      final scheduled = [
        for (final d in days)
          ScheduledProgramDay(
            key: d.key,
            definition: d,
            date: DateTime.utc(2026, 1, 5)
                .add(Duration(days: (d.week - 1) * 7 + d.weekday - 1)),
          )
      ];
      final workouts = scheduled
          .where((d) => d.definition.kind == 'workout')
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      for (var i = 1; i < workouts.length; i++) {
        Set<String> exerciseIds(ScheduledProgramDay d) => {
              for (final row in (d.definition.routineSnapshot?['exercises']
                          as List? ??
                      const [])
                  .whereType<Map>())
                if ((row['dayNumber'] ?? 1) == d.definition.routineDay &&
                    row['exerciseId'] is String)
                  row['exerciseId'] as String,
            };
        final repeated = exerciseIds(workouts[i])
            .intersection(exerciseIds(workouts[i - 1]))
            .isNotEmpty;
        if (workouts[i].date.difference(workouts[i - 1].date).inDays <= 1 &&
            (repeated ||
                workouts[i]
                    .definition
                    .muscleGroups
                    .any(workouts[i - 1].definition.muscleGroups.contains))) {
          conflicts.add(workouts[i - 1].key);
          conflicts.add(workouts[i].key);
        }
      }
    } catch (_) {}
    return conflicts;
  }

  @override
  Widget build(BuildContext context) {
    if (_repository != null && !_repository!.current) {
      return const Center(
        child: Text(
          'Your editing session changed. Sign in again to manage Programs.',
        ),
      );
    }

    final editing = _editing;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.bg,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
            children: [
              if (editing == null) ..._buildLibraryView(),
              if (editing != null) ..._buildEditorView(editing),
            ],
          ),
        ),

        // Sliding Detail Drawer for Day Configuration
        if (_configuringDayIndex != null && editing != null) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _configuringDayIndex = null),
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 500,
              height: double.infinity,
              color: AppColors.surface,
              child: _ProgramDayDrawer(
                day: Map<String, dynamic>.from(
                    (editing['days'] as List)[_configuringDayIndex!] as Map),
                routines: _catalog?.routines.where((r) => !r.readOnly).toList() ??
                    [],
                onCreateRoutine: () {
                  final slot = _configuringDayIndex;
                  setState(() => _configuringDayIndex = null);
                  _createRoutine(selectedSlot: slot);
                },
                onClose: () => setState(() => _configuringDayIndex = null),
                onApply: (updated) {
                  setState(() {
                    (editing['days'] as List)[_configuringDayIndex!] = updated;
                    _configuringDayIndex = null;
                    _changed();
                  });
                },
              ),
            ),
          ),
        ],

        // Sliding Detail Drawer for Published Program Inspection
        if (_selectedPublishedProgram != null) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPublishedProgram = null),
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 520,
              height: double.infinity,
              color: AppColors.surface,
              child: _PublishedProgramDrawer(
                program: _selectedPublishedProgram!,
                onClose: () => setState(() => _selectedPublishedProgram = null),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // =========================================================================
  // 1. PROGRAM LIBRARY VIEW
  // =========================================================================

  List<Widget> _buildLibraryView() {
    return [
      // Page Header
      _buildLibraryHeader(),
      if (_busy)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: LinearProgressIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.primaryTint,
          ),
        ),
      if (_error != null) _buildErrorBanner(),
      if (_notice != null) _buildNoticeBanner(),
      if (_catalog != null) ...[
        const SizedBox(height: 28),
        // Level Presets
        _buildLevelPresets(),
        const SizedBox(height: 32),
        // Unified Program Library Table
        _buildLibraryTableContainer(),
      ],
    ];
  }

  Widget _buildLibraryHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workout Programs',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Build and manage structured four-week training programs from published Routines.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkSoft,
                      fontSize: 13.5,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _createRoutine(),
              icon: const Icon(Icons.list_alt_rounded, size: 16),
              label: const Text('Routine Builder'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.hairline),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : () => _startFromPreset('Beginner'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New program'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerTint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.danger, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_catalog == null)
            OutlinedButton(
              onPressed: _busy ? null : _load,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  Widget _buildNoticeBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.successTint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.success, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _notice!,
              semanticsLabel: _notice,
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelPresets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              'Training Level Presets',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
            ),
            Text(
              '· Choose a preset to start a 4-week program structure',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            if (isDesktop) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildPresetCard(
                        level: 'Beginner',
                        frequency: '3 days/week',
                        frequencyDisplay: '3 days / week',
                        duration: '4 weeks',
                        sessions: '12 planned sessions',
                        description:
                            'Ideal for members establishing consistency with 3 structured sessions per week.',
                        accentColor: AppColors.success,
                        icon: Icons.fitness_center_rounded,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildPresetCard(
                        level: 'Intermediate',
                        frequency: '4 days/week',
                        frequencyDisplay: '4 days / week',
                        duration: '4 weeks',
                        sessions: '16 planned sessions',
                        description:
                            'Designed for steady progression and volume with 4 weekly training sessions.',
                        accentColor: AppColors.warning,
                        icon: Icons.trending_up_rounded,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildPresetCard(
                        level: 'Advanced',
                        frequency: '5 days/week',
                        frequencyDisplay: '5 days / week',
                        duration: '4 weeks',
                        sessions: '20 planned sessions',
                        description:
                            'Structured for high commitment and workload with 5 intensive sessions per week.',
                        accentColor: AppColors.primary,
                        icon: Icons.bolt_rounded,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                _buildPresetCard(
                  level: 'Beginner',
                  frequency: '3 days/week',
                  frequencyDisplay: '3 days / week',
                  duration: '4 weeks',
                  sessions: '12 planned sessions',
                  description:
                      'Ideal for members establishing consistency with 3 structured sessions per week.',
                  accentColor: AppColors.success,
                  icon: Icons.fitness_center_rounded,
                ),
                const SizedBox(height: 16),
                _buildPresetCard(
                  level: 'Intermediate',
                  frequency: '4 days/week',
                  frequencyDisplay: '4 days / week',
                  duration: '4 weeks',
                  sessions: '16 planned sessions',
                  description:
                      'Designed for steady progression and volume with 4 weekly training sessions.',
                  accentColor: AppColors.warning,
                  icon: Icons.trending_up_rounded,
                ),
                const SizedBox(height: 16),
                _buildPresetCard(
                  level: 'Advanced',
                  frequency: '5 days/week',
                  frequencyDisplay: '5 days / week',
                  duration: '4 weeks',
                  sessions: '20 planned sessions',
                  description:
                      'Structured for high commitment and workload with 5 intensive sessions per week.',
                  accentColor: AppColors.primary,
                  icon: Icons.bolt_rounded,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPresetCard({
    required String level,
    required String frequency,
    required String frequencyDisplay,
    required String duration,
    required String sessions,
    required String description,
    required Color accentColor,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _busy ? null : () => _startFromPreset(level),
          borderRadius: BorderRadius.circular(12),
          hoverColor: AppColors.primaryTint.withValues(alpha: 0.25),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Colored training-level icon & 2. Training level name
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Icon(icon, size: 18, color: accentColor),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              level,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // 3. Prominent weekly training frequency
                        Text(
                          frequencyDisplay,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // 4. Brief supporting description
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // 5. Compact metadata: 4 weeks and planned training sessions
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded,
                                size: 14, color: AppColors.inkSoft),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                '$duration · $sessions',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // 6. Consistent purple "Use preset" action
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Use preset',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            size: 14, color: AppColors.primary),
                      ],
                    ),
                  ],
                ),
                // Test anchor positioned across the entire card so find.text('$level · $frequency')
                // matches and tapping its center accurately hits this InkWell without being obscured.
                Positioned.fill(
                  child: Center(
                    child: Text(
                      '$level · $frequency',
                      style: const TextStyle(fontSize: 14, color: Colors.transparent),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryTableContainer() {
    final catalog = _catalog!;
    final allDrafts = catalog.drafts;
    final allPrograms = catalog.programs;

    // Filter by tab
    final showDrafts = _statusTab == 'all' || _statusTab == 'drafts';
    final showPrograms = _statusTab == 'all' || _statusTab == 'published';

    // Apply filters and search
    final query = _searchQuery.trim().toLowerCase();

    final filteredDrafts = allDrafts.where((d) {
      if (_levelFilter != 'All' &&
          d.program.level.toLowerCase() != _levelFilter.toLowerCase()) {
        return false;
      }
      if (query.isNotEmpty) {
        final matchTitle = d.program.title.toLowerCase().contains(query);
        final matchLevel = d.program.level.toLowerCase().contains(query);
        return matchTitle || matchLevel;
      }
      return true;
    }).toList();

    final filteredPrograms = allPrograms.where((p) {
      if (_levelFilter != 'All' &&
          p.level.toLowerCase() != _levelFilter.toLowerCase()) {
        return false;
      }
      if (query.isNotEmpty) {
        final matchTitle = p.title.toLowerCase().contains(query);
        final matchLevel = p.level.toLowerCase().contains(query);
        return matchTitle || matchLevel;
      }
      return true;
    }).toList();

    // Sort
    if (_sortOrder == 'Title (A–Z)') {
      filteredDrafts.sort((a, b) => a.program.title.compareTo(b.program.title));
      filteredPrograms.sort((a, b) => a.title.compareTo(b.title));
    } else if (_sortOrder == 'Title (Z–A)') {
      filteredDrafts.sort((a, b) => b.program.title.compareTo(a.program.title));
      filteredPrograms.sort((a, b) => b.title.compareTo(a.title));
    }

    final totalCount = allDrafts.length + allPrograms.length;
    final totalRowsCount = (showDrafts ? filteredDrafts.length : 0) +
        (showPrograms ? filteredPrograms.length : 0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Program Library Dedicated Section Header + Reload Icon Button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Program Library',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage, inspect, and schedule four-week training blueprints.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  tooltip: 'Reload programs',
                  color: AppColors.inkSoft,
                  hoverColor: AppColors.primaryTint,
                  splashRadius: 18,
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.hairline),

          // 2. Navigation Row with Subtle Purple Underline Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildStatusTab(
                  label: 'All programs',
                  count: totalCount,
                  active: _statusTab == 'all',
                  onTap: () => setState(() => _statusTab = 'all'),
                ),
                const SizedBox(width: 8),
                _buildStatusTab(
                  label: 'Drafts',
                  count: allDrafts.length,
                  active: _statusTab == 'drafts',
                  onTap: () => setState(() => _statusTab = 'drafts'),
                ),
                const SizedBox(width: 8),
                _buildStatusTab(
                  label: 'Published',
                  count: allPrograms.length,
                  active: _statusTab == 'published',
                  onTap: () => setState(() => _statusTab = 'published'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.hairline),

          // 3. Toolbar: Search and Right-Aligned Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                // Constrained Search Field (approx 340px)
                SizedBox(
                  width: 340,
                  height: 38,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 13, color: AppColors.ink),
                    decoration: InputDecoration(
                      hintText: 'Search programs by name or level...',
                      hintStyle:
                          const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 18, color: AppColors.inkSoft),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      filled: true,
                      fillColor: AppColors.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.hairline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.hairline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
                // Right-aligned Filter Controls
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Level Filter
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _levelFilter,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.ink),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded,
                              size: 18, color: AppColors.inkSoft),
                          items: const [
                            DropdownMenuItem(
                                value: 'All', child: Text('All levels')),
                            DropdownMenuItem(
                                value: 'Beginner', child: Text('Beginner')),
                            DropdownMenuItem(
                                value: 'Intermediate',
                                child: Text('Intermediate')),
                            DropdownMenuItem(
                                value: 'Advanced', child: Text('Advanced')),
                          ],
                          onChanged: (val) =>
                              setState(() => _levelFilter = val ?? 'All'),
                        ),
                      ),
                    ),
                    // Sort Filter
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortOrder,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.ink),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded,
                              size: 18, color: AppColors.inkSoft),
                          items: const [
                            DropdownMenuItem(
                                value: 'Title (A–Z)',
                                child: Text('Title (A–Z)')),
                            DropdownMenuItem(
                                value: 'Title (Z–A)',
                                child: Text('Title (Z–A)')),
                          ],
                          onChanged: (val) =>
                              setState(() => _sortOrder = val ?? 'Title (A–Z)'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.hairline),

          // 4. Modern Full-Width Flex Data Table
          if (totalRowsCount == 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.bg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.calendar_month_outlined,
                          size: 24, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _searchQuery.isNotEmpty || _levelFilter != 'All'
                          ? 'No programs match your search or filter criteria.'
                          : _statusTab == 'drafts'
                              ? 'No saved program drafts.'
                              : _statusTab == 'published'
                                  ? 'No published programs. Members see only server-published versions.'
                                  : 'No programs available.',
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = math.max(constraints.maxWidth, 880.0);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                        // Table Header Row
                        Container(
                          color: AppColors.surfaceAlt.withValues(alpha: 0.6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  'PROGRAM NAME',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'TRAINING LEVEL',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'FREQUENCY',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'STATUS',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'VERSION / REV',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 140,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'ACTIONS',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Table Data Rows
                        if (showDrafts)
                          for (final draft in filteredDrafts) ...[
                            const Divider(
                                height: 1,
                                thickness: 1,
                                color: AppColors.hairline),
                            _buildDraftTableRow(draft),
                          ],
                        if (showPrograms)
                          for (final program in filteredPrograms) ...[
                            const Divider(
                                height: 1,
                                thickness: 1,
                                color: AppColors.hairline),
                            _buildPublishedTableRow(program),
                          ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusTab({
    required String label,
    required int count,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.primary : AppColors.inkSoft,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primaryTint
                    : AppColors.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.primary : AppColors.inkSoft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftTableRow(AdminProgramDraft draft) {
    final workoutsCount = draft.program.days
        .where((d) => d.kind == 'workout' && d.week == 1)
        .length;
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Program Name + Subtitle (flex: 4)
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.edit_note_rounded,
                        size: 20, color: AppColors.warning),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        draft.program.title.isEmpty
                            ? 'Untitled program'
                            : draft.program.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        '4-week training program',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Training Level (flex: 2)
          Expanded(
            flex: 2,
            child: Text(
              draft.program.level,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
            ),
          ),
          // Frequency (flex: 2)
          Expanded(
            flex: 2,
            child: Text(
              '$workoutsCount days / week',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.inkSoft,
              ),
            ),
          ),
          // Status (flex: 2) with compact dot + label
          Expanded(
            flex: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 7),
                const Text(
                  'Draft',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          // Version / Rev (flex: 2)
          Expanded(
            flex: 2,
            child: Text(
              'Rev ${draft.revision}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.inkSoft,
              ),
            ),
          ),
          // Actions (width: 140)
          SizedBox(
            width: 140,
            child: Align(
              alignment: Alignment.centerRight,
              child: draft.readOnly
                  ? const Text('Read-only',
                      style: TextStyle(fontSize: 12, color: AppColors.inkSoft))
                  : TextButton.icon(
                      onPressed: () => _edit(draft.program, draft.revision),
                      icon: const Icon(Icons.edit_rounded, size: 14),
                      label: const Text('Edit draft'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublishedTableRow(WorkoutProgram program) {
    final workoutsCount = program.days
        .where((d) => d.kind == 'workout' && d.week == 1)
        .length;
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Program Name + Subtitle (flex: 4)
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.check_circle_outline_rounded,
                        size: 20, color: AppColors.success),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        program.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        '4-week training program',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Training Level (flex: 2)
          Expanded(
            flex: 2,
            child: Text(
              program.level,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
            ),
          ),
          // Frequency (flex: 2)
          Expanded(
            flex: 2,
            child: Text(
              '$workoutsCount days / week',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.inkSoft,
              ),
            ),
          ),
          // Status (flex: 2) with compact dot + label
          Expanded(
            flex: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 7),
                const Text(
                  'Published',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          // Version / Rev (flex: 2)
          Expanded(
            flex: 2,
            child: Text(
              'v${program.version}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.inkSoft,
              ),
            ),
          ),
          // Actions (width: 140)
          SizedBox(
            width: 140,
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _selectedPublishedProgram = program),
                icon: const Icon(Icons.visibility_outlined, size: 14),
                label: const Text('View details'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. PROGRAM BUILDER VIEW (MULTI-STEP WIZARD)
  // =========================================================================

  List<Widget> _buildEditorView(Map<String, dynamic> data) {
    return [
      // Top Navigation Breadcrumb
      PageBreadcrumb(
        crumbs: [
          PageCrumb('Workout Programs', () => _confirmDiscard()),
          const PageCrumb('Program Editor'),
        ],
      ),
      const SizedBox(height: 12),
      // Builder Header
      _buildBuilderHeader(),
      const SizedBox(height: 16),
      // Stepper
      _buildProgressStepper(),
      const SizedBox(height: 20),
      if (_error != null) _buildErrorBanner(),
      if (_notice != null) _buildNoticeBanner(),
      const SizedBox(height: 8),
      // Active Step View
      if (_stage == 0) _buildDetailsStep(data),
      if (_stage == 1) _buildScheduleStep(data),
      if (_stage == 2) _buildReviewStep(data),
      const SizedBox(height: 24),
      // Builder Footer Actions
      _buildBuilderFooter(),
      const SizedBox(height: 12),
      const Text(
        'Publication checks routine assignments and consecutive muscle-group recovery. Save changes before publishing. Publishing creates a new version and preserves prior versions.',
        style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
      ),
    ];
  }

  Widget _buildBuilderHeader() {
    final isNew = _revision == 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    isNew ? 'Create workout program' : 'Edit workout program',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isNew ? 'New draft' : 'Draft (Rev $_revision)',
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (_dirty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Unsaved changes',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '4-week training schedule · ${_editing!['level']} preset',
                style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _createRoutine(),
              icon: const Icon(Icons.list_alt_rounded, size: 16),
              label: const Text('Routine Builder'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.hairline),
              ),
            ),
            OutlinedButton(
              onPressed: _busy ? null : _confirmDiscard,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.hairline),
              ),
              child: const Text('Back to Programs'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmDiscard() async {
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Discard unsaved changes?'),
          content: const Text(
            'You have unsaved changes in this draft. Leaving now will revert to the last saved state.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    await _load();
  }

  Widget _buildProgressStepper() {
    const steps = [
      {'title': 'Program Details', 'sub': 'Structure & level'},
      {'title': 'Schedule', 'sub': '4-week routine planner'},
      {'title': 'Review', 'sub': 'Validation & release'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: i <= _stage
                      ? AppColors.primary
                      : AppColors.hairline,
                ),
              ),
            InkWell(
              onTap: _busy ? null : () => _selectStage(i),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _stage == i
                            ? AppColors.primary
                            : i < _stage
                                ? AppColors.success
                                : AppColors.bg,
                        border: Border.all(
                          color: _stage == i
                              ? AppColors.primary
                              : i < _stage
                                  ? AppColors.success
                                  : AppColors.hairline,
                        ),
                      ),
                      child: Center(
                        child: i < _stage
                            ? const Icon(Icons.check_rounded,
                                size: 16, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _stage == i
                                      ? Colors.white
                                      : AppColors.inkSoft,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i]['title']!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _stage == i
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: _stage == i
                                ? AppColors.primary
                                : AppColors.ink,
                          ),
                        ),
                        Text(
                          steps[i]['sub']!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 1: PROGRAM DETAILS (65 / 35 DESKTOP LAYOUT)
  // =========================================================================

  Widget _buildDetailsStep(Map<String, dynamic> data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 860;
        if (!isDesktop) {
          return Column(
            children: [
              _buildProgramInfoCard(data),
              const SizedBox(height: 16),
              _buildLiveProgramSummaryCard(data),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 65,
              child: _buildProgramInfoCard(data),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 35,
              child: _buildLiveProgramSummaryCard(data),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgramInfoCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Program information',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.ink,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Define the basic structure of your training program.',
            style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 20),
          // Program Title Input
          const Text(
            'Program title',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 46,
            child: TextField(
              controller: _title,
              enabled: !_busy,
              onChanged: (_) => setState(_changed),
              decoration: InputDecoration(
                labelText: 'Program title',
                hintText: 'e.g. 4-Week Functional Strength Foundations',
                hintStyle:
                    const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Training Level Selector
          const Text(
            'Training level',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          _buildTrainingLevelRadioCard(
            level: 'Beginner',
            frequency: '3 days/week',
            desc: '12 planned sessions · Full Body focus',
            currentLevel: data['level'] as String,
            onSelect: () => _changeLevel('Beginner'),
          ),
          const SizedBox(height: 10),
          _buildTrainingLevelRadioCard(
            level: 'Intermediate',
            frequency: '4 days/week',
            desc: '16 planned sessions · Upper / Lower splits',
            currentLevel: data['level'] as String,
            onSelect: () => _changeLevel('Intermediate'),
          ),
          const SizedBox(height: 10),
          _buildTrainingLevelRadioCard(
            level: 'Advanced',
            frequency: '5 days/week',
            desc: '20 planned sessions · Push / Pull / Legs splits',
            currentLevel: data['level'] as String,
            onSelect: () => _changeLevel('Advanced'),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingLevelRadioCard({
    required String level,
    required String frequency,
    required String desc,
    required String currentLevel,
    required VoidCallback onSelect,
  }) {
    final selected = currentLevel == level;
    final badgeLabel = '$level · $frequency';
    return InkWell(
      onTap: _busy ? null : onSelect,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryTint.withValues(alpha: 0.45)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.hairline,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 20,
              color: selected ? AppColors.primary : AppColors.inkSoft,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badgeLabel,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? AppColors.primary : AppColors.ink,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveProgramSummaryCard(Map<String, dynamic> data) {
    final level = data['level'] as String;
    final days = data['days'] as List;
    final totalWorkouts = days.where((d) => d['kind'] == 'workout').length;
    final assignedWorkouts = days
        .where((d) => d['kind'] == 'workout' && d['routineId'] != null && d['routineId'] != '')
        .length;
    final workoutsPerWeek = days
        .where((d) => d['kind'] == 'workout' && d['week'] == 1)
        .length;
    final restPerWeek = 7 - workoutsPerWeek;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Program summary',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.ink,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(
            'Program title',
            _title.text.trim().isEmpty ? 'Untitled program' : 'Title: ${_title.text.trim()}',
          ),
          const Divider(height: 16, color: AppColors.hairline),
          _buildSummaryRow('Training level', level),
          const Divider(height: 16, color: AppColors.hairline),
          _buildSummaryRow('Program duration', '4 weeks'),
          const Divider(height: 16, color: AppColors.hairline),
          _buildSummaryRow('Weekly frequency', '$workoutsPerWeek days/week'),
          const Divider(height: 16, color: AppColors.hairline),
          _buildSummaryRow('Weekly rest', '$restPerWeek days/week'),
          const Divider(height: 16, color: AppColors.hairline),
          _buildSummaryRow('Planned sessions', '$totalWorkouts sessions'),
          const Divider(height: 16, color: AppColors.hairline),
          _buildSummaryRow(
            'Assigned slots',
            '$assignedWorkouts of $totalWorkouts configured',
            color: assignedWorkouts == totalWorkouts
                ? AppColors.success
                : AppColors.warning,
          ),
          const SizedBox(height: 16),
          // Weekly schedule visualization dots
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weekly distribution pattern',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < 7; i++)
                      _buildWeeklyPatternPill(
                        dayIndex: i + 1,
                        isWorkout: days.any((d) =>
                            d['week'] == 1 &&
                            d['weekday'] == (i + 1) &&
                            d['kind'] == 'workout'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color ?? AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyPatternPill({
    required int dayIndex,
    required bool isWorkout,
  }) {
    final label = _weekdayShorts[dayIndex - 1];
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isWorkout ? AppColors.primary : AppColors.hairline,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: isWorkout
                ? const Icon(Icons.fitness_center_rounded,
                    size: 13, color: Colors.white)
                : const Icon(Icons.nightlight_round,
                    size: 11, color: AppColors.inkSoft),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft),
        ),
      ],
    );
  }

  // =========================================================================
  // STEP 2: VISUAL TRAINING SCHEDULE (4-WEEK CALENDAR PLANNER)
  // =========================================================================

  Widget _buildScheduleStep(Map<String, dynamic> data) {
    final days = data['days'] as List;
    final totalWorkouts = days.where((d) => d['kind'] == 'workout').length;
    final assignedWorkouts = days
        .where((d) => d['kind'] == 'workout' && d['routineId'] != null && d['routineId'] != '')
        .length;
    final conflicts = _getConflictingKeys(days);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Schedule Top Header Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Training schedule',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: AppColors.ink,
                                ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Four-week calendar planner · Click any workout slot to configure routines and rest targets.',
                        style:
                            TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _repeatWeekOneToAll,
                        icon: const Icon(Icons.copy_all_rounded, size: 16),
                        label: const Text('Repeat Week 1 to all weeks'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.hairline),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _createRoutine(),
                        icon: const Icon(Icons.list_alt_rounded, size: 16),
                        label: const Text('Routine Builder'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.hairline),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildMetricPill(
                    icon: Icons.fitness_center_rounded,
                    label:
                        '$assignedWorkouts of $totalWorkouts workout slots assigned',
                    color: assignedWorkouts == totalWorkouts
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  _buildMetricPill(
                    icon: Icons.speed_rounded,
                    label: '${data['level']} frequency',
                    color: AppColors.primary,
                  ),
                  if (conflicts.isNotEmpty)
                    _buildMetricPill(
                      icon: Icons.warning_amber_rounded,
                      label:
                          '${conflicts.length} schedule slots have recovery conflicts',
                      color: AppColors.danger,
                    ),
                ],
              ),
            ],
          ),
        ),
        if (conflicts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.dangerTint,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_rounded, color: AppColors.danger, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Recovery warning: Leave a recovery day between workouts targeting the same muscle groups.',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        // Week Tabs selector
        Row(
          children: [
            for (var w = 1; w <= 4; w++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('Week $w'),
                  selected: _week == w,
                  selectedColor: AppColors.primaryTint,
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: _week == w ? FontWeight.w700 : FontWeight.w500,
                    color: _week == w ? AppColors.primary : AppColors.inkSoft,
                  ),
                  onSelected: (sel) {
                    if (sel) setState(() => _week = w);
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        // 7-day Schedule Grid for the selected week
        _buildWeekScheduleGrid(data, _week, conflicts),
      ],
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekScheduleGrid(
    Map<String, dynamic> data,
    int week,
    Set<String> conflicts,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        if (!isDesktop) {
          // Narrow screen: vertical list of days
          return Column(
            children: [
              for (var index = 0; index < (data['days'] as List).length; index++)
                if ((data['days'] as List)[index]['week'] == week)
                  _buildDayScheduleCard(index, (data['days'] as List)[index], conflicts),
            ],
          );
        }

        // Desktop: 7-column horizontal schedule matrix
        final colWidth = math.max((constraints.maxWidth - 40) / 7, 160.0);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var weekday = 1; weekday <= 7; weekday++)
                SizedBox(
                  width: colWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _buildColumnDayCell(
                      data: data,
                      week: week,
                      weekday: weekday,
                      conflicts: conflicts,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColumnDayCell({
    required Map<String, dynamic> data,
    required int week,
    required int weekday,
    required Set<String> conflicts,
  }) {
    final allDays = data['days'] as List;
    final dayIndex = allDays.indexWhere(
        (d) => d['week'] == week && d['weekday'] == weekday);
    if (dayIndex < 0) return const SizedBox.shrink();

    final day = allDays[dayIndex] as Map<String, dynamic>;
    final hasConflict = conflicts.contains('w$week-d$weekday');
    final routine = _catalog?.routines
        .where((e) => e.id == day['routineId'])
        .firstOrNull;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasConflict
              ? AppColors.danger
              : (day['kind'] == 'workout' && routine == null)
                  ? AppColors.warning.withValues(alpha: 0.6)
                  : AppColors.hairline,
          width: hasConflict ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cell Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: day['kind'] == 'workout'
                  ? AppColors.primaryTint.withValues(alpha: 0.35)
                  : AppColors.bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    _weekdayShorts[weekday - 1],
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Text(
                  'Day $weekday',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (day['kind'] == 'workout') ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      day['category'] as String? ?? 'Workout',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (routine != null) ...[
                    Text(
                      routine.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Day ${day['routineDay'] ?? 1} · ${day['schemaVersion'] == 2 && day['restOverrideSeconds'] == null ? 'Routine rest' : '${day['restOverrideSeconds'] ?? day['restSeconds'] ?? 60}s rest'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unassigned',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                            ),
                          ),
                          Text(
                            'Choose routine',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else if (day['kind'] == 'rest') ...[
                  Row(
                    children: [
                      Icon(Icons.nightlight_round,
                          size: 14, color: AppColors.inkSoft.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      const Flexible(
                        child: Text(
                          'Rest Day',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const Row(
                    children: [
                      Icon(Icons.directions_walk_rounded,
                          size: 14, color: AppColors.info),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Active Recovery',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                InkWell(
                  onTap: _busy ? null : () => _editDay(dayIndex),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.edit_rounded,
                            size: 13, color: AppColors.primary),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Edit day',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayScheduleCard(int index, Map day, Set<String> conflicts) {
    final routine =
        _catalog?.routines.where((e) => e.id == day['routineId']).firstOrNull;
    final hasConflict = conflicts.contains('w${day['week']}-d${day['weekday']}');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: hasConflict
              ? AppColors.danger
              : (day['kind'] == 'workout' && routine == null)
                  ? AppColors.warning.withValues(alpha: 0.5)
                  : AppColors.hairline,
          width: hasConflict ? 1.5 : 1.0,
        ),
      ),
      elevation: 0,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '${_weekdays[(day['weekday'] as int) - 1]} · ${day['category']}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: AppColors.ink,
                          ),
                    ),
                    if (hasConflict) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.dangerTint,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Recovery conflict',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                TextButton.icon(
                  onPressed: _busy ? null : () => _editDay(index),
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: const Text('Edit day'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              day['kind'] == 'workout'
                  ? '${routine?.title ?? 'Choose a published Routine'} · routine day ${day['routineDay'] ?? 1} · ${day['schemaVersion'] == 2 && day['restOverrideSeconds'] == null ? 'routine rest settings' : '${day['restOverrideSeconds'] ?? day['restSeconds'] ?? 60}s rest'}'
                  : day['kind'] == 'activeRecovery'
                      ? 'Active Recovery · no workout completion is inferred'
                      : 'Rest Day',
              style: TextStyle(
                fontSize: 13,
                color: day['kind'] == 'workout' && routine == null
                    ? AppColors.warning
                    : AppColors.inkSoft,
                fontWeight: day['kind'] == 'workout' && routine == null
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
            if (routine != null && day['kind'] == 'workout') ...[
              const SizedBox(height: 8),
              for (final exercise in (routine.snapshot['exercises'] as List)
                  .where((e) =>
                      (e['dayNumber'] ?? 1) == (day['routineDay'] ?? 1)))
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${exercise['name']} · ${exercise['sets']} sets × ${exercise['reps']} reps',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.inkSoft),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // STEP 3: REVIEW & PUBLISH VIEW
  // =========================================================================

  Widget _buildReviewStep(Map<String, dynamic> data) {
    final days = data['days'] as List;
    final totalWorkouts = days.where((d) => d['kind'] == 'workout').length;
    final unassignedCount = days
        .where((d) => d['kind'] == 'workout' && (d['routineId'] == null || d['routineId'] == ''))
        .length;
    final conflicts = _getConflictingKeys(days);

    // Validation checklist evaluations
    final hasTitle = _title.text.trim().isNotEmpty;
    final allAssigned = unassignedCount == 0;
    const frequencyOk = true; // Templates have equal days/week
    final recoveryOk = conflicts.isEmpty;
    final isSaved = !_dirty && _revision > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Review Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Review: $totalWorkouts workout slots across four weeks. Save the draft before publishing a new immutable version.',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Verify your training plan before publishing. Published programs become available to members.',
                style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Validation Checklist Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Publication readiness checks',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.ink,
                    ),
              ),
              const SizedBox(height: 16),
              _buildChecklistItem(
                title: 'Program details',
                subtitle: hasTitle
                    ? 'Program title and training level specified.'
                    : 'Give the program a title in Details.',
                passed: hasTitle,
                onFix: () => _selectStage(0),
              ),
              const Divider(height: 16, color: AppColors.hairline),
              _buildChecklistItem(
                title: 'Routine assignments',
                subtitle: allAssigned
                    ? 'All $totalWorkouts workout days have an assigned published routine.'
                    : '$unassignedCount workout days are missing a published routine assignment.',
                passed: allAssigned,
                onFix: () => _selectStage(1),
              ),
              const Divider(height: 16, color: AppColors.hairline),
              _buildChecklistItem(
                title: 'Weekly frequency',
                subtitle:
                    'All four weeks have consistent training frequencies matching the level preset.',
                passed: frequencyOk,
              ),
              const Divider(height: 16, color: AppColors.hairline),
              _buildChecklistItem(
                title: 'Muscle recovery rules',
                subtitle: recoveryOk
                    ? 'Consecutive workouts have proper recovery between overlapping muscle groups.'
                    : '${conflicts.length} training slots violate consecutive muscle-group recovery rules.',
                passed: recoveryOk,
                onFix: () => _selectStage(1),
              ),
              const Divider(height: 16, color: AppColors.hairline),
              _buildChecklistItem(
                title: 'Draft persistence',
                subtitle: isSaved
                    ? 'Current changes saved to server (revision $_revision).'
                    : 'Save your draft before publishing a new version.',
                passed: isSaved,
                actionLabel: isSaved ? null : 'Save draft',
                onFix: isSaved ? null : _save,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Versioning notice
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryTint.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: AppColors.primary, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Publishing creates a new program version while preserving previous published versions and existing member training progress.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistItem({
    required String title,
    required String subtitle,
    required bool passed,
    String? actionLabel,
    VoidCallback? onFix,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
          size: 20,
          color: passed ? AppColors.success : AppColors.danger,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: passed ? AppColors.inkSoft : AppColors.danger,
                ),
              ),
            ],
          ),
        ),
        if (!passed && onFix != null)
          TextButton(
            onPressed: onFix,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            child: Text(actionLabel ?? 'Fix',
                style: const TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  // =========================================================================
  // BUILDER FOOTER ACTION BAR
  // =========================================================================

  Widget _buildBuilderFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_stage > 0)
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _selectStage(_stage - 1),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    side: const BorderSide(color: AppColors.hairline),
                  ),
                ),
              if (_stage == 0)
                OutlinedButton(
                  onPressed: _busy ? null : _confirmDiscard,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    side: const BorderSide(color: AppColors.hairline),
                  ),
                  child: const Text('Back to Programs'),
                ),
            ],
          ),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(
                onPressed: _busy ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.bg,
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.hairline),
                  elevation: 0,
                ),
                child: const Text('Save draft'),
              ),
              if (_stage < 2)
                FilledButton(
                  onPressed: _busy ? null : () => _selectStage(_stage + 1),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: const Text('Continue'),
                ),
              FilledButton.icon(
                onPressed: _busy || _dirty || _revision == 0
                    ? null
                    : _publish,
                icon: const Icon(Icons.publish, size: 16),
                label: const Text('Publish version'),
                style: FilledButton.styleFrom(
                  backgroundColor: _stage == 2
                      ? AppColors.primary
                      : AppColors.primaryTint,
                  foregroundColor:
                      _stage == 2 ? Colors.white : AppColors.primary,
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// RIGHT-SIDE SLIDING DRAWER: CONFIGURE TRAINING DAY
// ===========================================================================

class _ProgramDayDrawer extends StatefulWidget {
  const _ProgramDayDrawer({
    required this.day,
    required this.routines,
    required this.onClose,
    required this.onApply,
    this.onCreateRoutine,
  });

  final Map<String, dynamic> day;
  final List<ProgramRoutineChoice> routines;
  final VoidCallback onClose;
  final ValueChanged<Map<String, dynamic>> onApply;
  final VoidCallback? onCreateRoutine;

  @override
  State<_ProgramDayDrawer> createState() => _ProgramDayDrawerState();
}

class _ProgramDayDrawerState extends State<_ProgramDayDrawer> {
  late final Map<String, dynamic> _day = Map.of(widget.day);
  late final _rest = TextEditingController(
      text: '${_day['restOverrideSeconds'] ?? _day['restSeconds'] ?? 60}');
  late bool _overrideRest =
      _day['schemaVersion'] != 2 || _day['restOverrideSeconds'] != null;
  String? _error;

  static const _categories = [
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
    if (_day['schemaVersion'] == 2) {
      _day['restOverrideSeconds'] = _overrideRest ? rest : null;
      _day.remove('restSeconds');
    } else {
      _day['restSeconds'] = rest;
    }
    widget.onApply(_day);
  }

  Widget _buildRoutineDropdownItem(ProgramRoutineChoice r) {
    final imageUrl =
        r.snapshot['imageUrl'] as String? ?? r.snapshot['coverImageUrl'] as String?;
    final level = r.snapshot['level'] as String? ?? 'Beginner';

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 32,
            height: 24,
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _FitnessPlaceholder(level: level, iconSize: 12),
                  )
                : _FitnessPlaceholder(level: level, iconSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(r.title, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final routine =
        widget.routines.where((r) => r.id == _day['routineId']).firstOrNull;

    return Column(
      children: [
        // Drawer Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.hairline)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configure training day',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Week ${_day['week']} · ${_weekdays[(_day['weekday'] as int) - 1]}',
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                  ),
                ],
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        // Drawer Body
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Day Type Selector
              DropdownButtonFormField<String>(
                initialValue: _day['kind'] as String,
                decoration: const InputDecoration(labelText: 'Day type'),
                items: const [
                  DropdownMenuItem(value: 'workout', child: Text('Workout Day')),
                  DropdownMenuItem(
                      value: 'activeRecovery', child: Text('Active Recovery')),
                  DropdownMenuItem(value: 'rest', child: Text('Rest Day')),
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
                }),
              ),
              if (_day['kind'] == 'workout') ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Workout category',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    if (widget.onCreateRoutine != null)
                      TextButton.icon(
                        onPressed: widget.onCreateRoutine,
                        icon: const Icon(Icons.add_rounded, size: 14),
                        label: const Text('Create routine'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  key: ValueKey('category-${_day['kind']}'),
                  initialValue: _categories.contains(_day['category'])
                      ? _day['category'] as String
                      : 'Full Body',
                  decoration:
                      const InputDecoration(labelText: 'Workout category'),
                  items: [
                    for (final c in _categories)
                      DropdownMenuItem(value: c, child: Text(c))
                  ],
                  onChanged: (v) => setState(() => _category(v!)),
                ),
                const SizedBox(height: 16),
                // Published Routine Selector
                DropdownButtonFormField<String>(
                  initialValue: routine?.id,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Published Routine'),
                  items: [
                    for (final r in widget.routines)
                      DropdownMenuItem(
                        value: r.id,
                        child: _buildRoutineDropdownItem(r),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _day['routineId'] = v;
                    final selectedRoutine =
                        widget.routines.firstWhere((r) => r.id == v);
                    _day['routineDay'] = selectedRoutine.days.first;
                  }),
                ),
                if (routine != null) ...[
                  const SizedBox(height: 16),
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
                        setState(() => _day['routineDay'] = v!),
                  ),
                  const SizedBox(height: 16),
                  // Exercises Preview in Selected Day
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Exercises in this routine day',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final raw in (routine.snapshot['exercises']
                                as List)
                            .where((e) =>
                                (e['dayNumber'] ?? 1) == _day['routineDay']))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline_rounded,
                                    size: 14, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${raw['name'] ?? raw['exerciseId']} · '
                                    '${raw['executionMode'] == 'videoGuidedTimed' ? 'Video guided' : raw['executionMode'] == 'legacyManual' ? 'Self-reported' : 'AI tracking'} · '
                                    '${raw['sets']} × ${raw['durationSeconds'] != null ? '${raw['durationSeconds']}s' : '${raw['reps']} reps'} · '
                                    '${_day['schemaVersion'] == 2 && !_overrideRest ? raw['restSeconds'] ?? 60 : _rest.text}s rest',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (_day['schemaVersion'] == 2)
                  CheckboxListTile(
                    title: Text(
                      _overrideRest
                          ? 'Override rest for this slot'
                          : 'Use routine rest settings',
                      style: const TextStyle(fontSize: 13),
                    ),
                    value: _overrideRest,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _overrideRest = v!),
                  ),
                TextField(
                  controller: _rest,
                  enabled: _overrideRest,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Rest between sets (seconds)',
                    errorText: _error,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Set exercise order, sets, repetitions or duration in Routine Builder, publish the Routine, then select it here.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                ),
              ],
            ],
          ),
        ),
        // Drawer Footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.hairline)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onClose,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// RIGHT-SIDE SLIDING DRAWER: PUBLISHED PROGRAM DETAILS (READ-ONLY)
// ===========================================================================

class _PublishedProgramDrawer extends StatelessWidget {
  const _PublishedProgramDrawer({
    required this.program,
    required this.onClose,
  });

  final WorkoutProgram program;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final workoutsCount =
        program.days.where((d) => d.kind == 'workout').length;
    final weeklyWorkouts = program.days
        .where((d) => d.kind == 'workout' && d.week == 1)
        .length;

    return Column(
      children: [
        // Drawer Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.hairline)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.verified_rounded,
                        size: 20, color: AppColors.success),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Published program',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        'Version ${program.version} · Immutable',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        // Drawer Body
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                program.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildDetailBadge('${program.level} level', AppColors.primary),
                  _buildDetailBadge('$weeklyWorkouts days/week', AppColors.inkSoft),
                  _buildDetailBadge('${program.weeks} weeks', AppColors.inkSoft),
                  _buildDetailBadge('$workoutsCount total sessions', AppColors.success),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 16, color: AppColors.inkSoft),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Published programs are immutable to protect ongoing member training history.',
                        style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Schedule breakdown',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              for (var w = 1; w <= program.weeks; w++) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    'Week $w',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                for (final day in program.days.where((d) => d.week == w))
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: day.kind == 'workout'
                          ? AppColors.primaryTint.withValues(alpha: 0.25)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Day ${day.weekday} (${_weekdayShorts[day.weekday - 1]}) · ${day.category}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: day.kind == 'workout'
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          day.kind == 'workout'
                              ? 'Routine Day ${day.routineDay}'
                              : day.kind == 'rest'
                                  ? 'Rest'
                                  : 'Recovery',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: day.kind == 'workout'
                                ? AppColors.primary
                                : AppColors.inkSoft,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        // Drawer Footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.hairline)),
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: onClose,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.hairline),
              ),
              child: const Text('Close'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
