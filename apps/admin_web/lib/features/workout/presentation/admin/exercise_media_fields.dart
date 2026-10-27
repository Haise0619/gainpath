import 'package:flutter/material.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class ExerciseMediaFields extends StatelessWidget {
  const ExerciseMediaFields(
      {super.key,
      required this.cover,
      required this.video,
      required this.hasSavedCover,
      required this.hasSavedVideo,
      required this.onChooseCover,
      required this.onChooseVideo,
      required this.onRemoveCover,
      required this.onRemoveVideo,
      this.error,
      this.saving = false,
      this.progress});
  final EquipmentImage? cover;
  final EquipmentVideo? video;
  final bool hasSavedCover, hasSavedVideo, saving;
  final VoidCallback onChooseCover, onChooseVideo, onRemoveCover, onRemoveVideo;
  final String? error;
  final double? progress;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 16),
        const Eyebrow('Cover image'),
        Text(cover != null
            ? 'New cover selected · ${(cover!.bytes.length / 1024).ceil()} KB'
            : hasSavedCover
                ? 'Saved cover image'
                : 'No cover image selected'),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                  onPressed: saving ? null : onChooseCover,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(cover != null || hasSavedCover
                      ? 'Replace cover image'
                      : 'Choose cover image')),
              if (cover != null || hasSavedCover)
                TextButton(
                    onPressed: saving ? null : onRemoveCover,
                    child: const Text('Remove cover')),
            ]),
        const Text('JPG, PNG or WebP · up to 5 MB',
            style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
        const SizedBox(height: 20),
        const Eyebrow('Tutorial video'),
        Text(video != null
            ? 'New video selected · ${(video!.bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB'
            : hasSavedVideo
                ? 'Saved tutorial video'
                : 'No tutorial video selected'),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                  onPressed: saving ? null : onChooseVideo,
                  icon: const Icon(Icons.video_library_outlined),
                  label: Text(video != null || hasSavedVideo
                      ? 'Replace tutorial video'
                      : 'Choose tutorial video')),
              if (video != null || hasSavedVideo)
                TextButton(
                    onPressed: saving ? null : onRemoveVideo,
                    child: const Text('Remove video')),
            ]),
        const Text('MP4 · up to 100 MB. Files upload when you save.',
            style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
        if (saving) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 6),
          Text(progress == null
              ? 'Uploading media and saving exercise…'
              : 'Uploading video · ${(progress! * 100).round()}%'),
        ],
        if (error != null)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!,
                  style: const TextStyle(color: AppColors.danger))),
      ]);
}
