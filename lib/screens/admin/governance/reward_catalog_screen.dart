import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import '../admin_dialogs.dart';

/// AD-M11.4 — Manage Reward Catalog. In-place Governance pane — items a
/// member can redeem gamification points for, mirroring the member-side
/// Rewards shop this same data feeds.
class RewardCatalogScreen extends StatefulWidget {
  const RewardCatalogScreen({super.key});

  @override
  State<RewardCatalogScreen> createState() => _RewardCatalogScreenState();
}

class _RewardCatalogScreenState extends State<RewardCatalogScreen> {
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final lowStock = MockData.rewards.where((r) => r.stock <= 10).length;
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
                    '${MockData.rewards.length} items in the shop'
                    '${lowStock > 0 ? '  ·  $lowStock running low on stock' : ''}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    final saved =
                        await showDialog<bool>(context: context, builder: (ctx) => const _RewardFormDialog());
                    if (saved == true) _refresh();
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add item'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...MockData.rewards.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.title, style: Theme.of(context).textTheme.titleMedium),
                              Text('${r.points} points', style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${r.stock}',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: r.stock <= 10 ? AppColors.warning : AppColors.ink)),
                            Text('in stock', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 19),
                          onPressed: () async {
                            final saved = await showDialog<bool>(
                                context: context, builder: (ctx) => _RewardFormDialog(existing: r));
                            if (saved == true) _refresh();
                          },
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _RewardFormDialog extends StatefulWidget {
  final RewardItem? existing;
  const _RewardFormDialog({this.existing});

  @override
  State<_RewardFormDialog> createState() => _RewardFormDialogState();
}

class _RewardFormDialogState extends State<_RewardFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _points = TextEditingController(text: widget.existing?.points.toString() ?? '');
  late final _stock = TextEditingController(text: widget.existing?.stock.toString() ?? '');
  late final _imageUrl = TextEditingController(text: widget.existing?.imageUrl ?? '');

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _title.dispose();
    _points.dispose();
    _stock.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final points = int.parse(_points.text.trim());
    final stock = int.parse(_stock.text.trim());
    if (_isEdit) {
      widget.existing!
        ..title = _title.text.trim()
        ..points = points
        ..stock = stock
        ..imageUrl = _imageUrl.text.trim();
    } else {
      MockData.rewards.add(RewardItem(_title.text.trim(), points, stock, _imageUrl.text.trim()));
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AdminDialog(
      width: 460,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isEdit ? 'Edit reward item' : 'Add reward item', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title', isDense: true),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _points,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Points cost', isDense: true),
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      return (n == null || n <= 0) ? 'Whole number > 0' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _stock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock', isDense: true),
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      return (n == null || n < 0) ? 'Whole number ≥ 0' : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _imageUrl,
              decoration: const InputDecoration(labelText: 'Image URL', isDense: true),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(onPressed: _save, child: Text(_isEdit ? 'Save changes' : 'Add item')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
