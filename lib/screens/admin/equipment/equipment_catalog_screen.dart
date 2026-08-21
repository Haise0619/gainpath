import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import '../admin_dialogs.dart';

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
                  onPressed: () async {
                    final saved =
                        await showDialog<bool>(context: context, builder: (ctx) => const _EquipmentFormDialog());
                    if (saved == true) setState(() {});
                  },
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
                            onPressed: () async {
                              final saved = await showDialog<bool>(
                                  context: context, builder: (ctx) => _EquipmentFormDialog(existing: e));
                              if (saved == true) setState(() {});
                            },
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

class _EquipmentFormDialog extends StatefulWidget {
  final GymEquipment? existing;
  const _EquipmentFormDialog({this.existing});

  @override
  State<_EquipmentFormDialog> createState() => _EquipmentFormDialogState();
}

class _EquipmentFormDialogState extends State<_EquipmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _category = TextEditingController(text: widget.existing?.category ?? '');
  late final _muscleGroup = TextEditingController(text: widget.existing?.muscleGroup ?? '');
  late final _imageUrl = TextEditingController(text: widget.existing?.imageUrl ?? '');
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late List<String> _howToUse = [...(widget.existing?.howToUse ?? const [])];
  late List<String> _safetyTips = [...(widget.existing?.safetyTips ?? const [])];

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _muscleGroup.dispose();
    _imageUrl.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isEdit) {
      widget.existing!
        ..name = _name.text.trim()
        ..category = _category.text.trim()
        ..muscleGroup = _muscleGroup.text.trim()
        ..imageUrl = _imageUrl.text.trim()
        ..description = _description.text.trim()
        ..howToUse = _howToUse
        ..safetyTips = _safetyTips;
    } else {
      MockData.gymEquipment.add(GymEquipment(
        id: 'eq${DateTime.now().millisecondsSinceEpoch}',
        name: _name.text.trim(),
        category: _category.text.trim(),
        description: _description.text.trim(),
        howToUse: _howToUse,
        safetyTips: _safetyTips,
        imageUrl: _imageUrl.text.trim(),
        muscleGroup: _muscleGroup.text.trim(),
      ));
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AdminDialog(
      width: 520,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isEdit ? 'Edit equipment' : 'Add equipment', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Name', isDense: true),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _category,
                      decoration: const InputDecoration(labelText: 'Category', isDense: true),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _muscleGroup,
                      decoration: const InputDecoration(labelText: 'Muscle group', isDense: true),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _imageUrl,
                      decoration: const InputDecoration(labelText: 'Image URL', isDense: true),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description', isDense: true),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              EditableStringList(
                label: 'How to use',
                items: _howToUse,
                onChanged: (v) => _howToUse = v,
              ),
              const SizedBox(height: 14),
              EditableStringList(
                label: 'Safety tips',
                items: _safetyTips,
                onChanged: (v) => _safetyTips = v,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(onPressed: _save, child: Text(_isEdit ? 'Save changes' : 'Add equipment')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A repeatable list of short text lines (used for equipment "how to
/// use"/"safety tips" steps, and reusable anywhere else a form needs a
/// growable list of strings) with inline add/remove — the desktop-form
/// equivalent of a mobile "add another" list.
class EditableStringList extends StatefulWidget {
  final String label;
  final List<String> items;
  final ValueChanged<List<String>> onChanged;
  const EditableStringList({super.key, required this.label, required this.items, required this.onChanged});

  @override
  State<EditableStringList> createState() => _EditableStringListState();
}

class _EditableStringListState extends State<EditableStringList> {
  late final List<TextEditingController> _controllers =
      widget.items.map((s) => TextEditingController(text: s)).toList();

  void _notify() => widget.onChanged(_controllers.map((c) => c.text).toList());

  void _add() {
    setState(() => _controllers.add(TextEditingController()));
    _notify();
  }

  void _remove(int i) {
    setState(() {
      _controllers[i].dispose();
      _controllers.removeAt(i);
    });
    _notify();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(widget.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            TextButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add line'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
            ),
          ],
        ),
        ...List.generate(_controllers.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controllers[i],
                    onChanged: (_) => _notify(),
                    decoration: InputDecoration(isDense: true, hintText: 'Step ${i + 1}'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () => _remove(i),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
