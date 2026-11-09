import 'confirm_content_removal.dart';
import 'routine_cover_field.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../navigation/admin_breadcrumb.dart';
import 'equipment_catalog_screen.dart' show EditableStringList;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/workout.dart';

Widget _networkHero(String url, {BoxFit fit = BoxFit.cover}) {
  if (url.trim().isEmpty) {
    return const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.heroGradient));
  }
  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : Container(color: AppColors.surfaceAlt),
    errorBuilder: (context, error, stack) => const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.heroGradient)),
  );
}

/// AD-M11.4 — Manage Routine Templates. Previously a stub — the Content
/// hub's card linked here only to show a toast ("Routine template
/// editor.") with no real screen or data behind it at all. Backed now by
/// `routineTemplates`; each card expands in place to show its
/// full day-by-day breakdown. Create/Edit is a full page rather than a
/// dialog — a day/exercise builder plus goal/tags/equipment metadata is
/// genuinely a lot of content, the kind of "Create" flow that gets its
/// own page in a real web console rather than a cramped popup.
class RoutineTemplatesScreen extends StatefulWidget {
  const RoutineTemplatesScreen({super.key, this.allowRemoval = true});
  final bool allowRemoval;

  @override
  State<RoutineTemplatesScreen> createState() => _RoutineTemplatesScreenState();
}

class _RoutineTemplatesScreenState extends State<RoutineTemplatesScreen> {
  String? _expandedId;
  RoutineBlueprint? _editing;
  bool _creating = false;
  bool _removing = false;
  String? _publishingId;
  late Future<List<RoutineBlueprint>> _templatesFuture;

  @override
  void initState() {
    super.initState();
    _templatesFuture = context.read<RoutineTemplateRepository>().load();
  }

  void _openCreate() => setState(() => _creating = true);
  void _openEdit(RoutineBlueprint t) => setState(() => _editing = t);
  void _closeForm() => setState(() {
        _creating = false;
        _editing = null;
        _templatesFuture = context.read<RoutineTemplateRepository>().load();
      });

  Future<void> _remove(RoutineBlueprint item) async {
    if (_removing || _publishingId != null || !widget.allowRemoval) return;
    final repository = context.read<RoutineTemplateRepository>();
    if (repository is! RoutineArchivingRepository) return;
    setState(() => _removing = true);
    try {
      final confirmed = await confirmContentRemoval(context,
          title: item.name,
          detail:
              'This archives the template. Published Member routines and workout history are preserved.');
      if (!confirmed || !mounted || !widget.allowRemoval) {
        return;
      }
      await (repository as RoutineArchivingRepository).archive(item);
      if (!mounted) return;
      setState(() => _templatesFuture = repository.load());
      showToast(context, 'Template removed.');
    } catch (_) {
      if (mounted) {
        showToast(context, 'Removal was not verified. Reload before retrying.');
      }
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  Future<void> _publish(RoutineBlueprint blueprint) async {
    if (_publishingId != null || _removing) return;
    final firebaseCatalog =
        context.read<TutorialRepository>().requiresCatalogSelection;
    setState(() => _publishingId = blueprint.id);
    try {
      await context.read<RoutineTemplateRepository>().publish(blueprint.id);
      if (mounted) {
        showToast(
            context,
            firebaseCatalog
                ? 'Routine published. Members can pull to refresh Home or refresh Workout.'
                : 'Routine published to members.');
      }
    } catch (_) {
      if (mounted) {
        showToast(context,
            'Publication was not verified. Reload and check the Member catalog before retrying.');
      }
    } finally {
      if (mounted) setState(() => _publishingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_creating || _editing != null) {
      return _TemplateFormPage(existing: _editing, onDone: _closeForm);
    }

    return FutureBuilder<List<RoutineBlueprint>>(
      future: _templatesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Could not load routine templates.'),
            TextButton(
                onPressed: () => setState(() => _templatesFuture =
                    context.read<RoutineTemplateRepository>().load()),
                child: const Text('Retry')),
          ]));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final templates = snapshot.data!;
        final firebaseCatalog =
            context.read<TutorialRepository>().requiresCatalogSelection;
        final totalAssigned =
            templates.fold<int>(0, (sum, t) => sum + t.assignedMembers);
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        firebaseCatalog
                            ? '${templates.length} organization routine blueprints'
                            : '${templates.length} templates · $totalAssigned members currently following one',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    IconButton(
                        tooltip: 'Reload templates',
                        icon: const Icon(Icons.refresh),
                        onPressed: _removing
                            ? null
                            : () => setState(() => _templatesFuture = context
                                .read<RoutineTemplateRepository>()
                                .load())),
                    FilledButton.icon(
                      onPressed: _removing ? null : _openCreate,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New template'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ...templates.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TemplateCard(
                        showRemoval: widget.allowRemoval,
                        template: t,
                        expanded: _expandedId == t.id,
                        onToggle: () => setState(() =>
                            _expandedId = _expandedId == t.id ? null : t.id),
                        onRemove: widget.allowRemoval &&
                                context.read<RoutineTemplateRepository>()
                                    is RoutineArchivingRepository &&
                                !_removing &&
                                _publishingId == null
                            ? () => _remove(t)
                            : null,
                        onEdit: () => _openEdit(t),
                        onPublish: () => _publish(t),
                        publishing: _publishingId == t.id,
                        firebaseCatalog: firebaseCatalog,
                      ),
                    )),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final bool showRemoval;
  final RoutineBlueprint template;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;
  final VoidCallback onPublish;
  final bool publishing;
  final bool firebaseCatalog;
  const _TemplateCard(
      {required this.template,
      required this.expanded,
      required this.onToggle,
      required this.onEdit,
      this.showRemoval = true,
      this.onRemove,
      required this.onPublish,
      required this.publishing,
      required this.firebaseCatalog});

