import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import '../../../../navigation/admin_breadcrumb.dart';
import '../../../../media/video_preview.dart';
import 'mini_game_reward_policy_panel.dart';
import 'mini_game_standings_screen.dart';
import '../../../../infrastructure/firebase/firebase_mini_game_competition_repository.dart';

String _gameName(String id) =>
    id == MiniGameContent.reachTapId ? 'Reach & Tap' : 'Move & Catch';

List<MiniGameContent> _knownContent(
        List<MiniGameContent> items, String organizationId) =>
    [
      for (final id in MiniGameContent.supportedIds)
        items
                .where((item) =>
                    item.gameId == id && item.organizationId == organizationId)
                .firstOrNull ??
            MiniGameContent.defaults(organizationId, gameId: id),
    ];

String _newId() {
  final random = Random.secure();
  return List.generate(
      16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

Widget _cover(String url, {Uint8List? bytes}) {
  const fallback = ColoredBox(
      color: AppColors.primaryTint,
      child: Center(
          child: Icon(Icons.sports_esports_outlined,
              size: 48, color: AppColors.primary)));
  return AspectRatio(
      aspectRatio: 16 / 9,
      child: bytes != null
          ? Image.memory(bytes,
              fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback)
          : url.isEmpty
              ? fallback
              : Image.network(url,
                  fit: BoxFit.contain,
                  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                  errorBuilder: (_, __, ___) => fallback));
}

/// Authoring for system-supported games. Registry and gameplay stay managed.
class MiniGameContentScreen extends StatefulWidget {
  const MiniGameContentScreen(
      {super.key,
      this.repository,
      this.imagePicker,
      this.videoPicker,
      this.competitionRepository});
  final MiniGameContentRepository? repository;
  final MiniGameCompetitionRepository? competitionRepository;
  final EquipmentImagePicker? imagePicker;
  final EquipmentVideoPicker? videoPicker;

  @override
  State<MiniGameContentScreen> createState() => _MiniGameContentScreenState();
}

class _MiniGameContentScreenState extends State<MiniGameContentScreen> {
  late MiniGameContentRepository _repository;
  List<MiniGameContent>? _items;
  MiniGameContent? _editing;
  String? _error;
  int _generation = 0;
  bool _loading = false;
  String _query = '';
  String _mediaFilter = 'all';
  bool get _expandedRegistryAvailable =>
      _repository is! MiniGameContentRegistryStatus ||
      (_repository as MiniGameContentRegistryStatus).expandedRegistryAvailable;
  bool _editable(MiniGameContent content) =>
      content.gameId != MiniGameContent.reachTapId ||
      _expandedRegistryAvailable;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? context.read<MiniGameContentRepository>();
    _load();
  }

  @override
  void didUpdateWidget(MiniGameContentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final repository =
        widget.repository ?? context.read<MiniGameContentRepository>();
    if (!identical(repository, _repository)) {
      _repository = repository;
      _editing = null;
      _items = null;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final repository = _repository;
    if (!repository.current) return;
    setState(() {
      _loading = true;
      _error = null;
      _editing = null;
    });
    try {
      final items = await repository.load();
      if (!mounted || generation != _generation || !repository.current) return;
      setState(() {
        _items = _knownContent(items, repository.scope.organizationId);
        _editing = null;
      });
    } catch (_) {
      if (mounted && generation == _generation && repository.current) {
        setState(() => _error =
            'Could not load mini-game content. Check Admin access and retry.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_repository.current) return const _SessionUnavailable();
    if (_editing != null) {
      return _ContentEditor(
          key: ObjectKey(_editing),
          repository: _repository,
          content: _editing!,
          imagePicker: widget.imagePicker,
          videoPicker: widget.videoPicker,
          onCancel: () => setState(() => _editing = null),
          onReload: _load,
          onSaved: (items) => setState(() {
                _items = items;
                _editing = null;
              }));
    }
    return Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
                24,
                MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
                40),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Mini-games',
                        style: Theme.of(context).textTheme.headlineMedium),
                    OutlinedButton.icon(
                        onPressed: _loading ? null : _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reload')),
                    OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => MiniGameStandingsScreen(
                                    repository: widget.competitionRepository ??
                                        FirebaseAdminMiniGameCompetitionRepository(
                                            scope: _repository.scope,
                                            isCurrent: () =>
                                                _repository.current)))),
                        icon: const Icon(Icons.leaderboard_outlined),
                        label: const Text('Game standings')),
                  ]),
              const SizedBox(height: 8),
              const Text(
                  'Manage Member introductions, instructions and media for the two implemented games.'),
              const SizedBox(height: 24),
              if (_loading)
                const LinearProgressIndicator()
              else if (_error != null)
                Panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(_error!,
                          style: const TextStyle(color: AppColors.danger)),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ]))
              else if (_items != null) ...[
                _registry(context),
                const SizedBox(height: 24),
                const Eyebrow('Rewards'),
                const Text(
                    'Move & Catch uses the existing mini-game reward policy. Reach & Tap reward points are inactive.'),
                const SizedBox(height: 12),
                if (context.read<MiniGameRewardConfigurationRepository?>()
                    case final configuration?)
                  MiniGameRewardPolicyPanel(repository: configuration),
              ],
            ])));
  }

  Widget _registry(BuildContext context) {
    final items = _items!.where((item) {
      final search = '${_gameName(item.gameId)} ${item.title} ${item.gameId}'
          .toLowerCase();
      final hasMedia =
          item.coverUrl.isNotEmpty || item.previewVideoUrl.isNotEmpty;
      return search.contains(_query.toLowerCase().trim()) &&
          (_mediaFilter == 'all' ||
              (_mediaFilter == 'with' ? hasMedia : !hasMedia));
    }).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 24, runSpacing: 12, children: [
        Text('${_items!.length} implemented games',
            style: Theme.of(context).textTheme.titleMedium),
        Text(
            '${_items!.where((item) => !item.isBuiltIn).length} saved content overrides'),
        Text(
            '${_items!.where((item) => item.coverUrl.isNotEmpty || item.previewVideoUrl.isNotEmpty).length} with media'),
      ]),
      const SizedBox(height: 20),
      LayoutBuilder(builder: (context, constraints) {
        final search = TextField(
            key: const Key('mini-game-search'),
            decoration: const InputDecoration(
                labelText: 'Search games',
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Name or game ID'),
            onChanged: (value) => setState(() => _query = value));
        final filter = DropdownButtonFormField<String>(
            key: const Key('mini-game-media-filter'),
            initialValue: _mediaFilter,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Media'),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All media states')),
              DropdownMenuItem(value: 'with', child: Text('With media')),
              DropdownMenuItem(value: 'without', child: Text('Without media'))
            ],
            onChanged: (value) =>
                setState(() => _mediaFilter = value ?? 'all'));
        if (constraints.maxWidth < 680 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.5) {
          return Column(children: [search, const SizedBox(height: 12), filter]);
        }
        return Row(children: [
          Expanded(child: search),
          const SizedBox(width: 16),
          SizedBox(width: 240, child: filter)
        ]);
      }),
      const SizedBox(height: 16),
      if (!_expandedRegistryAvailable) ...[
        const Panel(
            child: Text(
                'Reach & Tap is showing its built-in guide. Editing is unavailable on the connected server. Reload after the expanded content registry is released.')),
        const SizedBox(height: 16),
      ],
      if (items.isEmpty)
        const Panel(child: Text('No games match these filters.'))
      else
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < 900 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.5) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in items)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Panel(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(item.title,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(
                                  '${_gameName(item.gameId)} · ${item.gameId}'),
                              const SizedBox(height: 12),
                              _contentStatus(item),
                              const SizedBox(height: 8),
                              _mediaStatus(item),
                              const SizedBox(height: 12),
                              _editAction(item),
                            ]))),
                ]);
          }
          return Panel(
              key: const Key('mini-game-registry-table'),
              padding: EdgeInsets.zero,
              child: SizedBox(
                  width: double.infinity,
                  child: DataTable(
                    headingRowColor:
                        const WidgetStatePropertyAll(AppColors.surfaceAlt),
                    headingRowHeight: 52,
                    dataRowMinHeight: 104,
                    dataRowMaxHeight: 120,
                    columnSpacing: 24,
                    horizontalMargin: 24,
                    columns: const [
                      DataColumn(label: Text('Cover')),
                      DataColumn(label: Text('Game')),
                      DataColumn(label: Text('Content')),
                      DataColumn(label: Text('Media')),
                      DataColumn(label: Text('Action'))
                    ],
                    rows: [
                      for (final item in items)
                        DataRow(cells: [
                          DataCell(SizedBox(
                              width: 104,
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _cover(item.coverUrl)))),
                          DataCell(SizedBox(
                              width: (constraints.maxWidth * .24)
                                  .clamp(140, 420)
                                  .toDouble(),
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(
                                        '${_gameName(item.gameId)} · ${item.gameId}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ]))),
                          DataCell(_contentStatus(item)),
                          DataCell(_mediaStatus(item)),
                          DataCell(_editAction(item)),
                        ])
                    ],
                  )));
        }),
    ]);
  }

  Widget _contentStatus(MiniGameContent item) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.isBuiltIn ? 'Built-in guide' : 'Saved content',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(item.isBuiltIn
                ? 'No saved override'
                : 'Revision ${item.revision}'),
          ]);
  Widget _mediaStatus(MiniGameContent item) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                item.coverUrl.isEmpty ? 'No cover image' : 'Cover image saved'),
            Text(item.previewVideoUrl.isEmpty
                ? 'No preview video'
                : 'Preview video saved'),
          ]);
  Widget _editAction(MiniGameContent item) => OutlinedButton.icon(
      key: Key('edit-${item.gameId}'),
      onPressed: !_editable(item)
          ? null
          : () {
              if (_repository.current) setState(() => _editing = item);
            },
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Edit content'));
}

