import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// AD-M11.4 — Manage Exercise Tutorial Library. An in-place content pane
/// selected from the sidebar's Content group — not a pushed route — so
/// there is no back arrow to return through; picking a different sidebar
/// item is how an admin leaves this section, the same as any website.
class ExerciseTutorialsScreen extends StatelessWidget {
  const ExerciseTutorialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final active = MockData.tutorials.where((t) => t[2] == 'Active').length;
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
                  onPressed: () => showToast(context, 'Opening the tutorial uploader.'),
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
                        title: Text(t[0], style: Theme.of(context).textTheme.titleMedium),
                        subtitle: Text(t[1], style: Theme.of(context).textTheme.bodyMedium),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            statusPill(t[2]),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => showToast(context, 'Edit ${t[0]}.'),
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