  Color get _levelColor {
    switch (template.level) {
      case 'Beginner':
        return AppColors.success;
      case 'Advanced':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: template.imageUrl.isEmpty
                          ? Container(
                              color: _levelColor.withValues(alpha: 0.14),
                              child: Icon(Icons.list_alt_rounded,
                                  size: 19, color: _levelColor),
                            )
                          : _networkHero(template.imageUrl),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(template.name,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          firebaseCatalog
                              ? '${template.level}  ·  ${template.days.length}-day split  ·  organization blueprint'
                              : '${template.level}  ·  ${template.days.length}-day split  ·  ${template.assignedMembers} following',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  if (showRemoval)
                    IconButton(
                        tooltip: 'Remove template',
                        onPressed: template.readOnly ? null : onRemove,
                        icon: const Icon(Icons.delete_outline, size: 18)),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: template.readOnly ? null : onEdit,
                  ),
                  Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppColors.inkSoft),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 20),
                        if (template.goal.isNotEmpty) ...[
                          Text(template.goal,
                              style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 10),
                        ],
                        if (template.tags.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: template.tags
                                .map((t) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: AppColors.primaryTint,
                                          borderRadius:
                                              BorderRadius.circular(999)),
                                      child: Text(t,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary)),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 10),
                        ],
                        ...template.days.map((d) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Day ${d.dayNumber}',
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary)),
                                  const SizedBox(height: 4),
                                  ...d.exercises.map((e) => Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 3, left: 4),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.circle,
                                                size: 4,
                                                color: AppColors.inkSoft),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                  '${e.exerciseName}  ·  ${e.sets} × ${e.prescription is TimedPrescription ? '${(e.prescription as TimedPrescription).durationSeconds}s' : '${e.reps} reps'}',
                                                  style: const TextStyle(
                                                      fontSize: 13)),
                                            ),
                                          ],
                                        ),
                                      )),
                                ],
                              ),
                            )),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: publishing || template.readOnly
                                ? null
                                : onPublish,
                            icon: publishing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.publish_rounded, size: 17),
                            label: Text(publishing ? 'Publishing…' : 'Publish'),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _ExerciseDraft {
  static int _serial = 0;
  final String entryId;
  ExerciseExecutionMode? mode;
  int? sourceRevision;
  final TextEditingController rest;
  final TextEditingController name;
  final TextEditingController sets;
  final TextEditingController reps;
  String? selectedExerciseId;
  _ExerciseDraft(
      {String name = '',
      String sets = '3',
      String reps = '10',
      String rest = '60',
      String? entryId,
      this.mode,
      this.sourceRevision,
      this.selectedExerciseId})
      : entryId = entryId ??
            'entry-${DateTime.now().microsecondsSinceEpoch}-${_serial++}',
        rest = TextEditingController(text: rest),
        name = TextEditingController(text: name),
        sets = TextEditingController(text: sets),
        reps = TextEditingController(text: reps);

  void dispose() {
    name.dispose();
    sets.dispose();
    reps.dispose();
    rest.dispose();
  }
}

