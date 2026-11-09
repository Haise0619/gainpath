import 'package:flutter/material.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class RoutineCoverField extends StatelessWidget {
  const RoutineCoverField(
      {super.key,
      required this.cover,
      required this.savedUrl,
      required this.onChoose,
      required this.onRemove,
      this.busy = false,
      this.error});
  final EquipmentImage? cover;
  final String savedUrl;
  final VoidCallback? onChoose;
  final VoidCallback onRemove;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final hasCover = cover != null || savedUrl.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Eyebrow('Cover image'),
      Text(cover != null
          ? 'New cover selected · ${(cover!.bytes.length / 1024).ceil()} KB'
          : hasCover
              ? 'Saved cover image'
              : 'No cover image selected'),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
            onPressed: busy ? null : onChoose,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label:
                Text(hasCover ? 'Replace cover image' : 'Choose cover image')),
        if (hasCover)
          TextButton(
              onPressed: busy ? null : onRemove,
              child: const Text('Remove cover')),
      ]),
      const Text('JPG, PNG or WebP · up to 5 MB. Uploads when you save.',
          style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
      if (busy) ...[
        const SizedBox(height: 8),
        const LinearProgressIndicator(),
        const Text('Preparing cover and saving routine…')
      ],
      if (error != null)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child:
                Text(error!, style: const TextStyle(color: AppColors.danger))),
    ]);
  }
}
