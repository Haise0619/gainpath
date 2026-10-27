import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/workout.dart'
    show EquipmentImage, EquipmentImagePicker;
import 'package:gainpath_ui/gainpath_ui.dart';
import 'workout_reward_draft_panel.dart';

String _requestId() =>
    'reward_${DateTime.now().microsecondsSinceEpoch}_${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';

class RewardManagementScreen extends StatefulWidget {
  const RewardManagementScreen(
      {super.key,
      required this.repository,
      this.onVerify,
      this.sessionChanges});
  final RewardManagementRepository repository;
  final VoidCallback? onVerify;
  final Stream<Object?>? sessionChanges;
  @override
  State<RewardManagementScreen> createState() => _RewardManagementScreenState();
}

class _RewardManagementScreenState extends State<RewardManagementScreen> {
  RewardShopAdministration? _shop;
  PublishedReward? _editing;
  String? _newId, _error;
  bool _busy = false, _loading = false;
  int _generation = 0;
  final _retireIds = <String, String>{};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final repository = widget.repository;
    if (!repository.current) return;
    setState(() {
      _loading = true;
      _shop = null;
      _error = null;
    });
    try {
      final shop = await repository.shopOverview();
      if (!mounted ||
          generation != _generation ||
          !identical(repository, widget.repository) ||
          !repository.current) {
        return;
      }
      setState(() => _shop = shop);
    } catch (_) {
      if (mounted && generation == _generation && repository.current) {
        setState(() =>
            _error = 'Could not load rewards. Check Admin access and retry.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void didUpdateWidget(RewardManagementScreen old) {
    super.didUpdateWidget(old);
    if (old.repository != widget.repository || !widget.repository.current) {
      _generation++;
      _shop = null;
      _editing = null;
      _newId = null;
      _busy = false;
      _error = null;
      _retireIds.clear();
      _loading = false;
      if (widget.repository.current) _load();
    }
  }

  void _open([PublishedReward? item]) {
    if (!widget.repository.current) return;
    try {
      final id = item == null ? widget.repository.newItemId() : null;
      setState(() {
        _editing = item;
        _newId = id;
        _error = null;
      });
    } catch (_) {
      setState(() =>
          _error = 'Check Admin access and refresh before editing rewards.');
    }
  }

  void _close() {
    setState(() {
      _editing = null;
      _newId = null;
    });
    _load();
  }

  Future<void> _remove(PublishedReward item) async {
    if (_busy || !widget.repository.current) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.retireReward(
          itemId: item.itemId,
          requestId: _retireIds.putIfAbsent(
              '${item.itemId}:${item.revision}', _requestId),
          baseItemRevision: item.revision);
      if (mounted && generation == _generation && widget.repository.current) {
        setState(() => _busy = false);
        await _load();
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
            () => _error = 'Removal not confirmed. Retry or refresh the shop.');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Widget _rewardCard(BuildContext context, PublishedReward item) => Panel(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: _cover(item.imageUrl)),
        Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(item.category,
                        style: Theme.of(context).textTheme.labelMedium),
                    statusPill(item.active ? 'In shop' : 'Removed')
                  ]),
              const SizedBox(height: 10),
              Text(item.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('${item.pointCost} points',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 10),
              Text('${item.stock} in stock'),
              Text('Valid ${item.validityDays} days after redemption'),
              const SizedBox(height: 18),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                    onPressed: _busy ? null : () => _open(item),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit reward')),
                if (item.active)
                  TextButton(
                      onPressed: _busy ? null : () => _remove(item),
                      child: const Text('Remove from shop'))
              ]),
            ])),
      ]));

  @override
  Widget build(BuildContext context) {
    if (!widget.repository.current) {
      return const Center(
          child: Text('Reward management unavailable for this session.'));
    }
    if (_newId != null || _editing != null) {
      return RewardEditorPage(
          key: ValueKey(_newId ?? _editing!.itemId),
          repository: widget.repository,
          itemId: _newId ?? _editing!.itemId,
          existing: _editing,
          onDone: _close);
    }
    return Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LayoutBuilder(builder: (context, c) {
                final title = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reward Catalog',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text('Create and manage rewards for your Members.'),
                    ]);
                final actions = Wrap(spacing: 12, runSpacing: 10, children: [
                  if (widget.onVerify != null)
                    OutlinedButton.icon(
                        onPressed: widget.onVerify,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Verify reward voucher')),
                  FilledButton.icon(
                      onPressed: _busy || _loading || _shop == null
                          ? null
                          : () => _open(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add reward')),
                  IconButton(
                      onPressed: _busy || _loading ? null : _load,
                      tooltip: 'Refresh rewards',
                      icon: const Icon(Icons.refresh_rounded)),
                ]);
                return c.maxWidth >= 1050 &&
                        MediaQuery.textScalerOf(context).scale(14) < 20
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Expanded(child: title),
                            const SizedBox(width: 20),
                            actions
                          ])
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [title, const SizedBox(height: 16), actions]);
              }),
              const SizedBox(height: 16),
              if (_loading) const LinearProgressIndicator(),
              if (widget.repository
                  is WorkoutRewardConfigurationRepository) ...[
                const SizedBox(height: 16),
                WorkoutRewardDraftPanel(
                    key: ObjectKey(widget.repository),
                    repository: widget.repository
                        as WorkoutRewardConfigurationRepository),
              ],
              const SizedBox(height: 20),
              Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.redeem_rounded,
                            color: AppColors.primary)),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rewards',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const Text('Manage items in your Member shop.')
                        ]),
                  ]),
              const SizedBox(height: 16),
              if (_error != null)
                Panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(_error!,
                          style: const TextStyle(color: AppColors.danger)),
                      TextButton(
                          onPressed: _busy || _loading ? null : _load,
                          child: const Text('Retry rewards'))
                    ])),
              if (_shop != null && _shop!.items.isEmpty)
                Panel(
                    child: SizedBox(
                        width: double.infinity,
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 36, horizontal: 12),
                            child: Column(children: [
                              const Icon(Icons.redeem_outlined,
                                  color: AppColors.primary, size: 56),
                              const SizedBox(height: 16),
                              Text('No rewards yet',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 8),
                              const Text(
                                  'Select Add reward to create your first Member reward.',
                                  textAlign: TextAlign.center),
                            ])))),
              if (_shop != null && _shop!.items.isNotEmpty)
                LayoutBuilder(builder: (context, c) {
                  final columns = c.maxWidth >= 1100
                      ? 3
                      : c.maxWidth >= 700
                          ? 2
                          : 1;
                  final width = (c.maxWidth - (columns - 1) * 20) / columns;
                  return Wrap(spacing: 20, runSpacing: 20, children: [
                    for (final item in _shop!.items)
                      SizedBox(width: width, child: _rewardCard(context, item))
                  ]);
                }),
            ])));
  }
}

