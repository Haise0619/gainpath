import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// AD-M11.4 — Manage Routine Templates. Previously a stub — the Content
/// hub's card linked here only to show a toast ("Routine template
/// editor.") with no real screen or data behind it at all. Backed now by
/// `MockData.routineTemplates`; each card expands in place to show its
/// full day-by-day breakdown rather than pushing into a separate route.
class RoutineTemplatesScreen extends StatefulWidget {
  const RoutineTemplatesScreen({super.key});

  @override
  State<RoutineTemplatesScreen> createState() => _RoutineTemplatesScreenState();
}

class _RoutineTemplatesScreenState extends State<RoutineTemplatesScreen> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    const templates = MockData.routineTemplates;
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
                  onPressed: () => showToast(context, 'Opening the routine builder.'),
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
  const _TemplateCard({required this.template, required this.expanded, required this.onToggle});

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
                    onPressed: () => showToast(context, 'Edit ${template.name}.'),
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
