import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import '../admin_breadcrumb.dart';

/// Defensive network image loader — a broken/slow link never breaks the
/// layout, same pattern used across the member-facing modules.
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

/// AD-M11.4 — Manage Exercise Tutorial Library. An in-place content pane
/// selected from the sidebar's Content group — not a pushed route — so
/// there is no back arrow to return through. Add/Edit is a full-page
/// form (not a dialog): there's real content to fill in here — video
/// URL, thumbnail, duration, difficulty — enough that a compact popup
/// was cramping it, so it gets its own page with a local breadcrumb
/// instead, the way an AWS Console "Create" flow does.
class ExerciseTutorialsScreen extends StatefulWidget {
  const ExerciseTutorialsScreen({super.key});

  @override
  State<ExerciseTutorialsScreen> createState() => _ExerciseTutorialsScreenState();
}

class _ExerciseTutorialsScreenState extends State<ExerciseTutorialsScreen> {
  TutorialVideo? _editing;
  bool _creating = false;

  void _openCreate() => setState(() => _creating = true);
  void _openEdit(TutorialVideo t) => setState(() => _editing = t);
  void _closeForm() => setState(() {
        _creating = false;
        _editing = null;
      });

  @override
  Widget build(BuildContext context) {
    if (_creating || _editing != null) {
      return _TutorialFormPage(existing: _editing, onDone: _closeForm);
    }

    final active = MockData.tutorials.where((t) => t.status == 'Active').length;
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
                  child: Text('$active of ${MockData.tutorials.length} tutorials are live to members.',
                      style: Theme.of(context).textTheme.bodyLarge),
                ),
                FilledButton.icon(
                  onPressed: _openCreate,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add tutorial'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: List.generate(MockData.tutorials.length, (i) {
                  final t = MockData.tutorials[i];
                  return Column(
                    children: [
                      if (i > 0) const Divider(height: 1, indent: 74),
                      ListTile(
                        onTap: () => _openEdit(t),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: t.thumbnailUrl.isEmpty
                                ? Container(
                                    color: AppColors.ink,
                                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                                  )
                                : _networkHero(t.thumbnailUrl),
                          ),
                        ),
                        title: Text(t.title, style: Theme.of(context).textTheme.titleMedium),
                        subtitle: Text(
                            '${t.category}  ·  ${t.durationMin} min'
                            '${t.coversExercise.isEmpty ? '' : '  ·  covers ${t.coversExercise}'}',
                            style: Theme.of(context).textTheme.bodyMedium),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            statusPill(t.status),
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
  late final _title = TextEditingController(text: widget.existing?.title ?? '')..addListener(_repaint);
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late final _videoUrl = TextEditingController(text: widget.existing?.videoUrl ?? '');
  late final _thumbnailUrl = TextEditingController(text: widget.existing?.thumbnailUrl ?? '')
    ..addListener(_repaint);
  late final _duration = TextEditingController(text: '${widget.existing?.durationMin ?? 5}');
  late String _category = widget.existing?.category ?? _categories.first;
  late String _difficulty = widget.existing?.difficulty ?? _difficulties.first;
  late String _status = widget.existing?.status ?? 'Draft';
  late String? _coversExercise =
      widget.existing?.coversExercise.isEmpty ?? true ? null : widget.existing!.coversExercise;

  bool get _isEdit => widget.existing != null;

  void _repaint() => setState(() {});

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _videoUrl.dispose();
    _thumbnailUrl.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final duration = int.tryParse(_duration.text.trim()) ?? 5;
    if (_isEdit) {
      widget.existing!
        ..title = _title.text.trim()
        ..category = _category
        ..status = _status
        ..coversExercise = _coversExercise ?? ''
        ..difficulty = _difficulty
        ..durationMin = duration
        ..videoUrl = _videoUrl.text.trim()
        ..thumbnailUrl = _thumbnailUrl.text.trim()
        ..description = _description.text.trim();
    } else {
      MockData.tutorials.add(TutorialVideo(
        title: _title.text.trim(),
        category: _category,
        status: _status,
        coversExercise: _coversExercise ?? '',
        difficulty: _difficulty,
        durationMin: duration,
        videoUrl: _videoUrl.text.trim(),
        thumbnailUrl: _thumbnailUrl.text.trim(),
        description: _description.text.trim(),
      ));
    }
    showToast(context, _isEdit ? 'Tutorial updated.' : 'Tutorial added to the library.');
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
              PageCrumb('Exercise Tutorials', widget.onDone),
              PageCrumb(_isEdit ? 'Edit tutorial' : 'Create tutorial'),
            ]),
            const SizedBox(height: 6),
            Text(_isEdit ? 'Edit tutorial' : 'Create tutorial', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('This appears in the member-facing tutorial library once published.',
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
          const Eyebrow('Video details'),
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
                  controller: _videoUrl,
                  decoration: const InputDecoration(labelText: 'Video URL', isDense: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _thumbnailUrl,
                  decoration: const InputDecoration(labelText: 'Thumbnail image URL', isDense: true),
                ),
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
                        decoration: const InputDecoration(labelText: 'Category', isDense: true),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => _category = v ?? _category),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _difficulty,
                        decoration: const InputDecoration(labelText: 'Difficulty', isDense: true),
                        items: _difficulties.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                        onChanged: (v) => setState(() => _difficulty = v ?? _difficulty),
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
                        controller: _duration,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Duration (minutes)', isDense: true),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          return (n == null || n <= 0) ? 'Whole number > 0' : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'Status', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'Active', child: Text('Active')),
                          DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                        ],
                        onChanged: (v) => setState(() => _status = v ?? _status),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _coversExercise,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Covers exercise (optional)', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...MockData.riskExercises.map((e) => DropdownMenuItem(value: e[0], child: Text(e[0]))),
                  ],
                  onChanged: (v) => setState(() => _coversExercise = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              OutlinedButton(onPressed: widget.onDone, child: const Text('Cancel')),
              const SizedBox(width: 10),
              FilledButton(onPressed: _save, child: Text(_isEdit ? 'Save changes' : 'Create tutorial')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewCard(BuildContext context) {
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
                child: AspectRatio(aspectRatio: 16 / 9, child: _networkHero(_thumbnailUrl.text)),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_title.text.isEmpty ? 'Untitled tutorial' : _title.text,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('$_category  ·  $_difficulty  ·  ${_duration.text.isEmpty ? '0' : _duration.text} min',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
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
                  'Set status to Active to make this visible in the member tutorial library immediately.',
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
