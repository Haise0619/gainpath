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
  const RoutineTemplatesScreen({super.key});

  @override
  State<RoutineTemplatesScreen> createState() => _RoutineTemplatesScreenState();
}

class _RoutineTemplatesScreenState extends State<RoutineTemplatesScreen> {
  String? _expandedId;
  RoutineBlueprint? _editing;
  bool _creating = false;
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

  Future<void> _publish(RoutineBlueprint blueprint) async {
    if (_publishingId != null) return;
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
                    FilledButton.icon(
                      onPressed: _openCreate,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New template'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ...templates.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TemplateCard(
                        template: t,
                        expanded: _expandedId == t.id,
                        onToggle: () => setState(() =>
                            _expandedId = _expandedId == t.id ? null : t.id),
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
  final RoutineBlueprint template;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final bool publishing;
  final bool firebaseCatalog;
  const _TemplateCard(
      {required this.template,
      required this.expanded,
      required this.onToggle,
      required this.onEdit,
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
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: onEdit,
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
                                                  '${e.exerciseName}  ·  ${e.sets} × ${e.reps}',
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
                            onPressed: publishing ? null : onPublish,
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
  final TextEditingController name;
  final TextEditingController sets;
  final TextEditingController reps;
  String? selectedExerciseId;
  _ExerciseDraft(
      {String name = '',
      String sets = '3',
      String reps = '10',
      this.selectedExerciseId})
      : name = TextEditingController(text: name),
        sets = TextEditingController(text: sets),
        reps = TextEditingController(text: reps);

  void dispose() {
    name.dispose();
    sets.dispose();
    reps.dispose();
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
                  reps: '${e.reps}',
                  selectedExerciseId:
                      e.exerciseId.isEmpty ? null : e.exerciseId))
              .toList()))
          .toList();
  String? _error;
  List<TutorialVideo> _catalog = const [];
  bool _catalogLoading = false;
  bool _saving = false;
  bool _reloadRequired = false;
  bool get _usesCatalog =>
      context.read<TutorialRepository>().requiresCatalogSelection;

  bool get _isEdit => widget.existing != null;

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
            .where((entry) => entry.status == TutorialStatus.active)
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

  Future<void> _save() async {
    if (_saving || _reloadRequired || _catalogLoading) return;
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
            (_usesCatalog && (sets > 50 || reps > 100))) {
          setState(() => _error = _usesCatalog
              ? 'Day ${i + 1}: sets must be 1–50 and reps 1–100.'
              : 'Day ${i + 1}: sets and reps must be whole numbers greater than zero.');
          return;
        }
        exercises.add(RoutineExerciseRef(name, sets, reps,
            exerciseId: selected?.id ?? ''));
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
      await context.read<RoutineTemplateRepository>().save(blueprint);
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
              PageCrumb('Routine Templates', widget.onDone),
              PageCrumb(_isEdit ? 'Edit routine' : 'Create routine'),
            ]),
            const SizedBox(height: 6),
            Text(_isEdit ? 'Edit routine template' : 'Create routine template',
                style: Theme.of(context).textTheme.headlineMedium),
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
                          .map(
                              (l) => DropdownMenuItem(value: l, child: Text(l)))
                          .toList(),
                      onChanged: (v) => setState(() => _level = v ?? _level),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _imageUrl,
                decoration: const InputDecoration(
                    labelText: 'Cover image URL', isDense: true),
              ),
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
                child:
                    Text('Tags', style: Theme.of(context).textTheme.bodyMedium),
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
        const SizedBox(height: 18),
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
            OutlinedButton(
                onPressed: _saving ? null : widget.onDone,
                child: const Text('Cancel')),
            const SizedBox(width: 10),
            FilledButton(
                onPressed: _saving || _catalogLoading || _reloadRequired
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
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _usesCatalog
                        ? DropdownButtonFormField<String>(
                            initialValue: _catalog.any(
                                    (item) => item.id == ex.selectedExerciseId)
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
                                    value: item.id, child: Text(item.title)))
                                .toList(),
                            onChanged: _catalogLoading || _catalog.isEmpty
                                ? null
                                : (id) =>
                                    setState(() => ex.selectedExerciseId = id),
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
                      decoration: const InputDecoration(
                          hintText: 'Reps', isDense: true),
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
                    aspectRatio: 16 / 9, child: _networkHero(_imageUrl.text)),
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