class _SessionUnavailable extends StatelessWidget {
  const _SessionUnavailable();
  @override
  Widget build(BuildContext context) => const Center(
      child: Text('Mini-game content unavailable for this session.'));
}

class _ContentEditor extends StatefulWidget {
  const _ContentEditor(
      {super.key,
      required this.repository,
      required this.content,
      required this.onCancel,
      required this.onReload,
      required this.onSaved,
      this.imagePicker,
      this.videoPicker});
  final MiniGameContentRepository repository;
  final MiniGameContent content;
  final EquipmentImagePicker? imagePicker;
  final EquipmentVideoPicker? videoPicker;
  final VoidCallback onCancel;
  final Future<void> Function() onReload;
  final ValueChanged<List<MiniGameContent>> onSaved;
  @override
  State<_ContentEditor> createState() => _ContentEditorState();
}

class _ContentEditorState extends State<_ContentEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _introduction;
  late final List<TextEditingController> _instructions;
  late String _coverUrl, _videoUrl;
  EquipmentImage? _image;
  EquipmentVideo? _video;
  Uint8List? _imageBytes;
  String? _coverUploadId, _videoUploadId, _saveId, _error, _mediaError;
  bool _coverUploaded = false, _videoUploaded = false;
  bool _saving = false,
      _picking = false,
      _reloadRequired = false,
      _sessionLost = false;
  bool get _busy => _saving || _picking;
  bool get _current => mounted && !_sessionLost && widget.repository.current;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.content.title);
    _introduction = TextEditingController(text: widget.content.introduction);
    _instructions = widget.content.instructions
        .map((value) => TextEditingController(text: value))
        .toList();
    _coverUrl = widget.content.coverUrl;
    _videoUrl = widget.content.previewVideoUrl;
  }

  @override
  void dispose() {
    _title.dispose();
    _introduction.dispose();
    for (final controller in _instructions) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() => _saveId = null);

  Future<void> _chooseCover() async {
    if (!_current || _busy) return;
    setState(() {
      _picking = true;
      _mediaError = null;
    });
    try {
      final value =
          await (widget.imagePicker ?? context.read<EquipmentImagePicker>())
              .pick();
      if (!_current || value == null) return;
      setState(() {
        _image = value;
        _imageBytes = value.copyBytes();
        _coverUploadId = _newId();
        _coverUploaded = false;
        _saveId = null;
      });
    } on FormatException catch (error) {
      if (_current) setState(() => _mediaError = error.message);
    } catch (_) {
      if (_current) {
        setState(
            () => _mediaError = 'Could not select the cover image. Try again.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _chooseVideo() async {
    if (!_current || _busy) return;
    setState(() {
      _picking = true;
      _mediaError = null;
    });
    try {
      final value =
          await (widget.videoPicker ?? context.read<EquipmentVideoPicker>())
              .pick();
      if (!_current || value == null) return;
      if (value.bytes.length > MiniGameContent.maxPreviewBytes) {
        throw const FormatException(
            'Choose an MP4 preview no larger than 20 MB.');
      }
      setState(() {
        _video = value;
        _videoUploadId = _newId();
        _videoUploaded = false;
        _saveId = null;
      });
    } on FormatException catch (error) {
      if (_current) setState(() => _mediaError = error.message);
    } catch (_) {
      if (_current) {
        setState(() =>
            _mediaError = 'Could not select the preview video. Try again.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (!_current || _busy || _reloadRequired) return;
    if (!_form.currentState!.validate()) return;
    final repository = widget.repository;
    _saveId ??= _newId();
    setState(() {
      _saving = true;
      _error = null;
      _mediaError = null;
    });
    try {
      if (_image != null && !_coverUploaded) {
        if (!_current) return;
        final url = await repository.upload(
            gameId: widget.content.gameId,
            kind: 'cover',
            uploadId: _coverUploadId!,
            bytes: _image!.copyBytes(),
            contentType: _image!.contentType);
        if (!_current) return;
        _coverUrl = url;
        _coverUploaded = true;
      }
      if (_video != null && !_videoUploaded) {
        if (!_current) return;
        final url = await repository.upload(
            gameId: widget.content.gameId,
            kind: 'preview',
            uploadId: _videoUploadId!,
            bytes: _video!.copyBytes(),
            contentType: 'video/mp4');
        if (!_current) return;
        _videoUrl = url;
        _videoUploaded = true;
      }
      if (!_current) return;
      final content = widget.content.copyWith(
          title: _title.text.trim(),
          introduction: _introduction.text.trim(),
          instructions: _instructions.map((c) => c.text.trim()).toList(),
          coverUrl: _coverUrl,
          previewVideoUrl: _videoUrl);
      final saved = await repository.save(
          requestId: _saveId!,
          baseRevision: widget.content.revision,
          content: content);
      if (!_current) return;
      final items = await repository.load();
      if (!_current) return;
      final scoped = items
          .where((item) =>
              MiniGameContent.supportedIds.contains(item.gameId) &&
              item.organizationId == repository.scope.organizationId)
          .toList();
      if (!scoped.any((item) =>
          item.gameId == saved.gameId && item.revision >= saved.revision)) {
        throw const MiniGameContentUnavailable();
      }
      widget.onSaved(_knownContent(scoped, repository.scope.organizationId));
    } on MiniGameContentConflict {
      if (_current) {
        setState(() {
          _reloadRequired = true;
          _error =
              'This content changed elsewhere. Reload before editing again.';
        });
      }
    } on MiniGameContentSessionChanged {
      if (mounted) setState(() => _sessionLost = true);
    } on MiniGameContentUploadFailed catch (error) {
      if (_current) setState(() => _error = error.message);
    } catch (_) {
      if (_current) {
        setState(() => _error =
            'Save was not confirmed. Retry with these edits or reload.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _requiredText(String? value, int max, String empty) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return empty;
    if (text.length > max) return 'Use $max characters or fewer.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionLost || !widget.repository.current) {
      return const _SessionUnavailable();
    }
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
                    24,
                    MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
                    40),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: PageBreadcrumb(crumbs: [
                            PageCrumb('Mini-games', () {
                              if (!_busy) widget.onCancel();
                            }),
                            const PageCrumb('Edit content'),
                          ])),
                      const SizedBox(height: 6),
                      Text('Edit mini-game content',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Text(
                          '${_gameName(widget.content.gameId)} · Member introduction and how to play'),
                      const SizedBox(height: 16),
                      _editorActions(),
                      const SizedBox(height: 22),
                      LayoutBuilder(builder: (context, constraints) {
                        final form = _formPanel(context),
                            preview = _preview(context);
                        if (constraints.maxWidth >= 900) {
                          return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: form),
                                const SizedBox(width: 20),
                                Expanded(flex: 2, child: preview),
                              ]);
                        }
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              form,
                              const SizedBox(height: 20),
                              preview
                            ]);
                      }),
                    ]))));
  }

  Widget _editorActions() => Wrap(spacing: 10, runSpacing: 10, children: [
        OutlinedButton(
            onPressed: _busy ? null : widget.onCancel,
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _busy || _reloadRequired ? null : _save,
            child: Text(_saving
                ? 'Saving…'
                : _error != null && !_reloadRequired
                    ? 'Retry save'
                    : 'Save changes')),
        if (_error != null || _reloadRequired)
          TextButton(
              onPressed: _busy ? null : widget.onReload,
              child: const Text('Discard edits and reload')),
      ]);

  Widget _formPanel(BuildContext context) => Form(
      key: _form,
      onChanged: _changed,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Eyebrow('Content details'),
        Panel(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              TextFormField(
                  key: const Key('mini-game-title'),
                  controller: _title,
                  enabled: !_busy && !_reloadRequired,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Display title'),
                  validator: (v) =>
                      _requiredText(v, 80, 'Enter a display title.')),
              const SizedBox(height: 14),
              TextFormField(
                  key: const Key('mini-game-introduction'),
                  controller: _introduction,
                  enabled: !_busy && !_reloadRequired,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: 2000,
                  decoration: const InputDecoration(labelText: 'Introduction'),
                  validator: (v) =>
                      _requiredText(v, 2000, 'Enter an introduction.')),
            ])),
        const SizedBox(height: 18),
        const Eyebrow('How to play'),
        Panel(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const Text('Add 1–8 numbered instructions.'),
              const SizedBox(height: 12),
              for (var i = 0; i < _instructions.length; i++)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: TextFormField(
                                  key: Key('mini-game-instruction-$i'),
                                  controller: _instructions[i],
                                  enabled: !_busy && !_reloadRequired,
                                  minLines: 2,
                                  maxLines: 5,
                                  maxLength: 500,
                                  decoration: InputDecoration(
                                      labelText: 'Instruction ${i + 1}'),
                                  validator: (v) => _requiredText(
                                      v, 500, 'Enter an instruction.'))),
                          IconButton(
                              tooltip: 'Remove instruction',
                              onPressed: _busy ||
                                      _reloadRequired ||
                                      _instructions.length <= 1
                                  ? null
                                  : () {
                                      final removed = _instructions.removeAt(i);
                                      _changed();
                                      WidgetsBinding.instance
                                          .addPostFrameCallback(
                                              (_) => removed.dispose());
                                    },
                              icon: const Icon(Icons.remove_circle_outline)),
                        ])),
              Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                      onPressed:
                          _busy || _reloadRequired || _instructions.length >= 8
                              ? null
                              : () {
                                  _instructions.add(TextEditingController());
                                  _changed();
                                },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add instruction'))),
            ])),
        const SizedBox(height: 18),
        const Eyebrow('Media'),
        Panel(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const Text('Cover image',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(_image != null
                  ? 'New cover selected'
                  : _coverUrl.isNotEmpty
                      ? 'Saved cover image'
                      : 'No cover image selected'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                    onPressed: _busy || _reloadRequired ? null : _chooseCover,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(_image != null || _coverUrl.isNotEmpty
                        ? 'Replace cover image'
                        : 'Choose cover image')),
                if (_image != null || _coverUrl.isNotEmpty)
                  TextButton(
                      onPressed: _busy || _reloadRequired
                          ? null
                          : () => setState(() {
                                _image = null;
                                _imageBytes = null;
                                _coverUrl = '';
                                _coverUploadId = null;
                                _coverUploaded = false;
                                _saveId = null;
                              }),
                      child: const Text('Remove cover')),
              ]),
              const Text('JPG, PNG or WebP · up to 5 MB'),
              const SizedBox(height: 22),
              const Text('Preview video',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(_video != null
                  ? 'New preview selected'
                  : _videoUrl.isNotEmpty
                      ? 'Saved preview video'
                      : 'No preview video selected'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                    onPressed: _busy || _reloadRequired ? null : _chooseVideo,
                    icon: const Icon(Icons.video_library_outlined),
                    label: Text(_video != null || _videoUrl.isNotEmpty
                        ? 'Replace preview video'
                        : 'Choose preview video')),
                if (_video != null || _videoUrl.isNotEmpty)
                  TextButton(
                      onPressed: _busy || _reloadRequired
                          ? null
                          : () => setState(() {
                                _video = null;
                                _videoUrl = '';
                                _videoUploadId = null;
                                _videoUploaded = false;
                                _saveId = null;
                              }),
                      child: const Text('Remove video')),
              ]),
              const Text('MP4 · up to 20 MB. Files upload when you save.'),
              if (_mediaError != null)
                Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_mediaError!,
                        style: const TextStyle(color: AppColors.danger))),
            ])),
        const SizedBox(height: 22),
        if (_saving) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          const Text('Uploading media and verifying saved content…'),
          const SizedBox(height: 12)
        ],
        if (_error != null)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!,
                  style: const TextStyle(color: AppColors.danger))),
      ]));

  Widget _preview(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Eyebrow('Member preview'),
        Panel(
            padding: EdgeInsets.zero,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      child: _cover(_coverUrl, bytes: _imageBytes)),
                  Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                _title.text.trim().isEmpty
                                    ? _gameName(widget.content.gameId)
                                    : _title.text.trim(),
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 10),
                            Text(_introduction.text.trim()),
                            const SizedBox(height: 18),
                            Text('How to play',
                                style: Theme.of(context).textTheme.titleMedium),
                            for (var i = 0; i < _instructions.length; i++)
                              Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                      '${i + 1}. ${_instructions[i].text.trim()}')),
                            if (_video != null || _videoUrl.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              ContentVideoPreview(
                                  semanticsLabel: 'Mini-game preview video',
                                  url: _videoUrl,
                                  bytes: _video?.bytes),
                            ],
                          ])),
                ])),
      ]);
}
