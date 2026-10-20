import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../navigation/admin_breadcrumb.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gamification.dart';

Widget _networkHero(String url, {BoxFit fit = BoxFit.cover}) {
  if (url.trim().isEmpty) {
    return const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.heroGradient));
  }
  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : Container(color: AppColors.surfaceAlt),
    errorBuilder: (context, error, stack) => const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.heroGradient)),
  );
}

/// AD-M11.4 — Manage Reward Catalog. In-place Governance pane — items a
/// member can redeem gamification points for, mirroring the member-side
/// Rewards shop this same data feeds. Add/Edit is a full page (category,
/// description, redemption limits, expiry — enough fields that a dialog
/// was too tight), with a local breadcrumb back to the catalog list.
class RewardCatalogScreen extends StatefulWidget {
  const RewardCatalogScreen({super.key, this.live = false});
  final bool live;

  @override
  State<RewardCatalogScreen> createState() => _RewardCatalogScreenState();
}

class _RewardCatalogScreenState extends State<RewardCatalogScreen> {
  RewardItem? _editing;
  bool _creating = false;
  RewardCatalogDraft? _draftEditing;
  List<RewardCatalogDraft> _drafts = [];
  String? _nextCursor, _error;
  bool _loading = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    if (widget.live) _load();
  }

  Future<void> _load({bool append = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      if (!append) {
        _drafts = [];
        _nextCursor = null;
      }
    });
    try {
      final page = await context
          .read<RewardCatalogRepository>()
          .loadPage(afterId: append ? _nextCursor : null);
      if (!mounted || generation != _generation) return;
      setState(() {
        _drafts = append ? [..._drafts, ...page.items] : page.items;
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _drafts = [];
          _nextCursor = null;
          _error =
              'Could not load reward drafts. Check your Admin access and retry.';
        });
      }
    }
  }

  void _openCreate() {
    if (widget.live) {
      try {
        final draft = context.read<RewardCatalogRepository>().beginCreate();
        setState(() => _draftEditing = draft);
      } catch (_) {
        setState(() => _error =
            'Check your Admin access and refresh before creating a draft.');
      }
    } else {
      setState(() => _creating = true);
    }
  }

  void _openEdit(RewardItem r) => setState(() => _editing = r);
  void _closeForm() {
    setState(() {
      _creating = false;
      _editing = null;
      _draftEditing = null;
    });
    if (widget.live) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_creating || _editing != null || _draftEditing != null) {
      return _RewardFormPage(
          existing: _editing,
          draft: _draftEditing,
          live: widget.live,
          onDone: _closeForm);
    }
    if (widget.live) return _liveCatalog(context);

    final lowStock = context
        .read<GamificationRepository>()
        .rewards
        .where((r) => r.stock <= 10)
        .length;
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
                    '${context.read<GamificationRepository>().rewards.length} items in the shop'
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
            ...context
                .read<GamificationRepository>()
                .rewards
                .map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Panel(
                        onTap: () => _openEdit(r),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: _networkHero(r.imageUrl)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  Text('${r.category}  ·  ${r.points} points',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium),
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
                                        color: r.stock <= 10
                                            ? AppColors.warning
                                            : AppColors.ink)),
                                Text('in stock',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontSize: 12)),
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

  Widget _liveCatalog(BuildContext context) => Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('${_drafts.length} metadata drafts loaded',
                      style: Theme.of(context).textTheme.bodyLarge),
                  IconButton(
                      tooltip: 'Refresh reward drafts',
                      onPressed: _loading ? null : () => _load(),
                      icon: const Icon(Icons.refresh_rounded)),
                  FilledButton.icon(
                      onPressed: _loading ? null : _openCreate,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add draft')),
                ]),
            const SizedBox(height: 12),
            const Text(
                'Admin metadata only. Drafts are not published or redeemable.'),
            const SizedBox(height: 20),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Panel(
                  child: Column(children: [
                Text(_error!),
                TextButton(onPressed: () => _load(), child: const Text('Retry'))
              ])),
            if (!_loading && _error == null && _drafts.isEmpty)
              const Panel(
                  child: Text(
                      'No reward drafts yet. Add a draft to get started.')),
            for (final draft in _drafts)
              Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                      onTap: _loading
                          ? null
                          : () => setState(() => _draftEditing = draft),
                      child: Row(children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                                width: 48,
                                height: 48,
                                child: _networkHero(draft.imageUrl))),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(draft.title,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(
                                  '${draft.category} · Revision ${draft.revision}'),
                            ])),
                        statusPill(draft.isArchived ? 'Archived' : 'Draft'),
                        IconButton(
                            tooltip: 'Edit ${draft.title}',
                            onPressed: _loading
                                ? null
                                : () => setState(() => _draftEditing = draft),
                            icon: const Icon(Icons.edit_outlined, size: 19)),
                      ]))),
            if (_nextCursor != null)
              TextButton(
                  onPressed: _loading ? null : () => _load(append: true),
                  child: const Text('Load more drafts')),
          ])));
}

class _RewardFormPage extends StatefulWidget {
  final RewardItem? existing;
  final VoidCallback onDone;
  final RewardCatalogDraft? draft;
  final bool live;
  const _RewardFormPage(
      {this.existing, this.draft, this.live = false, required this.onDone});

  @override
  State<_RewardFormPage> createState() => _RewardFormPageState();
}

