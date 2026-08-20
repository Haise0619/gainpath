import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// Defensive network image loader: a broken/slow link never breaks the
/// layout — the same pattern used across the member-facing modules.
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

/// Admin management view over `MockData.gymEquipment` — the catalogue
/// the member-facing equipment scanner matches against and browses.
/// This is the software side of a genuinely physical feature: every
/// entry here corresponds to a real machine on the gym floor, so
/// "manage the catalogue" mostly means keeping it in sync with what's
/// actually installed — publishing new equipment, and unpublishing
/// anything removed or out of service without losing its record.
class EquipmentCatalogScreen extends StatefulWidget {
  const EquipmentCatalogScreen({super.key});

  @override
  State<EquipmentCatalogScreen> createState() => _EquipmentCatalogScreenState();
}

class _EquipmentCatalogScreenState extends State<EquipmentCatalogScreen> {
  String _category = 'All';

  @override
  Widget build(BuildContext context) {
    final equipment = MockData.gymEquipment;
    final categories = ['All', ...{for (final e in equipment) e.category}];
    final visible =
        _category == 'All' ? equipment : equipment.where((e) => e.category == _category).toList();
    final activeCount = equipment.where((e) => e.isActive).length;

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
                    '$activeCount of ${equipment.length} items published to the member scanner',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => showToast(context, 'Opening the equipment form.'),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add equipment'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: categories.map((c) {
                final selected = c == _category;
                return ChoiceChip(
                  label: Text(c),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = c),
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.ink),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999), side: const BorderSide(color: AppColors.hairline)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            ...visible.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Opacity(
                    opacity: e.isActive ? 1 : 0.55,
                    child: Panel(
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(width: 56, height: 56, child: _networkHero(e.imageUrl)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.name, style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 2),
                                Text('${e.category}  ·  ${e.muscleGroup}',
                                    style: Theme.of(context).textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: e.isActive,
                                onChanged: (v) => setState(() => e.isActive = v),
                              ),
                              Text(e.isActive ? 'Published' : 'Hidden',
                                  style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => showToast(context, 'Edit ${e.name}.'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
