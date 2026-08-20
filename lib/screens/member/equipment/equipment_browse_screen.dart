import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import 'equipment_detail_screen.dart';

/// Defensive network image loader: a broken/slow link never breaks the
/// layout — the same pattern used across onboarding, profile setup, and
/// the workout module.
Widget _networkHero(String url, {BoxFit fit = BoxFit.cover}) {
  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : Container(color: AppColors.surfaceAlt),
    errorBuilder: (context, error, stack) =>
        const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
  );
}

/// Direct, browsable alternative to scanning — the equipment catalogue
/// as a grid, filterable by category. Reachable both from the scanner's
/// app-bar action and from its "couldn't recognise this" fallback.
class EquipmentBrowseScreen extends StatefulWidget {
  const EquipmentBrowseScreen({super.key});

  @override
  State<EquipmentBrowseScreen> createState() => _EquipmentBrowseScreenState();
}

class _EquipmentBrowseScreenState extends State<EquipmentBrowseScreen> {
  String _category = 'All';

  @override
  Widget build(BuildContext context) {
    final published = MockData.gymEquipment.where((e) => e.isActive).toList();
    final categories = ['All', ...{for (final e in published) e.category}];
    final visible =
        _category == 'All' ? published : published.where((e) => e.category == _category).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Equipment')),
      body: Column(
        children: [
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
              itemBuilder: (ctx, i) => _EquipmentCard(equipment: visible[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  final GymEquipment equipment;
  const _EquipmentCard({required this.equipment});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => EquipmentDetailScreen(equipment: equipment))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 16 / 11,
              child: _networkHero(equipment.imageUrl),
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
