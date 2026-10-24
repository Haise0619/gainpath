import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/workout.dart';

/// Defensive network image loader: a broken/slow link never breaks the
/// layout — the same pattern used across the member-facing modules.
Widget _networkHero(String url, {BoxFit fit = BoxFit.cover}) {
  if (url.trim().isEmpty) {
    return const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.heroGradient));
  }
  return Image.network(
    url,
    fit: fit,
    // Saved download URLs may not permit canvas/XHR reads across origins.
    // Native HTML image display works without changing bucket CORS or access.
    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : Container(color: AppColors.surfaceAlt),
    errorBuilder: (context, error, stack) => const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.heroGradient)),
  );
}

/// Admin management view over `gymEquipment` — the catalogue
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
  List<GymEquipment> _equipment = [];
  bool _loading = true, _saving = false, _reloadRequired = false;
  String? _error, _cursor;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _reloadRequired = false;
      if (!more) {
        _equipment = [];
        _cursor = null;
      }
    });
    try {
      final page = await context
          .read<EquipmentRepository>()
          .loadEquipment(afterId: more ? _cursor : null);
      if (!mounted || generation != _generation) return;
      setState(() {
        _equipment = [..._equipment, ...page.items];
        _cursor = page.nextCursor;
        _loading = false;
        if (_category != 'All' &&
            !_equipment.any((e) => e.category == _category)) {
          _category = 'All';
        }
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _equipment = [];
        _error = 'Could not load equipment. Check authorization and retry.';
      });
    }
  }

  Future<void> _edit([GymEquipment? equipment]) async {
    final saved = await showDialog<bool>(
        context: context,
        builder: (_) => _EquipmentFormDialog(existing: equipment));
    if (saved == true && mounted) await _load();
  }

  Future<void> _activate(GymEquipment equipment, bool active) async {
    if (_saving || _reloadRequired) return;
    setState(() => _saving = true);
    try {
      await context
          .read<EquipmentRepository>()
          .saveEquipment(equipment.copyWith(isActive: active));
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _reloadRequired = true;
          _error =
              'Change was not verified or the record changed. Refresh the catalog before retrying.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipment = _equipment;
    final categories = [
      'All',
      ...{for (final e in equipment) e.category}
    ];
    final visible = _category == 'All'
        ? equipment
        : equipment.where((e) => e.category == _category).toList();
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
                    '$activeCount active, ${equipment.length} loaded for Member browsing',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                IconButton(
                    tooltip: 'Refresh equipment',
                    onPressed: _loading || _saving ? null : () => _load(),
                    icon: const Icon(Icons.refresh)),
                FilledButton.icon(
                  onPressed: _loading || _saving || _error != null
                      ? null
                      : () => _edit(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add equipment'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(_error!),
                    TextButton(
                        onPressed: _loading || _saving ? null : () => _load(),
                        child: const Text('Reload equipment'))
                  ])),
            if (!_loading && _error == null && equipment.isEmpty)
              const Panel(
                  child: Text(
                      'No equipment yet. Add an item, then activate it for Members.')),
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
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.ink),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: const BorderSide(color: AppColors.hairline)),
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
                            child: SizedBox(
                                width: 56,
                                height: 56,
                                child: _networkHero(e.imageUrl)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 2),
                                Text('${e.category}  ·  ${e.muscleGroup}',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: e.isActive,
                                onChanged: _saving || _reloadRequired
                                    ? null
                                    : (v) => _activate(e, v),
                              ),
                              Text(e.isActive ? 'Published' : 'Hidden',
                                  style: const TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.inkSoft)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: _saving || _reloadRequired
                                ? null
                                : () => _edit(e),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
            if (_cursor != null)
              TextButton(
                  onPressed:
                      _loading || _saving ? null : () => _load(more: true),
                  child: const Text('Load more equipment')),
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
  bool _saving = false, _reloadRequired = false;
  bool _picking = false;
  EquipmentImage? _selectedImage;
  String? _imageError;
  EquipmentVideo? _selectedVideo;
  bool _pickingVideo = false, _removeVideo = false;
  double? _videoProgress;
  String? _videoError;
  Future<void> _chooseVideo() async {
    if (_busy || _reloadRequired) return;
    setState(() {
      _pickingVideo = true;
      _videoError = null;
    });
    try {
      final video = await context.read<EquipmentVideoPicker>().pick();
      if (mounted && video != null) {
        setState(() {
          _selectedVideo = video;
          _removeVideo = false;
        });
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => _videoError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _videoError = 'Could not select a video. Try again.');
      }
    } finally {
      if (mounted) setState(() => _pickingVideo = false);
    }
  }

  bool get _busy => _saving || _picking || _pickingVideo;
  String? _error;
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _category =
      TextEditingController(text: widget.existing?.category ?? '');
  late final _muscleGroup =
      TextEditingController(text: widget.existing?.muscleGroup ?? '');
  late final _imageUrl =
      TextEditingController(text: widget.existing?.imageUrl ?? '');
  late final _description =
      TextEditingController(text: widget.existing?.description ?? '');
  late List<String> _howToUse = [...(widget.existing?.howToUse ?? const [])];
  late List<String> _safetyTips = [
    ...(widget.existing?.safetyTips ?? const [])
  ];

  bool get _isEdit => widget.existing != null;

  Future<void> _chooseImage() async {
    if (_busy || _reloadRequired) return;
    setState(() {
      _picking = true;
      _imageError = null;
    });
    try {
      final image = await context.read<EquipmentImagePicker>().pick();
      if (mounted && image != null) setState(() => _selectedImage = image);
    } on FormatException catch (e) {
      if (mounted) setState(() => _imageError = e.message);
    } catch (_) {
      if (mounted) {
        setState(
            () => _imageError = 'Could not select an image. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _muscleGroup.dispose();
    _imageUrl.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _reloadRequired) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repository = context.read<EquipmentRepository>();
    final entry = widget.existing?.copyWith() ??
        GymEquipment(
            id: '',
            name: '',
            category: '',
            muscleGroup: '',
            imageUrl: '',
            description: '',
            howToUse: [],
            safetyTips: [],
            isActive: !repository.isLive);
    entry
      ..name = _name.text.trim()
      ..category = _category.text.trim()
      ..muscleGroup = _muscleGroup.text.trim()
      ..tutorialVideoUrl =
          _removeVideo ? '' : (widget.existing?.tutorialVideoUrl ?? '')
      ..imageUrl = _imageUrl.text.trim()
      ..description = _description.text.trim()
      ..howToUse = List.of(_howToUse)
      ..safetyTips = List.of(_safetyTips);
    try {
      entry.validate();
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    setState(() => _saving = true);
    try {
      await repository.saveEquipment(entry,
          image: _selectedImage,
          video: _selectedVideo, onVideoProgress: (value) {
        if (mounted) setState(() => _videoProgress = value);
      });
      if (mounted) Navigator.pop(context, true);
    } on EquipmentVideoUploadFailed {
      if (mounted) {
        setState(() => _error =
            'Video upload failed. Equipment was not saved. Check your connection and retry.');
      }
    } on EquipmentImageUploadFailed {
      if (mounted) {
        setState(() => _error =
            'Image upload failed. Equipment was not saved. Check your connection and authorization, then retry.');
      }
    } on EquipmentConflict {
      if (mounted) {
        setState(() {
          _reloadRequired = true;
          _error =
              'Equipment changed or was removed. Discard and reload before saving.';
        });
      }
    } on EquipmentSessionChanged {
      if (mounted) {
        setState(() {
          _reloadRequired = true;
          _error =
              'Account or authorization changed. Sign in again before editing.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _reloadRequired = true;
          _error = 'Save was not verified. Discard and reload before retrying.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
              Text(_isEdit ? 'Edit equipment' : 'Add equipment',
                  style: Theme.of(context).textTheme.titleLarge),
              if (context.read<EquipmentRepository>().isLive)
                const Text(
                    'Organization equipment information. New items start hidden; activation enables Member browsing. Optional tutorials appear on Equipment Details.'),
              if (_error != null) Text(_error!),
              if (_reloadRequired)
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Discard and reload')),
              const SizedBox(height: 16),
              const Text('Tutorial video (optional)'),
              const Text(
                  'MP4 · up to 100 MB. Use H.264 video with AAC audio for device compatibility. Uploaded when you save.'),
              if (_selectedVideo != null)
                Semantics(
                    liveRegion: true,
                    child: Text(
                        'Selected: ${_selectedVideo!.name} (${(_selectedVideo!.bytes.length / 1048576).toStringAsFixed(1)} MB). Save to apply.'))
              else if (_removeVideo)
                const Text('Tutorial will be removed when you save.')
              else if (widget.existing?.tutorialVideoUrl.isNotEmpty == true)
                const Text('A tutorial video is attached.'),
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(
                    onPressed: _busy || _reloadRequired ? null : _chooseVideo,
                    icon: const Icon(Icons.video_library_outlined),
                    label: Text(_pickingVideo
                        ? 'Opening video…'
                        : 'Choose tutorial video')),
                if (_selectedVideo != null ||
                    (!_removeVideo &&
                        widget.existing?.tutorialVideoUrl.isNotEmpty == true))
                  TextButton(
                      onPressed: _busy || _reloadRequired
                          ? null
                          : () => setState(() {
                                _selectedVideo = null;
                                _removeVideo = true;
                              }),
                      child: const Text('Remove tutorial')),
                if (_removeVideo &&
                    widget.existing?.tutorialVideoUrl.isNotEmpty == true)
                  TextButton(
                      onPressed: _busy || _reloadRequired
                          ? null
                          : () => setState(() => _removeVideo = false),
                      child: const Text('Undo removal')),
              ]),
              if (_videoError != null)
                Semantics(
                    liveRegion: true,
                    child: Text(_videoError!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
              if (_saving && _selectedVideo != null) ...[
                LinearProgressIndicator(value: _videoProgress),
                Text(_videoProgress == null
                    ? 'Preparing video upload…'
                    : 'Uploading tutorial: ${(_videoProgress! * 100).round()}%'),
              ],
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _name,
                      enabled: !_busy && !_reloadRequired,
                      decoration: const InputDecoration(
                          labelText: 'Name', isDense: true),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _category,
                      enabled: !_busy && !_reloadRequired,
                      decoration: const InputDecoration(
                          labelText: 'Category', isDense: true),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                      enabled: !_busy && !_reloadRequired,
                      decoration: const InputDecoration(
                          labelText: 'Muscle group', isDense: true),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: context.read<EquipmentRepository>().isLive
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                const Text('Equipment image'),
                                const SizedBox(height: 8),
                                if (_selectedImage != null ||
                                    _imageUrl.text.isNotEmpty)
                                  SizedBox(
                                      height: 100,
                                      width: 160,
                                      child: _selectedImage == null
                                          ? _networkHero(_imageUrl.text)
                                          : kIsWeb
                                              ? Image.network(
                                                  'data:${_selectedImage!.contentType};base64,${base64Encode(_selectedImage!.bytes)}',
                                                  key: const ValueKey(
                                                      'equipment-selected-image-preview'),
                                                  webHtmlElementStrategy:
                                                      WebHtmlElementStrategy
                                                          .prefer,
                                                  fit: BoxFit.contain)
                                              : Image.memory(
                                                  _selectedImage!.bytes,
                                                  key: const ValueKey(
                                                      'equipment-selected-image-preview'),
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(Icons
                                                          .broken_image_outlined))),
                                OutlinedButton.icon(
                                    onPressed: _busy || _reloadRequired
                                        ? null
                                        : _chooseImage,
                                    icon:
                                        const Icon(Icons.upload_file_outlined),
                                    label: Text(_picking
                                        ? 'Opening…'
                                        : 'Choose image')),
                                const Text(
                                    'JPG, PNG or WebP · up to 5 MB. Uploaded when you save.'),
                                if (_imageError != null)
                                  Semantics(
                                      liveRegion: true,
                                      child: Text(_imageError!,
                                          key: const ValueKey(
                                              'equipment-image-error'),
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error))),
                                if (_selectedImage != null)
                                  Semantics(
                                      liveRegion: true,
                                      child: Text(_isEdit
                                          ? 'New image selected. Save changes to apply it.'
                                          : 'Image selected. Save to upload it.')),
                                if (_selectedImage != null)
                                  TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => setState(
                                              () => _selectedImage = null),
                                      child:
                                          const Text('Discard selected image')),
                              ])
                        : TextFormField(
                            controller: _imageUrl,
                            enabled: !_busy && !_reloadRequired,
                            decoration: const InputDecoration(
                                labelText: 'Image URL', isDense: true),
                            validator: (v) => null,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                enabled: !_busy && !_reloadRequired,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Description', isDense: true),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              IgnorePointer(
                  ignoring: _busy || _reloadRequired,
                  child: EditableStringList(
                    label: 'How to use',
                    items: _howToUse,
                    onChanged: (v) => _howToUse = v,
                  )),
              const SizedBox(height: 14),
              IgnorePointer(
                  ignoring: _busy || _reloadRequired,
                  child: EditableStringList(
                    label: 'Safety tips',
                    items: _safetyTips,
                    onChanged: (v) => _safetyTips = v,
                  )),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        child: const Text('Cancel')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                        onPressed: _busy || _reloadRequired ? null : _save,
                        child: Text(_saving
                            ? (_selectedImage == null
                                ? 'Saving…'
                                : 'Uploading and saving…')
                            : _isEdit
                                ? 'Save changes'
                                : 'Add equipment')),
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
  const EditableStringList(
      {super.key,
      required this.label,
      required this.items,
      required this.onChanged});

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
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            TextButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add line'),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
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
                    decoration: InputDecoration(
                        isDense: true, hintText: 'Step ${i + 1}'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () => _remove(i),
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
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
