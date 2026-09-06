import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import '../admin_breadcrumb.dart';

Widget _networkHero(String url, {BoxFit fit = BoxFit.cover}) {
  if (url.trim().isEmpty) {
    return const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient));
  }
  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : Container(color: AppColors.surfaceAlt),
    errorBuilder: (context, error, stack) =>
        const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
  );
}

/// AD-M11.4 — Manage Reward Catalog. In-place Governance pane — items a
/// member can redeem gamification points for, mirroring the member-side
/// Rewards shop this same data feeds. Add/Edit is a full page (category,
/// description, redemption limits, expiry — enough fields that a dialog
/// was too tight), with a local breadcrumb back to the catalog list.
class RewardCatalogScreen extends StatefulWidget {
  const RewardCatalogScreen({super.key});

  @override
  State<RewardCatalogScreen> createState() => _RewardCatalogScreenState();
}

class _RewardCatalogScreenState extends State<RewardCatalogScreen> {
  RewardItem? _editing;
  bool _creating = false;

  void _openCreate() => setState(() => _creating = true);
  void _openEdit(RewardItem r) => setState(() => _editing = r);
  void _closeForm() => setState(() {
        _creating = false;
        _editing = null;
      });

  @override
  Widget build(BuildContext context) {
    if (_creating || _editing != null) {
      return _RewardFormPage(existing: _editing, onDone: _closeForm);
    }

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
                  onPressed: _openCreate,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add item'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...MockData.rewards.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    onTap: () => _openEdit(r),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(width: 48, height: 48, child: _networkHero(r.imageUrl)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.title, style: Theme.of(context).textTheme.titleMedium),
                              Text('${r.category}  ·  ${r.points} points',
                                  style: Theme.of(context).textTheme.bodyMedium),
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
                          onPressed: () => _openEdit(r),
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

class _RewardFormPage extends StatefulWidget {
  final RewardItem? existing;
  final VoidCallback onDone;
  const _RewardFormPage({this.existing, required this.onDone});

  @override
  State<_RewardFormPage> createState() => _RewardFormPageState();
}

class _RewardFormPageState extends State<_RewardFormPage> {
  static const _categories = ['Merchandise', 'Food & Drink', 'Apparel', 'Access Pass'];

  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '')..addListener(_repaint);
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late final _points = TextEditingController(text: widget.existing?.points.toString() ?? '')..addListener(_repaint);
  late final _stock = TextEditingController(text: widget.existing?.stock.toString() ?? '');
  late final _imageUrl = TextEditingController(text: widget.existing?.imageUrl ?? '')..addListener(_repaint);
  late final _limit = TextEditingController(text: widget.existing?.redemptionLimitPerMember?.toString() ?? '');
  late String _category = widget.existing?.category ?? _categories.first;
  late DateTime? _expiresAt = widget.existing?.expiresAt;

  bool get _isEdit => widget.existing != null;

  void _repaint() => setState(() {});

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _points.dispose();
    _stock.dispose();
    _imageUrl.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final points = int.parse(_points.text.trim());
    final stock = int.parse(_stock.text.trim());
    final limit = int.tryParse(_limit.text.trim());
    if (_isEdit) {
      widget.existing!
        ..title = _title.text.trim()
        ..points = points
        ..stock = stock
        ..imageUrl = _imageUrl.text.trim()
        ..category = _category
        ..description = _description.text.trim()
        ..redemptionLimitPerMember = limit
        ..expiresAt = _expiresAt;
    } else {
      MockData.rewards.add(RewardItem(_title.text.trim(), points, stock, _imageUrl.text.trim(),
          category: _category,
          description: _description.text.trim(),
          redemptionLimitPerMember: limit,
          expiresAt: _expiresAt));
    }
    showToast(context, _isEdit ? 'Reward item updated.' : 'Reward item added to the catalog.');
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageBreadcrumb(crumbs: [
              PageCrumb('Reward Catalog', widget.onDone),
              PageCrumb(_isEdit ? 'Edit reward' : 'Add reward'),
            ]),
            const SizedBox(height: 6),
            Text(_isEdit ? 'Edit reward item' : 'Add reward item', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('This appears in the member-facing reward shop once added.',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 22),
            LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final form = _form(context);
              final preview = _previewCard(context);
              return wide
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: form),
                          const SizedBox(width: 20),
                          Expanded(flex: 2, child: preview),
                        ],
                      ),
                    )
                  : Column(children: [form, const SizedBox(height: 20), preview]);
            }),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Item details'),
          Panel(
            child: Column(
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title', isDense: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description', isDense: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imageUrl,
                  decoration: const InputDecoration(labelText: 'Image URL', isDense: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category', isDense: true),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Eyebrow('Availability & limits'),
          Panel(
            child: Column(
              children: [
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _limit,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Redemption limit / member (optional)', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _pickExpiry,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Expires (optional)', isDense: true),
                          child: Text(
                            _expiresAt == null
                                ? 'No expiry'
                                : '${_expiresAt!.year}-${_expiresAt!.month.toString().padLeft(2, '0')}-${_expiresAt!.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              OutlinedButton(onPressed: widget.onDone, child: const Text('Cancel')),
              const SizedBox(width: 10),
              FilledButton(onPressed: _save, child: Text(_isEdit ? 'Save changes' : 'Add item')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewCard(BuildContext context) {
    final points = int.tryParse(_points.text.trim());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Member preview'),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(aspectRatio: 16 / 10, child: _networkHero(_imageUrl.text)),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_title.text.isEmpty ? 'Untitled reward' : _title.text,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('$_category  ·  ${points ?? 0} pts', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          background: AppColors.primaryTint,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'At 200 pts = RM 1.00, this costs members roughly RM ${((points ?? 0) / 200).toStringAsFixed(2)}.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
