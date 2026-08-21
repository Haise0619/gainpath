import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import '../admin_dialogs.dart';

/// AD-M11.4 — Manage Exercise Tutorial Library. An in-place content pane
/// selected from the sidebar's Content group — not a pushed route — so
/// there is no back arrow to return through; picking a different sidebar
/// item is how an admin leaves this section, the same as any website.
class ExerciseTutorialsScreen extends StatefulWidget {
  const ExerciseTutorialsScreen({super.key});

  @override
  State<ExerciseTutorialsScreen> createState() => _ExerciseTutorialsScreenState();
}

class _ExerciseTutorialsScreenState extends State<ExerciseTutorialsScreen> {
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
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
                  onPressed: () async {
                    final saved = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => const _TutorialFormDialog(),
                    );
                    if (saved == true) _refresh();
                  },
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                        ),
                        title: Text(t.title, style: Theme.of(context).textTheme.titleMedium),
                        subtitle: Text(
                            t.coversExercise.isEmpty ? t.category : '${t.category}  ·  covers ${t.coversExercise}',
                            style: Theme.of(context).textTheme.bodyMedium),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            statusPill(t.status),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () async {
                                final saved = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => _TutorialFormDialog(existing: t),
                                );
                                if (saved == true) _refresh();
                              },
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

class _TutorialFormDialog extends StatefulWidget {
  final TutorialVideo? existing;
  const _TutorialFormDialog({this.existing});

  @override
  State<_TutorialFormDialog> createState() => _TutorialFormDialogState();
}

class _TutorialFormDialogState extends State<_TutorialFormDialog> {
  static const _categories = [
    'Compound Lower-Body',
    'Compound Upper-Body',
    'Core',
    'Cardio',
    'Accessory',
  ];

  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late String _category = widget.existing?.category ?? _categories.first;
  late String _status = widget.existing?.status ?? 'Draft';
  late String? _coversExercise =
      widget.existing?.coversExercise.isEmpty ?? true ? null : widget.existing!.coversExercise;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isEdit) {
      widget.existing!
        ..title = _title.text.trim()
        ..category = _category
        ..status = _status
        ..coversExercise = _coversExercise ?? '';
    } else {
      MockData.tutorials.add(TutorialVideo(
        title: _title.text.trim(),
        category: _category,
        status: _status,
        coversExercise: _coversExercise ?? '',
      ));
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AdminDialog(
      width: 480,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isEdit ? 'Edit tutorial' : 'Add tutorial', style: Theme.of(context).textTheme.titleLarge),
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
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(onPressed: _save, child: Text(_isEdit ? 'Save changes' : 'Add tutorial')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
