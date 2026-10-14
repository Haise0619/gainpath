import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/published_routine_catalog_cubit.dart';

/// Small controls inside the existing preparation layout; selection is a
/// published content ID, never an exercise label or assignment command.
class PublishedRoutineCatalogControls extends StatelessWidget {
  const PublishedRoutineCatalogControls(
      {super.key,
      required this.state,
      required this.onRefresh,
      required this.onSelect,
      required this.onLoadMore});
  final PublishedRoutineCatalogState state;
  final Future<void> Function() onRefresh, onLoadMore;
  final void Function(String) onSelect;
  @override
  Widget build(BuildContext context) {
    final entries = {
      for (final item in state.items) item.id: item,
      if (state.selected != null) state.selected!.id: state.selected!
    };
    final loading = state.status == CatalogStatus.loading;
    final available = state.status != CatalogStatus.unavailable;
    return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('Published routines')),
        IconButton(
            tooltip: 'Refresh routines',
            onPressed: loading || !available ? null : onRefresh,
            icon: const Icon(Icons.refresh)),
      ]),
      if (loading) const LinearProgressIndicator(),
      if (!loading && entries.isNotEmpty)
        DropdownButtonFormField<String>(
          key: ValueKey((state.selected?.id, entries.keys.join(','))),
          initialValue: state.selected?.id,
          isExpanded: true,
          decoration:
              const InputDecoration(labelText: 'Choose published routine'),
          items: entries.values
              .map((item) => DropdownMenuItem(
                  value: item.id,
                  child: Text('${item.title} · ${item.id}',
                      overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: state.status == CatalogStatus.ready
              ? (id) {
                  if (id != null) onSelect(id);
                }
              : null,
        ),
      if (state.status == CatalogStatus.empty)
        const Text(
            'No published routines are available for this organization.'),
      if (state.message != null) Text(state.message!),
      if (state.nextCursor != null)
        TextButton(
            onPressed: state.loadingMore ? null : onLoadMore,
            child: Text(
                state.loadingMore ? 'Loading more…' : 'Load more routines')),
    ]));
  }
}
