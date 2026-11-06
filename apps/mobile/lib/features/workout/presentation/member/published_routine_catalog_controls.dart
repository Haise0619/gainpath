import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/published_routine_catalog_cubit.dart';
import '../../domain/published_routine_view.dart';
import 'widgets/workout_exercise_image.dart';

/// A temporary free-workout choice; selecting never changes a program schedule.
class PublishedRoutineCatalogControls extends StatelessWidget {
  const PublishedRoutineCatalogControls(
      {super.key,
      required this.state,
      required this.onRefresh,
      required this.onSelect,
      required this.onLoadMore,
      this.catalogCubit,
      this.inHero,
      this.scheduledTitle,
      this.scheduledSelected = false,
      this.onChooseScheduled});
  final PublishedRoutineCatalogState state;
  final Future<void> Function() onRefresh, onLoadMore;
  final void Function(String) onSelect;
  final PublishedRoutineCatalogCubit? catalogCubit;
  final bool? inHero;
  final String? scheduledTitle;
  final bool scheduledSelected;
  final VoidCallback? onChooseScheduled;

  void _browse(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        Widget content(PublishedRoutineCatalogState current) => _RoutineBrowser(
              state: current,
              onRefresh: onRefresh,
              onLoadMore: onLoadMore,
              scheduledTitle: scheduledTitle,
              scheduledSelected: scheduledSelected,
              onChooseScheduled: onChooseScheduled == null
                  ? null
                  : () {
                      onChooseScheduled!();
                      Navigator.of(sheetContext).pop();
                    },
              onSelect: (id) {
                onSelect(id);
                Navigator.of(sheetContext).pop();
              },
            );
        final cubit = catalogCubit;
        return cubit == null
            ? content(state)
            : BlocBuilder<PublishedRoutineCatalogCubit,
                    PublishedRoutineCatalogState>(
                bloc: cubit, builder: (_, current) => content(current));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (inHero ?? (state.selected != null || scheduledTitle != null)) {
      return TextButton.icon(
        onPressed: state.status == CatalogStatus.loading
            ? null
            : () => _browse(context),
        icon: const Icon(Icons.swap_horiz_rounded, size: 19),
        label: const Text('Change workout'),
        style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8)),
      );
    }
    final loading = state.status == CatalogStatus.loading;
    return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(loading ? 'Loading workouts…' : 'Find a workout',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (loading)
        const LinearProgressIndicator()
      else ...[
        Text(switch (state.status) {
          CatalogStatus.empty =>
            'No workouts are available yet. Check back later.',
          CatalogStatus.error =>
            'Could not load workouts. Check your connection and try again.',
          CatalogStatus.unavailable =>
            'Workouts are unavailable for this session.',
          _ => 'Choose an available workout to see its exercises.',
        }),
        const SizedBox(height: 12),
        if (scheduledTitle != null && onChooseScheduled != null)
          TextButton.icon(
              onPressed: onChooseScheduled,
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('View planned workout')),
        if (state.status == CatalogStatus.ready && state.items.isNotEmpty)
          FilledButton(
              onPressed: () => _browse(context),
              child: const Text('Browse workouts'))
        else if (state.status != CatalogStatus.unavailable)
          OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh workouts')),
      ],
    ]));
  }
}

class _RoutineBrowser extends StatelessWidget {
  const _RoutineBrowser(
      {required this.state,
      required this.onRefresh,
      required this.onLoadMore,
      required this.onSelect,
      this.scheduledTitle,
      this.scheduledSelected = false,
      this.onChooseScheduled});
  final String? scheduledTitle;
  final bool scheduledSelected;
  final VoidCallback? onChooseScheduled;
  final PublishedRoutineCatalogState state;
  final Future<void> Function() onRefresh, onLoadMore;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final entries = <String, PublishedRoutine>{
      for (final item in state.items) item.id: item,
      if (state.selected != null) state.selected!.id: state.selected!,
    }.values.toList(growable: false);
    return SafeArea(
        child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .76,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(children: [
              Expanded(
                  child: Text('Choose a workout',
                      style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                  tooltip: 'Refresh routines',
                  onPressed:
                      state.status == CatalogStatus.loading ? null : onRefresh,
                  icon: const Icon(Icons.refresh_rounded)),
            ])),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child:
                Text('Choosing a workout does not change your training plan.')),
        if (scheduledTitle != null && onChooseScheduled != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                      color: scheduledSelected
                          ? AppColors.primary
                          : AppColors.hairline)),
              leading: const Icon(Icons.calendar_month_outlined,
                  color: AppColors.primary),
              title: Text(scheduledTitle!),
              subtitle: const Text('From your training plan'),
              trailing: scheduledSelected
                  ? const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary)
                  : const Icon(Icons.chevron_right_rounded),
              onTap: onChooseScheduled,
            ),
          ),
        const SizedBox(height: 8),
        if (state.status == CatalogStatus.loading)
          const LinearProgressIndicator(),
        if (state.message != null)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(state.status == CatalogStatus.error
                  ? 'Could not load workouts. Refresh to try again.'
                  : state.selected == null
                      ? 'That workout is no longer available. Choose another.'
                      : 'Could not load more workouts. Try again.')),
        Expanded(
            child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: entries.length + (state.nextCursor == null ? 0 : 1),
          itemBuilder: (context, index) {
            if (index == entries.length) {
              return TextButton(
                  onPressed: state.loadingMore ? null : onLoadMore,
                  child: Text(state.loadingMore
                      ? 'Loading more…'
                      : 'Show more workouts'));
            }
            final item = entries[index];
            final duplicate =
                entries.where((e) => e.title == item.title).length > 1;
            final isSelected =
                !scheduledSelected && item.id == state.selected?.id;
            return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.hairline)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: state.status == CatalogStatus.ready
                        ? () => onSelect(item.id)
                        : null,
                    child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(children: [
                          ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: WorkoutExerciseImage(
                                      url: item.exercises.isEmpty
                                          ? ''
                                          : item.exercises.first.imageUrl))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(item.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 3),
                                Text(
                                    '${item.exercises.length} exercises · about ${item.estimatedMinutes} min',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium),
                                if (duplicate)
                                  Text('Option ${index + 1}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                if (item.difficulty != null)
                                  Text(item.difficulty!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                              ])),
                          Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.chevron_right_rounded,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.inkSoft),
                        ])),
                  ),
                ));
          },
        )),
      ]),
    ));
  }
}
