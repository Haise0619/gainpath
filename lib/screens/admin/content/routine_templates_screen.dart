import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import '../admin_breadcrumb.dart';
import '../equipment/equipment_catalog_screen.dart' show EditableStringList;

Widget _networkHero(String url, {BoxFit fit = BoxFit.cover}) {
  if (url.trim().isEmpty) {
    return const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient));
  }
  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : Container(color: AppColors.surfaceAlt),
    errorBuilder: (context, error, stack) =>
        const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
  );
}

/// AD-M11.4 — Manage Routine Templates. Previously a stub — the Content
/// hub's card linked here only to show a toast ("Routine template
/// editor.") with no real screen or data behind it at all. Backed now by
/// `MockData.routineTemplates`; each card expands in place to show its
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

  void _openCreate() => setState(() => _creating = true);
  void _openEdit(RoutineBlueprint t) => setState(() => _editing = t);
  void _closeForm() => setState(() {
        _creating = false;
        _editing = null;
      });

  @override
  Widget build(BuildContext context) {
    if (_creating || _editing != null) {
      return _TemplateFormPage(existing: _editing, onDone: _closeForm);
    }

    final templates = MockData.routineTemplates;
    final totalAssigned = templates.fold<int>(0, (sum, t) => sum + t.assignedMembers);

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
                    '${templates.length} templates · $totalAssigned members currently following one',
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
                    onToggle: () => setState(() => _expandedId = _expandedId == t.id ? null : t.id),
                    onEdit: () => _openEdit(t),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final RoutineBlueprint template;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  const _TemplateCard(
      {required this.template, required this.expanded, required this.onToggle, required this.onEdit});

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
                              child: Icon(Icons.list_alt_rounded, size: 19, color: _levelColor),
                            )
                          : _networkHero(template.imageUrl),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(template.name, style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          '${template.level}  ·  ${template.days.length}-day split  ·  ${template.assignedMembers} following',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: onEdit,
                  ),
                  Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
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
                          Text(template.goal, style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 10),
                        ],
                        if (template.tags.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: template.tags
                                .map((t) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: AppColors.primaryTint, borderRadius: BorderRadius.circular(999)),
                                      child: Text(t,
                                          style: const TextStyle(
                                              fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
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
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                  const SizedBox(height: 4),
                                  ...d.exercises.map((e) => Padding(
                                        padding: const EdgeInsets.only(bottom: 3, left: 4),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.circle, size: 4, color: AppColors.inkSoft),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text('${e.exerciseName}  ·  ${e.sets} × ${e.reps}',
                                                  style: const TextStyle(fontSize: 13)),
                                            ),
                                          ],
                                        ),
                                      )),
                                ],
                              ),
                            )),
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
  _ExerciseDraft({String name = '', String sets = '3', String reps = '10'})
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
  _DayDraft([List<_ExerciseDraft>? exercises]) : exercises = exercises ?? [_ExerciseDraft()];

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
  static const _tagOptions = ['Fat loss', 'Muscle gain', 'General fitness', 'Strength', 'Mobility'];

  late final _name = TextEditingController(text: widget.existing?.name ?? '')..addListener(_repaint);
  late final _imageUrl = TextEditingController(text: widget.existing?.imageUrl ?? '')..addListener(_repaint);
  late final _goal = TextEditingController(text: widget.existing?.goal ?? '');
  late final _duration = TextEditingController(text: '${widget.existing?.sessionDurationMin ?? 45}');
  late String _level = widget.existing?.level ?? _levels.first;
  late final Set<String> _tags = {...(widget.existing?.tags ?? const [])};
  late List<String> _equipmentNeeded = [...(widget.existing?.equipmentNeeded ?? const [])];
  late final List<_DayDraft> _days = widget.existing == null
      ? [_DayDraft()]
      : widget.existing!.days
          .map((d) => _DayDraft(d.exercises
              .map((e) => _ExerciseDraft(name: e.exerciseName, sets: '${e.sets}', reps: '${e.reps}'))
              .toList()))
          .toList();
  String? _error;

  bool get _isEdit => widget.existing != null;

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

  void _addExercise(int dayIndex) => setState(() => _days[dayIndex].exercises.add(_ExerciseDraft()));

  void _removeExercise(int dayIndex, int exIndex) {
    setState(() {
      _days[dayIndex].exercises[exIndex].dispose();
      _days[dayIndex].exercises.removeAt(exIndex);
    });
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give the template a name.');
      return;
    }
    if (_days.isEmpty) {
      setState(() => _error = 'Add at least one day.');
      return;
    }
    final days = <RoutineDay>[];
    for (var i = 0; i < _days.length; i++) {
      final exercises = <RoutineExerciseRef>[];
      for (final ex in _days[i].exercises) {
        final name = ex.name.text.trim();
        if (name.isEmpty) continue;
        final sets = int.tryParse(ex.sets.text.trim());
        final reps = int.tryParse(ex.reps.text.trim());
        if (sets == null || sets <= 0 || reps == null || reps <= 0) {
          setState(() => _error = 'Day ${i + 1}: sets and reps must be whole numbers greater than zero.');
          return;
        }
        exercises.add(RoutineExerciseRef(name, sets, reps));
      }
      if (exercises.isEmpty) {
        setState(() => _error = 'Day ${i + 1} needs at least one exercise.');
        return;
      }
      days.add(RoutineDay(i + 1, exercises));
    }
    final duration = int.tryParse(_duration.text.trim()) ?? 45;

    if (_isEdit) {
      widget.existing!
        ..name = _name.text.trim()
        ..level = _level
        ..days = days
        ..goal = _goal.text.trim()
        ..tags = _tags.toList()
        ..sessionDurationMin = duration
        ..equipmentNeeded = _equipmentNeeded
        ..imageUrl = _imageUrl.text.trim();
    } else {
      MockData.routineTemplates.add(RoutineBlueprint(
        id: 'rt${DateTime.now().millisecondsSinceEpoch}',
        name: _name.text.trim(),
        level: _level,
        assignedMembers: 0,
        days: days,
        goal: _goal.text.trim(),
        tags: _tags.toList(),
        sessionDurationMin: duration,
        equipmentNeeded: _equipmentNeeded,
        imageUrl: _imageUrl.text.trim(),
      ));
    }
    showToast(context, _isEdit ? 'Template updated.' : 'Template created.');
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
            Text('Coaches and members can be assigned this blueprint once it is saved.',
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
                  : Column(children: [form, const SizedBox(height: 20), summary]);
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
                      decoration: const InputDecoration(labelText: 'Template name', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _level,
                      decoration: const InputDecoration(labelText: 'Level', isDense: true),
                      items: _levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                      onChanged: (v) => setState(() => _level = v ?? _level),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _imageUrl,
                decoration: const InputDecoration(labelText: 'Cover image URL', isDense: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _goal,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Goal / description', isDense: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _duration,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Est. session duration (minutes)', isDense: true),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Tags', style: Theme.of(context).textTheme.bodyMedium),
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
                    onSelected: (v) => setState(() => v ? _tags.add(t) : _tags.remove(t)),
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.primaryTint,
                    labelStyle: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.ink),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999), side: const BorderSide(color: AppColors.hairline)),
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
        ...List.generate(_days.length, (dayIndex) => _dayEditor(context, dayIndex)),
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
            child: Text(_error!, style: const TextStyle(fontSize: 12.5, color: AppColors.danger)),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton(onPressed: widget.onDone, child: const Text('Cancel')),
            const SizedBox(width: 10),
            FilledButton(onPressed: _save, child: Text(_isEdit ? 'Save changes' : 'Create template')),
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
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
              if (_days.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 17, color: AppColors.danger),
                  onPressed: () => _removeDay(dayIndex),
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
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
                    child: TextField(
                      controller: ex.name,
                      decoration: const InputDecoration(hintText: 'Exercise name', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: ex.sets,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Sets', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: ex.reps,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Reps', isDense: true),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: day.exercises.length > 1 ? () => _removeExercise(dayIndex, exIndex) : null,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
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
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context) {
    final totalExercises = _days.fold<int>(0, (sum, d) => sum + d.exercises.length);
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(aspectRatio: 16 / 9, child: _networkHero(_imageUrl.text)),
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
              const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Coaches see this in their routine picker as soon as it is saved — members already following an assigned routine are unaffected until reassigned.',
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
        DetailRow('Session length', '${_duration.text.isEmpty ? '0' : _duration.text} min'),
        if (_tags.isNotEmpty) ...[
          const Divider(height: 20),
          DetailRow('Tags', _tags.join(', ')),
        ],
      ],
    );
  }
}
