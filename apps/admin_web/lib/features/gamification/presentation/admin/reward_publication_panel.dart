import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

String _requestId() {
  final random = Random.secure();
  return 'reward_${DateTime.now().microsecondsSinceEpoch}_${List.generate(12, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
}

/// A saved metadata revision is the only source of publishable reward information.
class RewardPublicationPanel extends StatefulWidget {
  const RewardPublicationPanel(
      {super.key,
      required this.repository,
      required this.drafts,
      this.sessionChanges,
      this.settingsOnly = false,
      this.onShopChanged});
  final RewardPublishingRepository repository;
  final List<RewardCatalogDraft> drafts;
  final Stream<Object?>? sessionChanges;
  final bool settingsOnly;
  final ValueChanged<RewardShopAdministration>? onShopChanged;
  @override
  State<RewardPublicationPanel> createState() => _RewardPublicationPanelState();
}

class _RewardPublicationPanelState extends State<RewardPublicationPanel> {
  final _form = GlobalKey<FormState>();
  final _points = TextEditingController(), _value = TextEditingController();
  RewardShopAdministration? _shop;
  bool _loading = true, _busy = false, _enabled = false;
  bool _settingsOpen = false;
  String? _error, _pendingSignature, _pendingId;
  final _retireRequests = <String, String>{};
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RewardPublicationPanel old) {
    super.didUpdateWidget(old);
    if (old.repository != widget.repository) {
      _generation++;
      _shop = null;
      _points.clear();
      _value.clear();
      _enabled = false;
      _pendingId = null;
      _pendingSignature = null;
      _retireRequests.clear();
      _busy = false;
      _settingsOpen = false;
      _load();
    }
  }

  @override
  void dispose() {
    _points.dispose();
    _value.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final shop = await widget.repository.shopOverview();
      if (!mounted || generation != _generation || !widget.repository.current) {
        return;
      }
      setState(() {
        _shop = shop;
        _points.text = shop.policy?.pointsPerUnit.toString() ?? '';
        _value.text =
            shop.policy == null ? '' : _rm(shop.policy!.unitValueMinor);
        _enabled = shop.policy?.enabled ?? false;
      });
      widget.onShopChanged?.call(shop);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _shop = null;
          _error =
              'Could not load the reward shop. Check Admin access and retry.';
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _configure() async {
    if (_busy ||
        !_form.currentState!.validate() ||
        !widget.repository.current) {
      return;
    }
    final points = int.parse(_points.text.trim()), value = _minor(_value.text)!;
    final signature = '$points:$value:$_enabled';
    if (_pendingSignature != signature) {
      _pendingSignature = signature;
      _pendingId = _requestId();
    }
    await _mutate(() => widget.repository.configureShop(
        requestId: _pendingId!,
        pointsPerUnit: points,
        unitValueMinor: value,
        enabled: _enabled));
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (_busy || !widget.repository.current) return;
    final generation = _generation;
    final repository = widget.repository;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted || generation != _generation || !widget.repository.current) {
        return;
      }
      await _load();
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error =
            'Change not confirmed. Retry unchanged inputs to reuse the same request, or refresh before changing them.');
      }
    } finally {
      if (mounted && identical(widget.repository, repository)) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _publish(RewardCatalogDraft draft, PublishedReward? item) async {
    final repository = widget.repository,
        sessionChanges = widget.sessionChanges;
    final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => StreamBuilder<Object?>(
            stream: sessionChanges,
            builder: (_, __) => RewardPublicationDialog(
                repository: repository, draft: draft, existing: item)));
    if (result == true &&
        mounted &&
        identical(repository, widget.repository) &&
        repository.current) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.repository.current) {
      return const Panel(
          child: Text('Reward publication unavailable for this session.'));
    }
    final shop = _shop;
    final active = shop?.items.any((i) => i.active) ?? false;
    final blocked = _busy || _loading || shop == null;
    final availableDrafts =
        widget.drafts.where((d) => d.revision > 0 && !d.isArchived).toList();
    final activeItems =
        shop?.items.where((i) => i.active).toList() ?? <PublishedReward>[];
    final retiredItems =
        shop?.items.where((i) => !i.active).toList() ?? <PublishedReward>[];
    final newDrafts = availableDrafts
        .where((d) => !activeItems.any((i) => i.itemId == d.id))
        .toList();
    final settingsVisible =
        widget.settingsOnly || shop?.policy == null || _settingsOpen;
    return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (widget.settingsOnly)
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(12)),
                  child:
                      const Icon(Icons.tune_rounded, color: AppColors.primary)),
            Text(widget.settingsOnly ? 'Shop policy' : 'Member reward shop',
                style: Theme.of(context).textTheme.titleLarge),
            if (shop != null)
              statusPill(shop.policy == null
                  ? 'Setup needed'
                  : shop.policy!.enabled
                      ? 'Open'
                      : 'Paused'),
            IconButton(
                tooltip: 'Refresh shop',
                onPressed: _busy || _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded)),
          ]),
      Text(widget.settingsOnly
          ? 'Set the points conversion and availability for your Member shop.'
          : 'Basic and Premium Members can redeem rewards.'),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child:
                Text(_error!, style: const TextStyle(color: AppColors.danger))),
      if (!_loading && shop == null)
        TextButton(
            onPressed: _busy ? null : _load,
            child: const Text('Retry shop overview')),
      if (shop != null) ...[
        const SizedBox(height: 16),
        Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color:
                    widget.settingsOnly ? Colors.white : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Eyebrow('Shop settings'),
                          Text(
                              shop.policy == null
                                  ? 'Set up your reward shop'
                                  : '${shop.policy!.pointsPerUnit} points = RM ${_rm(shop.policy!.unitValueMinor)}',
                              style: Theme.of(context).textTheme.titleMedium),
                        ]),
                    if (shop.policy != null && !widget.settingsOnly)
                      TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => _settingsOpen = !_settingsOpen),
                          icon: Icon(_settingsOpen
                              ? Icons.expand_less
                              : Icons.settings_outlined),
                          label: Text(_settingsOpen
                              ? 'Close settings'
                              : 'Edit settings')),
                  ]),
              if (settingsVisible) ...[
                const SizedBox(height: 14),
                if (active)
                  const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                          'To change the conversion rate, remove all rewards from the shop first. Existing vouchers keep their original terms.')),
                Form(
                    key: _form,
                    child: LayoutBuilder(builder: (context, c) {
                      final fields = Column(children: [
                        _number(_points, 'Points',
                            enabled: !blocked && !active),
                        const SizedBox(height: 12),
                        _money(_value, 'Equivalent reward value (RM)',
                            enabled: !blocked && !active),
                      ]);
                      final controls = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Allow redemptions'),
                                subtitle: const Text(
                                    'Pause new redemptions; existing vouchers stay valid.'),
                                value: _enabled,
                                onChanged: blocked
                                    ? null
                                    : (value) =>
                                        setState(() => _enabled = value)),
                            const SizedBox(height: 12),
                            FilledButton(
                                onPressed: blocked ? null : _configure,
                                child: const Text('Save settings')),
                          ]);
                      return c.maxWidth >= 800 &&
                              MediaQuery.textScalerOf(context).scale(14) < 24
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  Expanded(child: fields),
                                  const SizedBox(width: 32),
                                  Expanded(child: controls)
                                ])
                          : Column(children: [
                              fields,
                              const SizedBox(height: 12),
                              controls
                            ]);
                    })),
              ],
            ])),
        if (!widget.settingsOnly) ...[
          const SizedBox(height: 24),
          Text('Published rewards',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('These rewards are visible in the Member shop.'),
          const SizedBox(height: 12),
          if (activeItems.isEmpty)
            const Text(
                'No published rewards yet. Publish a saved reward below.'),
          for (final item in activeItems)
            _publishedCard(item, availableDrafts, blocked),
          if (retiredItems.isNotEmpty)
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Removed from shop (${retiredItems.length})'),
                subtitle:
                    const Text('Existing vouchers remain valid until expiry.'),
                children: [
                  for (final item in retiredItems)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.title),
                        subtitle: Text('${item.stock} stock retained'),
                        trailing: statusPill('Removed'))
                ]),
          if (newDrafts.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Ready to publish',
                style: Theme.of(context).textTheme.titleMedium),
            const Text(
                'Set points, stock and voucher conditions before Members can redeem.'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final draft in newDrafts)
                OutlinedButton.icon(
                    onPressed: blocked || shop.policy == null
                        ? null
                        : () => _publish(
                            draft,
                            shop.items
                                .where((i) => i.itemId == draft.id)
                                .firstOrNull),
                    icon: const Icon(Icons.publish_outlined),
                    label: Text('Publish ${draft.title}'))
            ]),
          ],
        ],
      ],
    ]));
  }

  Widget _publishedCard(
      PublishedReward item, List<RewardCatalogDraft> drafts, bool blocked) {
    final draft = drafts.where((d) => d.id == item.itemId).firstOrNull;
    return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(item.title,
                    style: Theme.of(context).textTheme.titleMedium),
                statusPill('Published')
              ]),
          const SizedBox(height: 10),
          Wrap(spacing: 20, runSpacing: 8, children: [
            Text('${item.pointCost} points'),
            Text('Value: RM ${_rm(item.valueMinor)}'),
            Text('${item.stock} in stock'),
            Text('Valid ${item.validityDays} days after redemption')
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (draft != null)
              OutlinedButton.icon(
                  onPressed: blocked ? null : () => _publish(draft, item),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Update reward')),
            TextButton(
                onPressed: blocked
                    ? null
                    : () => _mutate(() => widget.repository.retireReward(
                        itemId: item.itemId,
                        requestId: _retireRequests.putIfAbsent(
                            '${item.itemId}:${item.revision}', _requestId),
                        baseItemRevision: item.revision)),
                child: const Text('Remove from shop')),
          ]),
        ]));
  }
}

