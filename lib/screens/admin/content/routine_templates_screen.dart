import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import '../admin_dialogs.dart';

/// AD-M11.4 — Manage Routine Templates. Previously a stub — the Content
/// hub's card linked here only to show a toast ("Routine template
/// editor.") with no real screen or data behind it at all. Backed now by
/// `MockData.routineTemplates`; each card expands in place to show its
/// full day-by-day breakdown rather than pushing into a separate route,
/// and both the metadata and the day/exercise structure are genuinely
/// editable through `_TemplateFormDialog` below.
class RoutineTemplatesScreen extends StatefulWidget {
  const RoutineTemplatesScreen({super.key});

  @override
  State<RoutineTemplatesScreen> createState() => _RoutineTemplatesScreenState();
}

class _RoutineTemplatesScreenState extends State<RoutineTemplatesScreen> {
  String? _expandedId;

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
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
                  onPressed: () async {
                    final saved =
                        await showDialog<bool>(context: context, builder: (ctx) => const _TemplateFormDialog());
                    if (saved == true) _refresh();
                  },
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
                    onEdited: _refresh,
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
  final VoidCallback onEdited;
  const _TemplateCard(
      {required this.template, required this.expanded, required this.onToggle, required this.onEdited});

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
                  Container(
                    width: 40,
                    height: 40,
                    decoration:
                        BoxDecoration(color: _levelColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)),
                    child: Icon(Icons.list_alt_rounded, size: 19, color: _levelColor),
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
                    onPressed: () async {
                      final saved = await showDialog<bool>(
                          context: context, builder: (ctx) => _TemplateFormDialog(existing: template));
                      if (saved == true) onEdited();
                    },
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

class _TemplateFormDialog extends StatefulWidget {
  final RoutineBlueprint? existing;
  const _TemplateFormDialog({this.existing});

  @override
  State<_TemplateFormDialog> createState() => _TemplateFormDialogState();
}

class _TemplateFormDialogState extends State<_TemplateFormDialog> {
  static const _levels = ['Beginner', 'Intermediate', 'Advanced'];

  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late String _level = widget.existing?.level ?? _levels.first;
  late final List<_DayDraft> _days = widget.existing == null
      ? [_DayDraft()]
      : widget.existing!.days
          .map((d) => _DayDraft(d.exercises
              .map((e) => _ExerciseDraft(name: e.exerciseName, sets: '${e.sets}', reps: '${e.reps}'))
              .toList()))
          .toList();
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
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

    if (_isEdit) {
      widget.existing!
        ..name = _name.text.trim()
        ..level = _level
        ..days = days;
    } else {
      MockData.routineTemplates.add(RoutineBlueprint(
        id: 'rt${DateTime.now().millisecondsSinceEpoch}',
        name: _name.text.trim(),
        level: _level,
        assignedMembers: 0,
        days: days,
      ));
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AdminDialog(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isEdit ? 'Edit routine template' : 'New routine template',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
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
            const SizedBox(height: 18),
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
                Expanded(
                  child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(onPressed: _save, child: Text(_isEdit ? 'Save changes' : 'Create template')),
                ),
              ],
            ),
          ],
        ),
      ),
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
}
