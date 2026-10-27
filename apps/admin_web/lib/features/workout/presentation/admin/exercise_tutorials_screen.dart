import 'confirm_content_removal.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../navigation/admin_breadcrumb.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/recommendation.dart';
import 'exercise_tutorial_steps_editor.dart';
import 'exercise_media_fields.dart';
import 'exercise_video_preview.dart';

/// Defensive network image loader — a broken/slow link never breaks the
/// layout, same pattern used across the member-facing modules.
Widget _networkHero(String url, {BoxFit fit = BoxFit.cover}) {
  if (url.trim().isEmpty) {
    return const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.heroGradient));
  }
  return Image.network(
    url,
    fit: fit,
    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : Container(color: AppColors.surfaceAlt),
    errorBuilder: (context, error, stack) => const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.heroGradient)),
  );
}

/// AD-M11.4 — Manage Exercise Tutorial Library. An in-place content pane
/// selected from the sidebar's Content group — not a pushed route — so
/// there is no back arrow to return through. Add/Edit is a full-page
/// form (not a dialog): there's real content to fill in here — video
/// URL, thumbnail, duration, difficulty — enough that a compact popup
/// was cramping it, so it gets its own page with a local breadcrumb
/// instead, the way an AWS Console "Create" flow does.
class ExerciseTutorialsScreen extends StatefulWidget {
  const ExerciseTutorialsScreen({super.key, this.allowRemoval = true});
  final bool allowRemoval;

  @override
  State<ExerciseTutorialsScreen> createState() =>
      _ExerciseTutorialsScreenState();
}

class _ExerciseTutorialsScreenState extends State<ExerciseTutorialsScreen> {
  TutorialVideo? _editing;
  bool _creating = false;
  bool _removing = false;
  late Future<List<TutorialVideo>> _tutorialsFuture;

  @override
  void initState() {
    super.initState();
    _tutorialsFuture = context.read<TutorialRepository>().load();
  }

  void _openCreate() => setState(() => _creating = true);
  void _openEdit(TutorialVideo t) => setState(() => _editing = t);
  void _closeForm() => setState(() {
        _creating = false;
        _editing = null;
        _tutorialsFuture = context.read<TutorialRepository>().load();
      });