class _DayDraft {
  final List<_ExerciseDraft> exercises;
  _DayDraft([List<_ExerciseDraft>? exercises])
      : exercises = exercises ?? [_ExerciseDraft()];

  void dispose() {
    for (final e in exercises) {
      e.dispose();
    }
  }
}

class _TemplateFormPage extends StatefulWidget {
  final RoutineBlueprint? existing;
  final VoidCallback onDone;
  const _TemplateFormPage({this.existing, required this.onDone});

  @override
  State<_TemplateFormPage> createState() => _TemplateFormPageState();
}

class _TemplateFormPageState extends State<_TemplateFormPage> {
  static const _levels = ['Beginner', 'Intermediate', 'Advanced'];
  static const _tagOptions = [
    'Fat loss',
    'Muscle gain',
    'General fitness',
    'Strength',
    'Mobility'
  ];

  late final _name = TextEditingController(text: widget.existing?.name ?? '')
    ..addListener(_repaint);
  late final _imageUrl =
      TextEditingController(text: widget.existing?.imageUrl ?? '')
        ..addListener(_repaint);
  late final _goal = TextEditingController(text: widget.existing?.goal ?? '');
  late final _duration = TextEditingController(
      text: '${widget.existing?.sessionDurationMin ?? 45}');
  late String _level = widget.existing?.level ?? _levels.first;
  late final Set<String> _tags = {...(widget.existing?.tags ?? const [])};
  late List<String> _equipmentNeeded = [
    ...(widget.existing?.equipmentNeeded ?? const [])
  ];
  late final List<_DayDraft> _days = widget.existing == null
      ? [_DayDraft()]
      : widget.existing!.days
          .map((d) => _DayDraft(d.exercises
              .map((e) => _ExerciseDraft(
                  name: e.exerciseName,
                  sets: '${e.sets}',
                  reps:
                      '${e.prescription is TimedPrescription ? (e.prescription as TimedPrescription).durationSeconds : e.reps}',
                  rest: '${e.prescription?.restSeconds ?? 60}',
                  entryId: e.entryId.isEmpty ? null : e.entryId,
                  mode: e.executionMode,
                  sourceRevision: e.sourceCatalogRevision,
                  selectedExerciseId:
                      e.exerciseId.isEmpty ? null : e.exerciseId))
              .toList()))
          .toList();
  String? _error;
  EquipmentImage? _cover;
  String? _coverError;
  bool _pickingCover = false;

  Future<void> _chooseCover() async {
    if (_saving || _reloadRequired || _pickingCover) return;
    setState(() {
      _pickingCover = true;
      _coverError = null;
    });
    try {
      final selected = await context.read<EquipmentImagePicker>().pick();
      if (mounted && selected != null) setState(() => _cover = selected);
    } on FormatException catch (error) {
      if (mounted) setState(() => _coverError = error.message);
    } catch (_) {
      if (mounted)
        setState(() => _coverError =
            'Could not open the image. Choose another JPG, PNG or WebP.');
    } finally {
      if (mounted) setState(() => _pickingCover = false);
    }
  }

  List<TutorialVideo> _catalog = const [];
  bool _catalogLoading = false;
  bool _saving = false;
  bool _reloadRequired = false;
  bool get _usesCatalog =>
      context.read<TutorialRepository>().requiresCatalogSelection;

