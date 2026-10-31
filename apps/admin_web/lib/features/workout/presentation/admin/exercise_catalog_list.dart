import 'package:flutter/material.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'exercise_video_preview.dart';

/// Presentation for catalog lifecycle; repositories own transitions and checks.
class ExerciseCatalogList extends StatelessWidget {
  const ExerciseCatalogList(
      {super.key,
      required this.tutorials,
      required this.catalogOnly,
      required this.filter,
      required this.onFilter,
      required this.onReload,
      required this.onAdd,
      required this.onEdit,
      this.onDelete,
      this.onStatusChange,
      this.busy = false,
      this.error});
  final List<TutorialVideo> tutorials;
  final bool catalogOnly, busy;
  final ExerciseCatalogStatus? filter;
  final String? error;
  final void Function(ExerciseCatalogStatus?) onFilter;
  final VoidCallback onReload, onAdd;
  final void Function(TutorialVideo) onEdit;
  final void Function(TutorialVideo)? onDelete;
  final void Function(TutorialVideo, ExerciseCatalogStatus)? onStatusChange;
  bool get blocked => busy || error != null;

  @override
  Widget build(BuildContext context) {
    final rows = tutorials
        .where((t) => filter == null || t.catalogStatus == filter)
        .toList();
    int count(ExerciseCatalogStatus status) =>
        tutorials.where((t) => t.catalogStatus == status).length;
    return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (catalogOnly) ...[
            Text('Exercise Catalog',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            const Text(
                'Build routines with AI-tracked and guided-only exercises. Tracking availability is checked by the system.'),
            const SizedBox(height: 18),
          ],
          Text(
              '${count(ExerciseCatalogStatus.active)} active · ${count(ExerciseCatalogStatus.inactive)} inactive · ${count(ExerciseCatalogStatus.archived)} archived',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                    tooltip: 'Reload catalog',
                    icon: const Icon(Icons.refresh),
                    onPressed: busy ? null : onReload),
                FilledButton.icon(
                    onPressed: blocked ? null : onAdd,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(catalogOnly ? 'Add exercise' : 'Add tutorial')),
              ]),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(
                label: const Text('All'),
                selected: filter == null,
                onSelected: busy ? null : (_) => onFilter(null)),
            for (final status in ExerciseCatalogStatus.values)
              ChoiceChip(
                  label: Text(status.label),
                  selected: filter == status,
                  onSelected: busy ? null : (_) => onFilter(status)),
          ]),
          const SizedBox(height: 20),
          if (rows.isEmpty)
            const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No exercises match this status.'))
          else
            Panel(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _entry(context, rows[i]),
                  ],
                ])),
        ]));
  }

  Widget _entry(BuildContext context, TutorialVideo item) => Padding(
      key: ValueKey('exercise-row-${item.id}'),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
            onTap: blocked || item.archived ? null : () => onEdit(item),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                              width: 44,
                              height: 44,
                              child: item.thumbnailUrl.isEmpty
                                  ? const ColoredBox(
                                      color: AppColors.ink,
                                      child: Icon(Icons.fitness_center,
                                          color: Colors.white))
                                  : Image.network(item.thumbnailUrl,
                                      fit: BoxFit.cover,
                                      webHtmlElementStrategy:
                                          WebHtmlElementStrategy.prefer,
                                      errorBuilder: (_, __, ___) =>
                                          const ColoredBox(
                                              color: AppColors.surfaceAlt)))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(item.title,
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(
                                catalogOnly
                                    ? '${item.category} · ${item.trackingCapability.displayLabel}\nID ${item.id}'
                                    : '${item.category} · ${item.durationMin} min',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ])),
                    ]))),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              statusPill(item.archived
                  ? 'Archived'
                  : catalogOnly
                      ? item.catalogStatus.label
                      : item.status.label),
              if (item.videoUrl.trim().isNotEmpty)
                IconButton(
                    tooltip: 'Preview tutorial video',
                    icon: const Icon(Icons.play_circle_outline),
                    onPressed: busy
                        ? null
                        : () => showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                                    title: Text(item.title),
                                    content: SizedBox(
                                        width: 640,
                                        child: ExerciseVideoPreview(
                                            url: item.videoUrl)),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Close'))
                                    ]))),
              if (!item.archived)
                TextButton.icon(
                    onPressed: blocked ? null : () => onEdit(item),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit')),
              if (onStatusChange != null)
                TextButton.icon(
                    key: ValueKey('exercise-status-${item.id}'),
                    onPressed: blocked
                        ? null
                        : () => onStatusChange!(
                            item,
                            item.archived ||
                                    item.catalogStatus ==
                                        ExerciseCatalogStatus.active
                                ? ExerciseCatalogStatus.inactive
                                : ExerciseCatalogStatus.active),
                    icon: Icon(
                        item.archived
                            ? Icons.unarchive_outlined
                            : item.catalogStatus == ExerciseCatalogStatus.active
                                ? Icons.pause_circle_outline
                                : Icons.check_circle_outline,
                        size: 18),
                    label: Text(item.archived
                        ? 'Restore'
                        : item.catalogStatus == ExerciseCatalogStatus.active
                            ? 'Deactivate'
                            : 'Activate')),
              if (!item.archived && onDelete != null)
                Tooltip(
                    message: 'Delete exercise',
                    child: TextButton.icon(
                        key: ValueKey('exercise-delete-${item.id}'),
                        onPressed: blocked ? null : () => onDelete!(item),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete'))),
            ]),
      ]));
}
