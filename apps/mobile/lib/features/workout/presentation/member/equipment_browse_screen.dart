import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../shared/equipment_detail_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/workout.dart';

/// Defensive network image loader: a broken/slow link never breaks the
/// layout — the same pattern used across onboarding, profile setup, and
/// the workout module.
Widget _networkHero(String url, {BoxFit fit = BoxFit.cover}) {
  if (url.trim().isEmpty) {
    return const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.heroGradient));
  }
  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : const SizedBox.shrink(),
    errorBuilder: (context, error, stack) => const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.heroGradient)),
  );
}

/// Direct, browsable alternative to scanning — the equipment catalogue
/// as a grid, filterable by category. Reachable both from the scanner's
/// app-bar action and from its "couldn't recognise this" fallback.
class EquipmentBrowseScreen extends StatefulWidget {
  const EquipmentBrowseScreen({super.key, this.reader});
  final EquipmentReader? reader;

  @override
  State<EquipmentBrowseScreen> createState() => _EquipmentBrowseScreenState();
}

class _EquipmentBrowseScreenState extends State<EquipmentBrowseScreen> {
  String _category = 'All';
  List<GymEquipment> _items = [];
  bool _loading = false;
  String? _error, _cursor;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    if (widget.reader != null) _load();
  }

  @override
  void didUpdateWidget(EquipmentBrowseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reader != widget.reader && widget.reader != null) _load();
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _items = [];
        _cursor = null;
      }
    });
    try {
      final page =
          await widget.reader!.loadEquipment(afterId: more ? _cursor : null);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = [..._items, ...page.items.where((e) => e.isActive)];
        _cursor = page.nextCursor;
        _loading = false;
        if (_category != 'All' && !_items.any((e) => e.category == _category)) {
          _category = 'All';
        }
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _items = [];
          _cursor = null;
          _loading = false;
          _error = 'Could not load equipment. Refresh or retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.reader != null;
    final published = live
        ? _items
        : context
            .read<EquipmentRepository>()
            .gymEquipment
            .where((e) => e.isActive)
            .toList();
    final categories = [
      'All',
      ...{for (final e in published) e.category}
    ];
    final visible = _category == 'All'
        ? published
        : published.where((e) => e.category == _category).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Equipment'), actions: [
        if (live)
          IconButton(
              tooltip: 'Refresh equipment',
              onPressed: _loading ? null : () => _load(),
              icon: const Icon(Icons.refresh))
      ]),
      body: Column(
        children: [
          if (live)
            const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                    'Organization equipment catalog. Camera recognition and equipment video playback are unavailable.')),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Panel(
                child: Column(children: [
              Text(_error!),
              TextButton(
                  onPressed: () => _load(),
                  child: const Text('Retry equipment'))
            ])),
          if (live && !_loading && _error == null && published.isEmpty)
            const Panel(child: Text('No active equipment is available.')),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: categories.map((c) {
                final selected = c == _category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: selected,
                    onSelected: (_) => setState(() => _category = c),
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.ink,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: const BorderSide(color: AppColors.hairline),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: visible.length,
              itemBuilder: (ctx, i) =>
                  _EquipmentCard(equipment: visible[i], live: live),
            ),
          ),
          if (_cursor != null)
            TextButton(
                onPressed: _loading ? null : () => _load(more: true),
                child: const Text('Load more equipment')),
        ],
      ),
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  final GymEquipment equipment;
  final bool live;
  const _EquipmentCard({required this.equipment, this.live = false});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  EquipmentDetailScreen(equipment: equipment, live: live))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              color: const Color(0xFFF3F4F8),
              child: AspectRatio(
                aspectRatio: 16 / 11,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _networkHero(equipment.imageUrl, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(equipment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(equipment.muscleGroup,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
