import 'package:flutter/material.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class ExerciseTutorialImage extends StatelessWidget {
  const ExerciseTutorialImage(
      {super.key,
      required this.url,
      required this.label,
      this.isCover = false});
  final String url, label;
  final bool isCover;
  @override
  Widget build(BuildContext context) {
    Widget placeholder(String message) => ColoredBox(
        color: AppColors.surfaceAlt,
        child: Center(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.image_outlined, color: AppColors.inkSoft),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                ]))));
    return Semantics(
        label: label,
        image: true,
        child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
                aspectRatio: isCover ? 16 / 9 : 4 / 3,
                child: exerciseImageUri(url) == null
                    ? placeholder('Image unavailable')
                    : Image.network(url,
                        fit: isCover ? BoxFit.cover : BoxFit.contain,
                        excludeFromSemantics: true,
                        cacheWidth: 1000,
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : placeholder('Loading image…'),
                        errorBuilder: (_, __, ___) =>
                            placeholder('Image unavailable')))));
  }
}