Widget _number(TextEditingController controller, String label,
        {bool enabled = true, int min = 1, int max = 100000000}) =>
    TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        validator: (text) {
          final n = int.tryParse(text?.trim() ?? '');
          return n == null || n < min || n > max
              ? 'Enter a whole number from $min to $max'
              : null;
        });

String _rm(int minor) =>
    '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';
int? _minor(String text) {
  final value = text.trim();
  if (!RegExp(r'^\d{1,7}(?:\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final minor = int.parse(parts.first) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  return minor > 0 && minor <= 100000000 ? minor : null;
}

Widget _money(TextEditingController controller, String label,
        {bool enabled = true}) =>
    TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, hintText: '0.50'),
      validator: (text) => _minor(text ?? '') == null
          ? 'Enter an RM amount, up to 2 decimal places'
          : null,
    );

class RewardPublicationDialog extends StatefulWidget {
  const RewardPublicationDialog(
      {super.key,
      required this.repository,
      required this.draft,
      this.existing});
  final RewardPublishingRepository repository;
  final RewardCatalogDraft draft;
  final PublishedReward? existing;
  @override
  State<RewardPublicationDialog> createState() =>
      _RewardPublicationDialogState();
}

class _RewardPublicationDialogState extends State<RewardPublicationDialog> {
  final _form = GlobalKey<FormState>();
  late final _cost =
      TextEditingController(text: widget.existing?.pointCost.toString() ?? '');
  late final _value = TextEditingController(
      text: widget.existing == null ? '' : _rm(widget.existing!.valueMinor));
  final _stock = TextEditingController();
  late final _days = TextEditingController(
      text: widget.existing?.validityDays.toString() ?? '');
  late final _conditions =
      TextEditingController(text: widget.existing?.conditions ?? '');
  late final _instructions = TextEditingController(
      text: widget.existing?.collectionInstructions ?? '');
  String? _signature, _request, _error;
  bool _busy = false;
  @override
  void dispose() {
    for (final c in [
      _cost,
      _value,
      _stock,
      _days,
      _conditions,
      _instructions
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy ||
        !_form.currentState!.validate() ||
        !widget.repository.current) {
      return;
    }
    final values = [
      _cost.text.trim(),
      _value.text.trim(),
      _stock.text.trim(),
      _days.text.trim(),
      _conditions.text.trim(),
      _instructions.text.trim()
    ];
    final signature = jsonEncode(values);
    if (_signature != signature) {
      _signature = signature;
      _request = _requestId();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.publishReward(
          draft: widget.draft,
          requestId: _request!,
          baseItemRevision: widget.existing?.revision ?? 0,
          pointCost: int.parse(values[0]),
          valueMinor: _minor(values[1])!,
          stockToAdd: int.parse(values[2]),
          validityDays: int.parse(values[3]),
          conditions: values[4],
          collectionInstructions: values[5]);
      if (mounted && widget.repository.current) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Publication not confirmed. Retry unchanged values, or close and refresh if the saved draft or published item changed.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: !widget.repository.current
                  ? const Text(
                      'Reward publication unavailable for this session.')
                  : Form(
                      key: _form,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${widget.existing?.active == true ? 'Update' : 'Publish'} ${widget.draft.title}',
                                style: Theme.of(context).textTheme.titleLarge),
                            Text(
                                'Changes apply to new redemptions. Existing vouchers keep their original terms.'),
                            const SizedBox(height: 16),
                            _number(_cost, 'Points cost', enabled: !_busy),
                            const SizedBox(height: 12),
                            _money(_value, 'Reward value (RM)',
                                enabled: !_busy),
                            const SizedBox(height: 12),
                            _number(_stock, 'Stock to add',
                                min: 0, enabled: !_busy),
                            const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Text(
                                    'Add to current stock. Enter 0 to update details only.')),
                            const SizedBox(height: 12),
                            _number(_days, 'Validity after redemption (days)',
                                max: 365, enabled: !_busy),
                            const SizedBox(height: 12),
                            TextFormField(
                                controller: _conditions,
                                enabled: !_busy,
                                maxLength: 2000,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                    labelText: 'Conditions'),
                                validator: _required),
                            TextFormField(
                                controller: _instructions,
                                enabled: !_busy,
                                maxLength: 2000,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                    labelText: 'Collection instructions'),
                                validator: _required),
                            const Text(
                                'Unused expired rewards keep their points spent. No automatic points refund or stock credit.'),
                            if (_error != null)
                              Text(_error!,
                                  style:
                                      const TextStyle(color: AppColors.danger)),
                            const SizedBox(height: 16),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel')),
                              FilledButton(
                                  onPressed: _busy ? null : _save,
                                  child: Text(_busy
                                      ? 'Publishing…'
                                      : 'Publish reward')),
                            ]),
                          ])))));
  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
}