Widget _cover(String url, {double height = 190}) => Container(
    height: height,
    width: double.infinity,
    color: AppColors.primaryTint,
    child: url.isEmpty
        ? const Icon(Icons.redeem_outlined, color: AppColors.primary, size: 56)
        : Image.network(url,
            fit: BoxFit.contain,
            webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
            errorBuilder: (_, __, ___) => const Icon(Icons.redeem_outlined,
                color: AppColors.primary, size: 56)));

class RewardEditorPage extends StatefulWidget {
  const RewardEditorPage(
      {super.key,
      required this.repository,
      required this.itemId,
      required this.onDone,
      this.existing});
  final RewardManagementRepository repository;
  final String itemId;
  final PublishedReward? existing;
  final VoidCallback onDone;
  @override
  State<RewardEditorPage> createState() => _RewardEditorPageState();
}

class _RewardEditorPageState extends State<RewardEditorPage> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _description =
      TextEditingController(text: widget.existing?.description ?? '');
  late final _image =
      TextEditingController(text: widget.existing?.imageUrl ?? '');
  late final _cost =
      TextEditingController(text: widget.existing?.pointCost.toString() ?? '');
  late final _stock =
      TextEditingController(text: widget.existing == null ? '' : '0');
  late final _days = TextEditingController(
      text: widget.existing?.validityDays.toString() ?? '');
  late final _conditions =
      TextEditingController(text: widget.existing?.conditions ?? '');
  late final _instructions = TextEditingController(
      text: widget.existing?.collectionInstructions ?? '');
  late String _category = widget.existing?.category ?? 'Merchandise';
  String? _signature, _request, _error;
  EquipmentImage? _selectedCover;
  Uint8List? _coverBytes;
  String? _uploadedCoverUrl;
  int _coverGeneration = 0;
  bool _busy = false;

  Future<void> _pickCover() async {
    if (_busy || !widget.repository.current) return;
    try {
      final image = await context.read<EquipmentImagePicker>().pick();
      if (!mounted || !widget.repository.current || image == null) return;
      setState(() {
        _selectedCover = image;
        _coverBytes = image.copyBytes();
        _uploadedCoverUrl = null;
        _coverGeneration++;
        _image.clear();
        _error = null;
      });
    } catch (_) {
      if (mounted && widget.repository.current) {
        setState(() =>
            _error = 'Choose a JPG, PNG or WebP image no larger than 5 MB.');
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _image,
      _cost,
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
        !widget.repository.current ||
        !_form.currentState!.validate()) {
      return;
    }
    final values = [
      _title.text.trim(),
      _description.text.trim(),
      _category,
      _image.text.trim(),
      _cost.text.trim(),
      _stock.text.trim(),
      _days.text.trim(),
      _conditions.text.trim(),
      _instructions.text.trim()
    ];
    final signature = jsonEncode([...values, _coverGeneration]);
    if (_signature != signature) {
      _signature = signature;
      _request = _requestId();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var imageUrl = values[3];
      if (_selectedCover != null) {
        final media = widget.repository;
        if (media is! RewardMediaRepository) {
          throw StateError('Reward cover upload unavailable');
        }
        _uploadedCoverUrl ??= await (media as RewardMediaRepository)
            .uploadRewardCover(_selectedCover!);
        if (!mounted || !widget.repository.current) return;
        imageUrl = _uploadedCoverUrl!;
      }
      await widget.repository.saveReward(
          requestId: _request!,
          itemId: widget.itemId,
          baseItemRevision: widget.existing?.revision ?? 0,
          title: values[0],
          description: values[1],
          category: values[2],
          imageUrl: imageUrl,
          pointCost: int.parse(values[4]),
          stockToAdd: int.parse(values[5]),
          validityDays: int.parse(values[6]),
          conditions: values[7],
          collectionInstructions: values[8]);
      if (mounted && widget.repository.current) widget.onDone();
    } on RewardMediaUploadFailed catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on RewardCatalogSessionChanged {
      if (mounted) {
        setState(() => _error =
            'Your Admin session changed. Sign in again before saving.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Save not confirmed. Retry unchanged fields, or return and refresh if another Admin changed the reward.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _text(TextEditingController c, String label,
          {int max = 2000, int lines = 1, bool required = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
              controller: c,
              enabled: !_busy,
              maxLength: max,
              maxLines: lines,
              decoration: InputDecoration(labelText: label),
              validator: (v) => required && (v == null || v.trim().isEmpty)
                  ? 'Required'
                  : null));
  Widget _number(TextEditingController c, String label,
          {int max = 100000000}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
              controller: c,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: label),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                return n == null || n < (c == _stock ? 0 : 1) || n > max
                    ? 'Enter a whole number from ${c == _stock ? 0 : 1} to $max'
                    : null;
              }));
  @override
  Widget build(BuildContext context) {
    if (!widget.repository.current) {
      return const Center(
          child: Text('Reward management unavailable for this session.'));
    }
    return Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
            child: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 850),
                    child: Form(
                        key: _form,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextButton.icon(
                                  onPressed: _busy ? null : widget.onDone,
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('Reward Catalog')),
                              Text(
                                  widget.existing == null
                                      ? 'Add reward'
                                      : 'Edit reward',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium),
                              if (widget.existing?.active == false)
                                const Text(
                                    'Saving returns this reward to the shop. Existing vouchers keep their original terms.'),
                              const SizedBox(height: 16),
                              Panel(
                                  child: Column(children: [
                                _text(_title, 'Title',
                                    max: 120, required: true),
                                _text(_description, 'Description', lines: 3),
                                DropdownButtonFormField<String>(
                                    initialValue: _category,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Category'),
                                    items: RewardCatalogDraft.categories
                                        .map((v) => DropdownMenuItem(
                                            value: v, child: Text(v)))
                                        .toList(),
                                    onChanged: _busy
                                        ? null
                                        : (v) =>
                                            setState(() => _category = v!)),
                                const SizedBox(height: 12),
                                Align(
                                    alignment: Alignment.centerLeft,
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Eyebrow('Reward cover'),
                                          ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              child: _coverBytes != null
                                                  ? Container(
                                                      height: 220,
                                                      width: double.infinity,
                                                      color:
                                                          AppColors.primaryTint,
                                                      child: Image.memory(
                                                          _coverBytes!,
                                                          fit: BoxFit.contain,
                                                          errorBuilder: (_, __,
                                                                  ___) =>
                                                              const Center(
                                                                  child: Text(
                                                                      'Image preview unavailable'))))
                                                  : _cover(_image.text,
                                                      height: 220)),
                                          const SizedBox(height: 12),
                                          Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                OutlinedButton.icon(
                                                    onPressed: _busy ||
                                                            widget.repository
                                                                is! RewardMediaRepository
                                                        ? null
                                                        : _pickCover,
                                                    icon: const Icon(
                                                        Icons.upload_outlined),
                                                    label: Text(_selectedCover !=
                                                                null ||
                                                            _image
                                                                .text.isNotEmpty
                                                        ? 'Change cover'
                                                        : 'Choose cover image')),
                                                if (_selectedCover != null ||
                                                    _image.text.isNotEmpty)
                                                  TextButton(
                                                      onPressed: _busy
                                                          ? null
                                                          : () => setState(() {
                                                                _selectedCover =
                                                                    null;
                                                                _coverBytes =
                                                                    null;
                                                                _uploadedCoverUrl =
                                                                    null;
                                                                _coverGeneration++;
                                                                _image.clear();
                                                              }),
                                                      child: const Text(
                                                          'Remove cover')),
                                              ]),
                                          const Text(
                                              'JPG, PNG or WebP · up to 5 MB. Your selected image uploads when you save.'),
                                          const SizedBox(height: 20),
                                        ])),
                                _number(_cost, 'Points cost'),
                                _number(
                                    _stock,
                                    widget.existing == null
                                        ? 'Initial stock'
                                        : 'Additional stock'),
                                if (widget.existing != null)
                                  Text(
                                      '${widget.existing!.stock} currently in stock. Enter 0 to keep the remaining stock unchanged.'),
                                _number(
                                    _days, 'Validity after redemption (days)',
                                    max: 365),
                                _text(_conditions, 'Conditions',
                                    lines: 3, required: true),
                                _text(_instructions, 'Collection instructions',
                                    lines: 3, required: true),
                              ])),
                              const SizedBox(height: 12),
                              const Text(
                                  'Unused expired rewards keep their points spent. Removing a reward from the shop preserves issued vouchers.'),
                              if (_error != null)
                                Text(_error!,
                                    style: const TextStyle(
                                        color: AppColors.danger)),
                              const SizedBox(height: 16),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                OutlinedButton(
                                    onPressed: _busy ? null : widget.onDone,
                                    child: const Text('Cancel')),
                                FilledButton(
                                    onPressed: _busy ? null : _save,
                                    child: Text(_busy
                                        ? 'Saving…'
                                        : widget.existing == null
                                            ? 'Create reward'
                                            : 'Save changes'))
                              ]),
                            ]))))));
  }
}