  bool get _isEdit => widget.existing != null;
  bool get _isV2 =>
      _usesCatalog &&
      (widget.existing == null ||
          widget.existing!.schemaVersion == 2 ||
          _upgradeLegacy);
  bool _upgradeLegacy = false;
  int _stage = 0;
  void _selectStage(int stage) {
    if (stage > 0 &&
        (_name.text.trim().isEmpty ||
            int.tryParse(_duration.text) == null ||
            int.parse(_duration.text) < 5 ||
            int.parse(_duration.text) > 240)) {
      setState(() {
        _stage = 0;
        _error = 'Give the routine a name and a duration of 5–240 minutes.';
      });
      return;
    }
    if (stage == 2) {
      for (final day in _days) {
        for (final row in day.exercises) {
          try {
            if (row.selectedExerciseId == null)
              throw const FormatException('Select an exercise for every row.');
            final sets = int.tryParse(row.sets.text),
                value = int.tryParse(row.reps.text),
                rest = int.tryParse(row.rest.text);
            if (sets == null || value == null || rest == null)
              throw const FormatException('Use whole target values.');
            final ExercisePrescription target =
                row.mode == ExerciseExecutionMode.videoGuidedTimed
                    ? TimedPrescription(
                        sets: sets, durationSeconds: value, restSeconds: rest)
                    : RepetitionPrescription(
                        sets: sets, repetitions: value, restSeconds: rest);
            target.validate();
          } on FormatException catch (error) {
            setState(() {
              _stage = 1;
              _error = error.message;
            });
            return;
          }
        }
      }
    }
    setState(() {
      _stage = stage;
      _error = null;
    });
  }

  void _copyDefaults(_ExerciseDraft row, TutorialVideo item) {
    row.selectedExerciseId = item.id;
    row.mode = item.executionMode ??
        (item.trackingCapability.hasPoseTracking
            ? ExerciseExecutionMode.aiTracked
            : ExerciseExecutionMode.legacyManual);
    row.sourceRevision = item.editRevision;
    final defaults = item.defaultPrescription;
    row.sets.text = '${defaults?.sets ?? 3}';
    row.rest.text = '${defaults?.restSeconds ?? 60}';
    row.reps.text = defaults is TimedPrescription
        ? '${defaults.durationSeconds}'
        : '${defaults is RepetitionPrescription ? defaults.repetitions : 10}';
  }

  @override
  void initState() {
    super.initState();
    if (context.read<TutorialRepository>().requiresCatalogSelection) {
      _loadCatalog();
    }
  }

  Future<void> _loadCatalog() async {
    if (_saving || _reloadRequired) return;
    setState(() {
      _catalogLoading = true;
      _error = null;
    });
    try {
      final entries = await context.read<TutorialRepository>().load();
      if (mounted) {
        setState(() => _catalog = entries
            .where((entry) =>
                !entry.archived && entry.status == TutorialStatus.active)
            .toList());
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not load the exercise catalog. Reload exercises to retry.');
      }
    } finally {
      if (mounted) setState(() => _catalogLoading = false);
    }
  }