  Future<void> _remove(TutorialVideo item) async {
    if (_removing || !widget.allowRemoval) return;
    final repository = context.read<TutorialRepository>();
    if (repository is! TutorialArchivingRepository) return;
    setState(() => _removing = true);
    try {
      final confirmed = await confirmContentRemoval(context,
          title: item.title,
          detail:
              'This archives the exercise and removes it from new routine selections. Existing published routines and workout history are preserved.');
      if (!confirmed || !mounted || !widget.allowRemoval) {
        return;
      }
      await (repository as TutorialArchivingRepository).archive(item);
      if (!mounted) return;
      setState(() => _tutorialsFuture = repository.load());
      showToast(context, 'Exercise removed.');
    } catch (_) {
      if (mounted) {
        showToast(context, 'Removal was not verified. Reload before retrying.');
      }
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_creating || _editing != null) {
      return _TutorialFormPage(existing: _editing, onDone: _closeForm);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder<List<TutorialVideo>>(
        future: _tutorialsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Could not load the exercise catalog.'),
              TextButton(
                  onPressed: () => setState(() => _tutorialsFuture =
                      context.read<TutorialRepository>().load()),
                  child: const Text('Retry')),
            ]));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final tutorials =
              snapshot.data!.where((item) => !item.archived).toList();
          final catalogOnly =
              context.read<TutorialRepository>().requiresCatalogSelection;
          final active =
              tutorials.where((t) => t.status == TutorialStatus.active).length;
          return _tutorialList(context, tutorials, active, catalogOnly);
        },
      ),
    );
  }

  Widget _tutorialList(BuildContext context, List<TutorialVideo> tutorials,
      int active, bool catalogOnly) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (catalogOnly) ...[
            Text('Exercise Catalog',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            const Text(
                'Build routines with AI-tracked and guided-only exercises. Tracking availability is checked by the system.'),
            const SizedBox(height: 18),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                    catalogOnly
                        ? '$active of ${tutorials.length} exercises are active in the catalog.'
                        : '$active of ${tutorials.length} tutorials are live to members.',
                    style: Theme.of(context).textTheme.bodyLarge),
              ),
              IconButton(
                  tooltip: 'Reload catalog',
                  icon: const Icon(Icons.refresh),
                  onPressed: _removing
                      ? null
                      : () => setState(() => _tutorialsFuture =
                          context.read<TutorialRepository>().load())),
              FilledButton.icon(
                onPressed: _removing ? null : _openCreate,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(catalogOnly ? 'Add exercise' : 'Add tutorial'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: List.generate(tutorials.length, (i) {
                final t = tutorials[i];
                return Column(
                  children: [
                    if (i > 0) const Divider(height: 1, indent: 74),
                    ListTile(
                      onTap: () => _openEdit(t),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 6),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: t.thumbnailUrl.isEmpty
                              ? Container(
                                  color: AppColors.ink,
                                  child: const Icon(Icons.play_arrow_rounded,
                                      color: Colors.white),
                                )
                              : _networkHero(t.thumbnailUrl),
                        ),
                      ),
                      title: Text(t.title,
                          style: Theme.of(context).textTheme.titleMedium),
                      subtitle: Text(
                          catalogOnly
                              ? '${t.category}  ·  ${t.trackingCapability.displayLabel}\nID ${t.id}'
                              : '${t.category}  ·  ${t.durationMin} min'
                                  '${t.coversExercise.isEmpty ? '' : '  ·  covers ${t.coversExercise}'}',
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          statusPill(t.status.label),
                          if (t.videoUrl.trim().isNotEmpty)
                            IconButton(
                              tooltip: 'Preview tutorial video',
                              icon: const Icon(Icons.play_circle_outline),
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(t.title),
                                  content: SizedBox(
                                    width: 640,
                                    child:
                                        ExerciseVideoPreview(url: t.videoUrl),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          if (widget.allowRemoval &&
                              context.read<TutorialRepository>()
                                  is TutorialArchivingRepository)
                            IconButton(
                                tooltip: 'Remove exercise',
                                icon:
                                    const Icon(Icons.delete_outline, size: 18),
                                onPressed: _removing ? null : () => _remove(t)),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _openEdit(t),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialFormPage extends StatefulWidget {
  final TutorialVideo? existing;
  final VoidCallback onDone;
  const _TutorialFormPage({this.existing, required this.onDone});

  @override
  State<_TutorialFormPage> createState() => _TutorialFormPageState();
}

class _TutorialFormPageState extends State<_TutorialFormPage> {
  static const _categories = [
    'Compound Lower-Body',
    'Compound Upper-Body',
    'Core',
    'Cardio',
    'Accessory',
  ];
  static const _difficulties = ['Beginner', 'Intermediate', 'Advanced'];

  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '')
    ..addListener(_repaint);
  late final _description =
      TextEditingController(text: widget.existing?.description ?? '')
        ..addListener(_repaint);
  late final _equipment =
      TextEditingController(text: widget.existing?.equipment ?? '');
  late List<ExerciseTutorialStep> _steps =
      List.of(widget.existing?.tutorialSteps ?? []);
  late final _videoUrl =
      TextEditingController(text: widget.existing?.videoUrl ?? '');
  late final _thumbnailUrl =
      TextEditingController(text: widget.existing?.thumbnailUrl ?? '')
        ..addListener(_repaint);
  late final _duration =
      TextEditingController(text: '${widget.existing?.durationMin ?? 5}');
  late String _category = widget.existing?.category ?? _categories.first;
  late String _difficulty = widget.existing?.difficulty ?? _difficulties.first;
  late String _status = widget.existing?.status.label ?? 'Draft';
  late String? _coversExercise = widget.existing?.coversExercise.isEmpty ?? true
      ? null
      : widget.existing!.coversExercise;

  bool get _isEdit => widget.existing != null;
  bool get _catalogOnly =>
      context.read<TutorialRepository>().requiresCatalogSelection;
  String? _saveError;
  bool _saving = false;
  bool _reloadRequired = false;
  bool _pickingMedia = false;
  EquipmentImage? _selectedCover;
  Uint8List? _coverPreviewBytes;
  EquipmentVideo? _selectedVideo;
  String? _mediaError;
  double? _videoProgress;
  bool get _hasMediaUploads =>
      _catalogOnly &&
      context.read<TutorialRepository>() is TutorialMediaRepository;
  bool get _busy => _saving || _pickingMedia;
  late final _editBaseline = widget.existing?.editBaseline;
  late final _editId = widget.existing?.id ?? '';

  void _repaint() => setState(() {});

  Future<void> _chooseCover() => _pickMedia(() async {
        final value = await context.read<EquipmentImagePicker>().pick();
        if (mounted && value != null) {
          setState(() {
            _selectedCover = value;
            _coverPreviewBytes = value.copyBytes();
          });
        }
      });
  Future<void> _chooseVideo() => _pickMedia(() async {
        final value = await context.read<EquipmentVideoPicker>().pick();
        if (mounted && value != null) setState(() => _selectedVideo = value);
      });
  Future<void> _pickMedia(Future<void> Function() pick) async {
    if (_busy || _reloadRequired) return;
    setState(() {
      _pickingMedia = true;
      _mediaError = null;
    });
    try {
      await pick();
    } on FormatException catch (e) {
      if (mounted) setState(() => _mediaError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _mediaError = 'Could not select this file. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _pickingMedia = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _equipment.dispose();
    _videoUrl.dispose();
    _thumbnailUrl.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _reloadRequired) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final duration = int.tryParse(_duration.text.trim()) ?? 5;
    final entry = TutorialVideo(
      id: _editId,
      editBaseline: _editBaseline,
      title: _title.text.trim(),
      category: _category,
      status: TutorialStatus.fromLabel(_status),
      coversExercise: _catalogOnly ? '' : (_coversExercise ?? ''),
      difficulty: _difficulty,
      durationMin: _catalogOnly ? 0 : duration,
      videoUrl: _videoUrl.text.trim(),
      thumbnailUrl: _thumbnailUrl.text.trim(),
      description: _description.text.trim(),
      equipment: _equipment.text.trim(),
      tutorialSteps: _steps,
    );
    setState(() {
      _saving = true;
      _saveError = null;
      _videoProgress = null;
    });
    try {
      final repository = context.read<TutorialRepository>();
      if (_hasMediaUploads) {
        await (repository as TutorialMediaRepository).saveWithMedia(entry,
            cover: _selectedCover,
            video: _selectedVideo, onVideoProgress: (value) {
          if (mounted) setState(() => _videoProgress = value);
        });
      } else {
        await repository.save(entry);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _reloadRequired = error is TutorialEditConflict ||
              error is TutorialEditAuthorizationChanged ||
              _catalogOnly;
          _saveError = error is TutorialEditConflict
              ? const TutorialEditConflict().toString()
              : error is TutorialEditAuthorizationChanged
                  ? const TutorialEditAuthorizationChanged().toString()
                  : error is TutorialMediaUploadFailed
                      ? const TutorialMediaUploadFailed().toString()
                      : _catalogOnly
                          ? const TutorialCatalogSaveFailed().toString()
                          : 'Could not save exercise. Please try again.';
        });
      }
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    showToast(
        context,
        _catalogOnly
            ? (_isEdit ? 'Exercise updated.' : 'Exercise added to the catalog.')
            : (_isEdit
                ? 'Tutorial updated.'
                : 'Tutorial added to the library.'));
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: AbsorbPointer(
              absorbing: _busy,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PageBreadcrumb(crumbs: [
                      PageCrumb(
                          _catalogOnly
                              ? 'Exercise Catalog'
                              : 'Exercise Tutorials', () {
                        if (!_busy) widget.onDone();
                      }),
                      PageCrumb(_catalogOnly
                          ? (_isEdit ? 'Edit exercise' : 'Create exercise')
                          : (_isEdit ? 'Edit tutorial' : 'Create tutorial')),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                        _catalogOnly
                            ? (_isEdit ? 'Edit exercise' : 'Create exercise')
                            : (_isEdit ? 'Edit tutorial' : 'Create tutorial'),
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                        _catalogOnly
                            ? 'Exercises use stable catalog IDs in routine blueprints.'
                            : 'This appears in the member-facing tutorial library once published.',
                        style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 22),
                    LayoutBuilder(builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 900;
                      final form = _form(context);
                      final preview = _previewCard(context);
                      return wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: form),
                                const SizedBox(width: 20),
                                Expanded(flex: 2, child: preview),
                              ],
                            )
                          : Column(children: [
                              form,
                              const SizedBox(height: 20),
                              preview
                            ]);
                    }),
                  ],
                ),
              )),
        ));
  }

  Widget _form(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(_catalogOnly ? 'Exercise catalog entry' : 'Video details'),
          Panel(
            child: Column(
              children: [
                if (_catalogOnly && _isEdit) ...[
                  Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(
                          'Exercise ID: ${widget.existing!.id}')),
                  const SizedBox(height: 12),
                ],
                if (_catalogOnly) ...[
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                          widget.existing?.trackingCapability.hasPoseTracking ==
                                  true
                              ? Icons.auto_awesome_rounded
                              : Icons.menu_book_outlined,
                          color: AppColors.primary),
                      title: Text(
                          widget.existing?.trackingCapability.displayLabel ??
                              'Guided only'),
                      subtitle: Text(widget
                              .existing?.trackingCapability.description ??
                          'New exercises start with instructions and self-reported sets. AI tracking requires a registered exercise tracker.')),
                  const Text(
                      'Tracking availability is system-managed. Renaming an exercise or adding a video does not enable AI tracking.',
                      style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _title,
                  decoration:
                      const InputDecoration(labelText: 'Title', isDense: true),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Required';
                    if (_catalogOnly && value.length > 100) {
                      return 'Use 100 characters or fewer';
                    }
                    return null;
                  },
                ),
                if (!_catalogOnly) const SizedBox(height: 12),
                if (!_hasMediaUploads)
                  TextFormField(
                    controller: _videoUrl,
                    decoration: InputDecoration(
                        labelText:
                            _catalogOnly ? 'Video URL (optional)' : 'Video URL',
                        isDense: true),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty && !_catalogOnly) return 'Required';
                      if (_catalogOnly && value.length > 2048) {
                        return 'Use 2048 characters or fewer';
                      }
                      return null;
                    },
                  ),
                if (_hasMediaUploads)
                  ExerciseMediaFields(
                      cover: _selectedCover,
                      video: _selectedVideo,
                      hasSavedCover: _thumbnailUrl.text.trim().isNotEmpty,
                      hasSavedVideo: _videoUrl.text.trim().isNotEmpty,
                      saving: _saving,
                      progress: _videoProgress,
                      error: _mediaError,
                      onChooseCover: _chooseCover,
                      onChooseVideo: _chooseVideo,
                      onRemoveCover: () => setState(() {
                            _selectedCover = null;
                            _coverPreviewBytes = null;
                            _thumbnailUrl.clear();
                          }),
                      onRemoveVideo: () => setState(() {
                            _selectedVideo = null;
                            _videoUrl.clear();
                          })),
                if (_selectedVideo != null || _videoUrl.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ExerciseVideoPreview(
                      url: _videoUrl.text.trim(),
                      bytes: _selectedVideo?.bytes,
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _description,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                        labelText: 'Exercise overview', isDense: true)),
                const SizedBox(height: 12),
                if (!_hasMediaUploads)
                  TextFormField(
                    controller: _thumbnailUrl,
                    decoration: const InputDecoration(
                        labelText: 'Cover image URL (optional)',
                        helperText: 'HTTPS image or signed storage URL',
                        isDense: true),
                    validator: (v) => v == null ||
                            v.trim().isEmpty ||
                            exerciseImageUri(v) != null
                        ? null
                        : 'Use an HTTPS image URL',
                  ),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _equipment,
                    maxLength: 300,
                    decoration: const InputDecoration(
                        labelText: 'Equipment / setup notes', isDense: true)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Eyebrow('Classification'),
          Panel(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _category,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Category', isDense: true),
                        items: _categories
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _category = v ?? _category),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _difficulty,
                        decoration: const InputDecoration(
                            labelText: 'Difficulty', isDense: true),
                        items: _difficulties
                            .map((d) =>
                                DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _difficulty = v ?? _difficulty),
                      ),
                    ),
                  ],
                ),
                if (_catalogOnly) const SizedBox(height: 12),
                if (_catalogOnly)
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                        labelText: 'Status', isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'Active', child: Text('Active')),
                      DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                    ],
                    onChanged: (value) =>
                        setState(() => _status = value ?? _status),
                  ),
                if (!_catalogOnly) const SizedBox(height: 12),
                if (!_catalogOnly)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _duration,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Duration (minutes)', isDense: true),
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
                        child: DropdownButtonFormField<String>(
                          initialValue: _status,
                          decoration: const InputDecoration(
                              labelText: 'Status', isDense: true),
                          items: const [
                            DropdownMenuItem(
                                value: 'Active', child: Text('Active')),
                            DropdownMenuItem(
                                value: 'Draft', child: Text('Draft')),
                          ],
                          onChanged: (v) =>
                              setState(() => _status = v ?? _status),
                        ),
                      ),
                    ],
                  ),
                if (!_catalogOnly) const SizedBox(height: 12),
                if (!_catalogOnly)
                  DropdownButtonFormField<String?>(
                    initialValue: _coversExercise,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Covers exercise (optional)', isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ...context
                          .read<RecommendationRepository>()
                          .riskExercises
                          .map((e) =>
                              DropdownMenuItem(value: e[0], child: Text(e[0]))),
                    ],
                    onChanged: (v) => setState(() => _coversExercise = v),
                  ),
              ],
            ),
          ),
          if (_catalogOnly) ...[
            const SizedBox(height: 18),
            ExerciseTutorialStepsEditor(
                initialSteps: _steps,
                onChanged: (value) => setState(() => _steps = value)),
          ],
          const SizedBox(height: 22),
          if (_saveError != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_saveError!,
                    style: const TextStyle(color: AppColors.danger))),
          Row(
            children: [
              OutlinedButton(
                  onPressed: _busy ? null : widget.onDone,
                  child: const Text('Cancel')),
              const SizedBox(width: 10),
              FilledButton(
                  onPressed: _busy || _reloadRequired ? null : _save,
                  child: Text(_saving
                      ? 'Saving…'
                      : _catalogOnly
                          ? (_isEdit ? 'Save changes' : 'Create exercise')
                          : (_isEdit ? 'Save changes' : 'Create tutorial'))),
            ],
          ),
          if (_reloadRequired)
            TextButton(
                onPressed: widget.onDone,
                child: const Text('Discard edits and reload catalog')),
        ],
      ),
    );
  }

  Widget _previewCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(_catalogOnly ? 'Catalog preview' : 'Member preview'),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _selectedCover == null
                        ? _networkHero(_thumbnailUrl.text, fit: BoxFit.contain)
                        : Image.memory(_coverPreviewBytes!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image_outlined)))),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _title.text.isEmpty ? 'Untitled tutorial' : _title.text,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                        _catalogOnly
                            ? '$_category · $_difficulty · ${_steps.length} steps'
                            : '$_category  ·  $_difficulty  ·  ${_duration.text.isEmpty ? '0' : _duration.text} min',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: 12)),
                  ],
                ),
              ),
              if (_description.text.trim().isNotEmpty)
                Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Text(_description.text.trim())),
              for (var i = 0; i < _steps.length; i++)
                Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('${i + 1}. ${_steps[i].title}',
                              style: Theme.of(context).textTheme.titleSmall),
                          if (exerciseImageUri(_steps[i].imageUrl) != null)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: AspectRatio(
                                        aspectRatio: 16 / 9,
                                        child:
                                            _networkHero(_steps[i].imageUrl)))),
                          Text(_steps[i].description),
                        ])),
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
                  _catalogOnly
                      ? 'Active exercises can be added to routine templates. Save and publish the routine, then refresh it in the Member app to update the published snapshot.'
                      : 'Set status to Active to make this visible in the member tutorial library immediately.',
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