class _RewardFormPageState extends State<_RewardFormPage> {
  static const _categories = [
    'Merchandise',
    'Food & Drink',
    'Apparel',
    'Access Pass'
  ];

  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(
      text: widget.draft?.title ?? widget.existing?.title ?? '')
    ..addListener(_repaint);
  late final _description = TextEditingController(
      text: widget.draft?.description ?? widget.existing?.description ?? '');
  late final _points =
      TextEditingController(text: widget.existing?.points.toString() ?? '')
        ..addListener(_repaint);
  late final _stock =
      TextEditingController(text: widget.existing?.stock.toString() ?? '');
  late final _imageUrl = TextEditingController(
      text: widget.draft?.imageUrl ?? widget.existing?.imageUrl ?? '')
    ..addListener(_repaint);
  late final _limit = TextEditingController(
      text: widget.existing?.redemptionLimitPerMember?.toString() ?? '');
  late String _category =
      widget.draft?.category ?? widget.existing?.category ?? _categories.first;
  late DateTime? _expiresAt = widget.existing?.expiresAt;

  bool get _isEdit =>
      widget.live ? (widget.draft?.revision ?? 0) > 0 : widget.existing != null;
  bool _saving = false, _blocked = false;
  String? _saveError;
  late bool _archived = widget.draft?.isArchived ?? false;

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

  Future<void> _save() async {
    if (_saving || _blocked) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (widget.live) {
      final draft = widget.draft!.copyWith(
          title: _title.text,
          description: _description.text,
          category: _category,
          imageUrl: _imageUrl.text,
          isArchived: _archived);
      try {
        draft.validate();
      } on FormatException catch (e) {
        setState(() => _saveError = e.message);
        return;
      }
      FocusScope.of(context).unfocus();
      setState(() {
        _saving = true;
        _saveError = null;
      });
      try {
        await context.read<RewardCatalogRepository>().save(draft);
        if (!mounted) return;
        showToast(context, 'Reward metadata draft saved.');
        widget.onDone();
      } on RewardCatalogConflict {
        if (mounted) {
          setState(() {
            _blocked = true;
            _saveError =
                'This draft changed. Return to the catalog and reopen it before saving.';
          });
        }
      } on RewardCatalogSessionChanged {
        if (mounted) {
          setState(() {
            _blocked = true;
            _saveError =
                'Account or permissions changed. Sign in again before saving.';
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _blocked = true;
            _saveError =
                'Could not verify the save. Return to the catalog and refresh before retrying.';
          });
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }
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
      context.read<GamificationRepository>().rewards.add(RewardItem(
          _title.text.trim(), points, stock, _imageUrl.text.trim(),
          category: _category,
          description: _description.text.trim(),
          redemptionLimitPerMember: limit,
          expiresAt: _expiresAt));
    }
    showToast(context,
        _isEdit ? 'Reward item updated.' : 'Reward item added to the catalog.');
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
              PageCrumb('Reward Catalog', () {
                if (!_saving) widget.onDone();
              }),
              PageCrumb(_isEdit ? 'Edit reward' : 'Add reward'),
            ]),
            const SizedBox(height: 6),
            Text(_isEdit ? 'Edit reward item' : 'Add reward item',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
                widget.live
                    ? 'Admin draft only. Saving does not publish to the reward shop.'
                    : 'This appears in the member-facing reward shop once added.',
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
                  : Column(
                      children: [form, const SizedBox(height: 20), preview]);
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
                  enabled: !_saving,
                  maxLength: widget.live ? 120 : null,
                  controller: _title,
                  decoration:
                      const InputDecoration(labelText: 'Title', isDense: true),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  enabled: !_saving,
                  maxLength: widget.live ? 2000 : null,
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Description', isDense: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  enabled: !_saving,
                  maxLength: widget.live ? 2048 : null,
                  controller: _imageUrl,
                  decoration: const InputDecoration(
                      labelText: 'Image URL', isDense: true),
                  validator: (v) =>
                      !widget.live && (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Category', isDense: true),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _category = v ?? _category),
                ),
              ],
            ),
          ),
          if (!widget.live) ...[
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
                          decoration: const InputDecoration(
                              labelText: 'Points cost', isDense: true),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            return (n == null || n <= 0)
                                ? 'Whole number > 0'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _stock,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Stock', isDense: true),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            return (n == null || n < 0)
                                ? 'Whole number ≥ 0'
                                : null;
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
                          decoration: const InputDecoration(
                              labelText: 'Redemption limit / member (optional)',
                              isDense: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _pickExpiry,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                                labelText: 'Expires (optional)', isDense: true),
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
          ],
          if (widget.live && _isEdit)
            SwitchListTile(
                title: const Text('Archive draft'),
                subtitle: const Text(
                    'Archived metadata remains available to Admins.'),
                value: _archived,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _archived = value)),
          if (_saveError != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_saveError!,
                    style: const TextStyle(color: AppColors.danger))),
          const SizedBox(height: 22),
          Row(
            children: [
              OutlinedButton(
                  onPressed: _saving ? null : widget.onDone,
                  child: const Text('Cancel')),
              const SizedBox(width: 10),
              FilledButton(
                  onPressed: _saving || _blocked ? null : _save,
                  child: Text(_saving
                      ? 'Saving…'
                      : widget.live
                          ? 'Save draft'
                          : _isEdit
                              ? 'Save changes'
                              : 'Add item')),
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
        Eyebrow(widget.live ? 'Draft preview' : 'Member preview'),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                    aspectRatio: 16 / 10, child: _networkHero(_imageUrl.text)),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_title.text.isEmpty ? 'Untitled reward' : _title.text,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                        widget.live
                            ? '$_category · ${_archived ? "Archived" : "Draft"}'
                            : '$_category  ·  ${points ?? 0} pts',
                        style: Theme.of(context).textTheme.bodyMedium),
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
              const Icon(Icons.info_outline_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.live
                      ? 'Metadata preview only. Points, stock, redemption, and publication are unavailable.'
                      : 'At 200 pts = RM 1.00, this costs members roughly RM ${((points ?? 0) / 200).toStringAsFixed(2)}.',
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