  void _repaint() => setState(() {});
  Future<void> _discard() async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
                title: const Text('Discard unsaved routine changes?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('Keep editing')),
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('Discard'))
                ]));
    if (confirmed == true && mounted) widget.onDone();
  }

  @override
  void dispose() {
    _name.dispose();
    _imageUrl.dispose();
    _goal.dispose();
    _duration.dispose();
    for (final d in _days) {
      d.dispose();
    }
    super.dispose();
  }

  void _addDay() => setState(() => _days.add(_DayDraft()));

  void _removeDay(int i) {
    setState(() {
      _days[i].dispose();
      _days.removeAt(i);
    });
  }

  void _addExercise(int dayIndex) =>
      setState(() => _days[dayIndex].exercises.add(_ExerciseDraft()));

  void _removeExercise(int dayIndex, int exIndex) {
    setState(() {
      _days[dayIndex].exercises[exIndex].dispose();
      _days[dayIndex].exercises.removeAt(exIndex);
    });
  }

  void _moveExercise(int dayIndex, int from, int to) {
    if (_saving || _reloadRequired) return;
    final exercises = _days[dayIndex].exercises;
    if (to < 0 || to >= exercises.length) return;
    setState(() => exercises.insert(to, exercises.removeAt(from)));
  }

  Future<void> _save() async {
    if (_saving || _reloadRequired || _catalogLoading || _pickingCover) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give the template a name.');
      return;
    }
    if (_usesCatalog && _name.text.trim().length > 120) {
      setState(() => _error = 'Routine names must be 120 characters or fewer.');
      return;
    }
    if (_days.isEmpty) {
      setState(() => _error = 'Add at least one day.');
      return;
    }
    if (_usesCatalog && _days.length > 14) {
      setState(() => _error = 'A routine can contain at most 14 days.');
      return;
    }
    final duration = int.tryParse(_duration.text.trim());
    if (_usesCatalog && (duration == null || duration < 5 || duration > 240)) {
      setState(() => _error = 'Session duration must be 5–240 whole minutes.');
      return;
    }
    final days = <RoutineDay>[];
    for (var i = 0; i < _days.length; i++) {
      if (_usesCatalog && _days[i].exercises.length > 20) {
        setState(
            () => _error = 'Day ${i + 1} can contain at most 20 exercises.');
        return;
      }
      final exercises = <RoutineExerciseRef>[];
      for (final ex in _days[i].exercises) {
        TutorialVideo? selected;
        if (_usesCatalog && ex.selectedExerciseId != null) {
          for (final entry in _catalog) {
            if (entry.id == ex.selectedExerciseId) selected = entry;
          }
        }
        if (_usesCatalog && selected == null) {
          setState(() => _error =
              'Day ${i + 1}: select an active exercise from the catalog.');
          return;
        }
        final name = _usesCatalog ? selected!.title : ex.name.text.trim();
        if (name.isEmpty) continue;
        final sets = int.tryParse(ex.sets.text.trim());
        final reps = int.tryParse(ex.reps.text.trim());
        if (sets == null ||
            sets <= 0 ||
            reps == null ||
            reps <= 0 ||
            (_usesCatalog &&
                (sets > 50 ||
                    reps >
                        (ex.mode == ExerciseExecutionMode.videoGuidedTimed
                            ? 3600
                            : 100)))) {
          setState(() => _error = _usesCatalog
              ? 'Day ${i + 1}: sets must be 1–50 and reps 1–100.'
              : 'Day ${i + 1}: sets and reps must be whole numbers greater than zero.');
          return;
        }
        ExercisePrescription? target;
        if (_isV2) {
          final rest = int.tryParse(ex.rest.text);
          if (rest == null) {
            setState(() => _error = 'Use whole rest seconds.');
            return;
          }
          target = ex.mode == ExerciseExecutionMode.videoGuidedTimed
              ? TimedPrescription(
                  sets: sets, durationSeconds: reps, restSeconds: rest)
              : RepetitionPrescription(
                  sets: sets, repetitions: reps, restSeconds: rest);
          try {
            target.validate();
          } on FormatException catch (error) {
            setState(() => _error = error.message);
            return;
          }
        }
        exercises.add(RoutineExerciseRef(
            name, sets, target is TimedPrescription ? null : reps,
            exerciseId: selected?.id ?? '',
            entryId: ex.entryId,
            executionMode: _isV2
                ? ex.mode ??
                    (selected!.trackingCapability.hasPoseTracking
                        ? ExerciseExecutionMode.aiTracked
                        : ExerciseExecutionMode.legacyManual)
                : null,
            prescription: target,
            sourceCatalogRevision: ex.sourceRevision));
      }
      if (exercises.isEmpty) {
        setState(() => _error = 'Day ${i + 1} needs at least one exercise.');
        return;
      }
      days.add(RoutineDay(i + 1, exercises));
    }
    final sessionDuration = duration ?? 45;
    if (_usesCatalog &&
        days.fold<int>(0, (sum, day) => sum + day.exercises.length) > 50) {
      setState(() => _error = 'A routine can contain at most 50 exercises.');
      return;
    }

    final blueprint = RoutineBlueprint(
      id: widget.existing?.id ??
          (_usesCatalog ? '' : 'rt${DateTime.now().millisecondsSinceEpoch}'),
      editBaseline: widget.existing?.editBaseline,
      schemaVersion: _isV2 ? 2 : 1,
      name: _name.text.trim(),
      level: _level,
      assignedMembers: 0,
      days: days,
      goal: _goal.text.trim(),
      tags: _tags.toList(),
      sessionDurationMin: sessionDuration,
      equipmentNeeded: _equipmentNeeded,
      imageUrl: _imageUrl.text.trim(),
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = context.read<RoutineTemplateRepository>();
      if (_cover != null) {
        if (repository is! RoutineCoverRepository) {
          throw const RoutineCoverUploadFailed();
        }
        await (repository as RoutineCoverRepository)
            .saveWithCover(blueprint, _cover!);
      } else {
        await repository.save(blueprint);
      }
    } on RoutineCoverUploadFailed {
      if (mounted) {
        setState(() => _error =
            'Could not upload the cover. Your changes are kept. Try saving again.');
      }
      return;
    } on RoutineEditConflict {
      if (mounted) {
        setState(() {
          _reloadRequired = true;
          _error = 'This routine changed. Discard and reload before saving.';
        });
      }
      return;
    } on RoutineEditAuthorizationChanged {
      if (mounted) {
        setState(() {
          _reloadRequired = true;
          _error = 'Your authorization changed. Sign in again.';
        });
      }
      return;
    } on FormatException {
      if (mounted) {
        setState(() => _error =
            'Check the routine fields and active catalog exercises before saving.');
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _reloadRequired = true;
          _error =
              'Could not verify the save. Discard and reload before retrying.';
        });
      }
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    showToast(
        context,
        _usesCatalog
            ? 'Blueprint saved. Publish it to update the Member catalog.'
            : _isEdit
                ? 'Template updated.'
                : 'Template created.');
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageBreadcrumb(crumbs: [
              PageCrumb('Routine Templates', _discard),
              PageCrumb(_isEdit ? 'Edit routine' : 'Create routine'),
            ]),
            const SizedBox(height: 6),
            if (_usesCatalog && widget.existing?.schemaVersion == 1)
              CheckboxListTile(
                  value: _upgradeLegacy,
                  title: const Text('Create an upgraded routine successor'),
                  subtitle: const Text(
                      'Keeps the original published routine and existing workout history.'),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                            _upgradeLegacy = value ?? false;
                            if (_upgradeLegacy) {
                              for (final day in _days) {
                                for (final row in day.exercises) {
                                  final item = _catalog
                                      .where(
                                          (e) => e.id == row.selectedExerciseId)
                                      .firstOrNull;
                                  row.mode = item?.trackingCapability
                                              .hasPoseTracking ==
                                          true
                                      ? ExerciseExecutionMode.aiTracked
                                      : ExerciseExecutionMode.legacyManual;
                                }
                              }
                            }
                          })),
            Text(_isEdit ? 'Edit routine template' : 'Create routine template',
                style: Theme.of(context).textTheme.headlineMedium),
            Wrap(spacing: 8, children: [
              for (var i = 0; i < 3; i++)
                ChoiceChip(
                    label: Text(const ['Details', 'Structure', 'Review'][i]),
                    selected: _stage == i,
                    onSelected: (_) => _selectStage(i))
            ]),
            if (_stage == 2)
              Panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Review effective workout targets'),
                    for (var d = 0; d < _days.length; d++) ...[
                      Text('Day ${d + 1}'),
                      for (final row in _days[d].exercises)
                        Text(
                            '${_catalog.where((e) => e.id == row.selectedExerciseId).firstOrNull?.title ?? row.name.text}: '
                            '${row.sets.text} sets × ${row.reps.text}${row.mode == ExerciseExecutionMode.videoGuidedTimed ? ' seconds' : ' reps'} · ${row.rest.text}s rest'),
                    ],
                    const Text(
                        'Save draft first. Publication is a separate action.'),
                  ])),
            const SizedBox(height: 4),
            Text(
                _usesCatalog
                    ? 'Save an organization routine blueprint, then publish it to the member workout catalog.'
                    : 'Coaches and members can be assigned this blueprint once it is saved.',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 22),
            LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final form = _form(context);
              final summary = _summaryCard(context);
              return wide
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: form),
                          const SizedBox(width: 20),
                          Expanded(flex: 2, child: summary),
                        ],
                      ),
                    )
                  : Column(
                      children: [form, const SizedBox(height: 20), summary]);
            }),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isV2 || _stage == 0) ...[
          const Eyebrow('Template details'),
          Panel(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                            labelText: 'Template name', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _level,
                        decoration: const InputDecoration(
                            labelText: 'Level', isDense: true),
                        items: _levels
                            .map((l) =>
                                DropdownMenuItem(value: l, child: Text(l)))
                            .toList(),
                        onChanged: (v) => setState(() => _level = v ?? _level),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RoutineCoverField(
                    cover: _cover,
                    savedUrl: _imageUrl.text,
                    busy: _pickingCover || (_saving && _cover != null),
                    error: _coverError,
                    onChoose: _reloadRequired ||
                            context.read<RoutineTemplateRepository>()
                                is! RoutineCoverRepository
                        ? null
                        : _chooseCover,
                    onRemove: () {
                      if (_saving || _reloadRequired) return;
                      setState(() {
                        _cover = null;
                        _imageUrl.clear();
                        _coverError = null;
                      });
                    }),
                const SizedBox(height: 12),
                TextField(
                  controller: _goal,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Goal / description', isDense: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Est. session duration (minutes)',
                      isDense: true),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Tags',
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tagOptions.map((t) {
                    final selected = _tags.contains(t);
                    return FilterChip(
                      label: Text(t),
                      selected: selected,
                      onSelected: (v) =>
                          setState(() => v ? _tags.add(t) : _tags.remove(t)),
                      backgroundColor: AppColors.surface,
                      selectedColor: AppColors.primaryTint,
                      labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: selected ? AppColors.primary : AppColors.ink),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: const BorderSide(color: AppColors.hairline)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                EditableStringList(
                  label: 'Equipment needed',
                  items: _equipmentNeeded,
                  onChanged: (v) => _equipmentNeeded = v,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (!_isV2 || _stage == 1) ...[
          const Eyebrow('Day-by-day structure'),
          ...List.generate(
              _days.length, (dayIndex) => _dayEditor(context, dayIndex)),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton.icon(
              onPressed: _addDay,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add day'),
            ),
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_error!,
                style:
                    const TextStyle(fontSize: 12.5, color: AppColors.danger)),
          ),
        if (_usesCatalog &&
            _catalog.isEmpty &&
            !_catalogLoading &&
            !_reloadRequired)
          TextButton(
              onPressed: _loadCatalog, child: const Text('Reload exercises')),
        if (_reloadRequired)
          TextButton(
              onPressed: widget.onDone,
              child: const Text('Discard and reload')),
        const SizedBox(height: 8),
        Row(
          children: [
            if (_isV2 && _stage < 2) ...[
              FilledButton(
                  onPressed: _saving ? null : () => _selectStage(_stage + 1),
                  child: const Text('Continue')),
              const SizedBox(width: 10),
            ],
            OutlinedButton(
                onPressed: _saving ? null : _discard,
                child: const Text('Cancel')),
            const SizedBox(width: 10),
            FilledButton(
                onPressed: _saving ||
                        _catalogLoading ||
                        _reloadRequired ||
                        _pickingCover
                    ? null
                    : _save,
                child: Text(_saving
                    ? 'Saving…'
                    : _isEdit
                        ? 'Save changes'
                        : 'Create template')),
          ],
        ),
      ],
    );
  }

  Widget _dayEditor(BuildContext context, int dayIndex) {
    final day = _days[dayIndex];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Day ${dayIndex + 1}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ),
              if (_days.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 17, color: AppColors.danger),
                  onPressed: () => _removeDay(dayIndex),
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          ...List.generate(day.exercises.length, (exIndex) {
            final ex = day.exercises[exIndex];
            return Padding(
              key: ObjectKey(ex),
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _usesCatalog
                              ? DropdownButtonFormField<String>(
                                  initialValue: _catalog.any((item) =>
                                          item.id == ex.selectedExerciseId)
                                      ? ex.selectedExerciseId
                                      : null,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    hintText: _catalogLoading
                                        ? 'Loading exercises…'
                                        : _catalog.isEmpty
                                            ? 'Add an active exercise first'
                                            : 'Select exercise',
                                    isDense: true,
                                  ),
                                  items: _catalog
                                      .map((item) => DropdownMenuItem(
                                          value: item.id,
                                          child: Row(children: [
                                            Expanded(
                                                child: Text(item.title,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis)),
                                            const SizedBox(width: 8),
                                            Text(
                                                item.trackingCapability
                                                    .displayLabel,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.inkSoft)),
                                          ])))
                                      .toList(),
                                  onChanged: _catalogLoading || _catalog.isEmpty
                                      ? null
                                      : (id) => setState(() {
                                            final item = _catalog
                                                .firstWhere((e) => e.id == id);
                                            if (_isV2) {
                                              _copyDefaults(ex, item);
                                            } else {
                                              ex.selectedExerciseId = id;
                                            }
                                          }),
                                )
                              : TextField(
                                  controller: ex.name,
                                  decoration: const InputDecoration(
                                      hintText: 'Exercise name', isDense: true),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: ex.sets,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                hintText: 'Sets', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: ex.reps,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                                hintText: ex.mode ==
                                        ExerciseExecutionMode.videoGuidedTimed
                                    ? 'Duration (seconds)'
                                    : 'Reps',
                                isDense: true),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: day.exercises.length > 1
                              ? () => _removeExercise(dayIndex, exIndex)
                              : null,
                          constraints:
                              const BoxConstraints(minWidth: 30, minHeight: 30),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    Wrap(spacing: 8, children: [
                      if (_isV2) ...[
                        SizedBox(
                            width: 140,
                            child: TextField(
                                controller: ex.rest,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Rest (seconds)'))),
                        Text(ex.mode == ExerciseExecutionMode.videoGuidedTimed
                            ? 'Video guided · Timer tracked'
                            : ex.mode == ExerciseExecutionMode.aiTracked
                                ? 'AI tracking'
                                : 'Self-reported sets'),
                        TextButton(
                            onPressed: ex.selectedExerciseId == null
                                ? null
                                : () => setState(() => _copyDefaults(
                                    ex,
                                    _catalog.firstWhere(
                                        (e) => e.id == ex.selectedExerciseId))),
                            child: const Text('Reset to exercise defaults')),
                      ],
                      TextButton.icon(
                          onPressed: exIndex == 0 || _saving || _reloadRequired
                              ? null
                              : () =>
                                  _moveExercise(dayIndex, exIndex, exIndex - 1),
                          icon: const Icon(Icons.arrow_upward, size: 16),
                          label: const Text('Move up')),
                      TextButton.icon(
                          onPressed: exIndex == day.exercises.length - 1 ||
                                  _saving ||
                                  _reloadRequired
                              ? null
                              : () =>
                                  _moveExercise(dayIndex, exIndex, exIndex + 1),
                          icon: const Icon(Icons.arrow_downward, size: 16),
                          label: const Text('Move down')),
                    ]),
                  ]),
            );
          }),
          TextButton.icon(
            onPressed: () => _addExercise(dayIndex),
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('Add exercise'),
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context) {
    final totalExercises =
        _days.fold<int>(0, (sum, d) => sum + d.exercises.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Summary'),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _cover == null
                        ? _networkHero(_imageUrl.text)
                        : Image.memory(_cover!.copyBytes(),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            semanticLabel: 'Selected routine cover',
                            errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image_outlined)))),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: _summaryDetails(context, totalExercises),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          background: AppColors.primaryTint,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _usesCatalog
                      ? 'Saving changes this blueprint only. Publish again after routine or catalog edits, then refresh Home or Workout in the Member app. Publication does not assign a workout or record activity.'
                      : 'Coaches see this in their routine picker as soon as it is saved — members already following an assigned routine are unaffected until reassigned.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryDetails(BuildContext context, int totalExercises) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_name.text.isEmpty ? 'Untitled template' : _name.text,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        DetailRow('Level', _level),
        const Divider(height: 20),
        DetailRow('Days', '${_days.length}'),
        const Divider(height: 20),
        DetailRow('Exercises', '$totalExercises total'),
        const Divider(height: 20),
        DetailRow('Session length',
            '${_duration.text.isEmpty ? '0' : _duration.text} min'),
        if (_tags.isNotEmpty) ...[
          const Divider(height: 20),
          DetailRow('Tags', _tags.join(', ')),
        ],
      ],
    );
  }
}
