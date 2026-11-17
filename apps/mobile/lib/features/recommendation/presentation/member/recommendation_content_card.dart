import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

String recommendationActionLabel(RecommendationKind kind) => switch (kind) {
      RecommendationKind.routine => 'Preview Routine',
      RecommendationKind.trainer => 'View Coach',
      RecommendationKind.content => 'Watch Tutorial',
    };

String recommendationTypeLabel(RecommendationKind kind) => switch (kind) {
      RecommendationKind.routine => 'Routine',
      RecommendationKind.trainer => 'Coach guidance',
      RecommendationKind.content => 'Exercise tutorial',
    };

class RecommendationContentCard extends StatelessWidget {
  const RecommendationContentCard(
      {super.key,
      required this.kind,
      required this.title,
      required this.reason,
      required this.onOpen,
      this.onDetails,
      this.onDismiss,
      this.imageUrl,
      this.photo,
      this.difficulty,
      this.durationMinutes,
      this.exerciseCount,
      this.specialization,
      this.branchLabel,
      this.priceMinor,
      this.currency,
      this.newRecommendation = false,
      this.general = false,
      this.available = true,
      this.busy = false});
  final RecommendationKind kind;
  final String title, reason;
  final String? imageUrl, difficulty, specialization, branchLabel, currency;
  final int? durationMinutes, exerciseCount, priceMinor;
  final Widget? photo;
  final VoidCallback onOpen;
  final VoidCallback? onDetails, onDismiss;
  final bool newRecommendation, general, available, busy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final coach = kind == RecommendationKind.trainer;
    final uri = Uri.tryParse(imageUrl ?? '');
    final validImage = available &&
        uri?.scheme == 'https' &&
        uri!.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasFragment;
    final fallback = Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [AppColors.primaryTint, AppColors.surfaceAlt],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)),
        alignment: Alignment.center,
        child: Icon(
            coach
                ? Icons.person_outline_rounded
                : kind == RecommendationKind.routine
                    ? Icons.fitness_center_rounded
                    : Icons.play_circle_outline_rounded,
            size: 48,
            color: AppColors.primary));
    final metadata = <String>[
      if (difficulty != null) difficulty!,
      if (durationMinutes != null) '$durationMinutes min',
      if (exerciseCount != null) '$exerciseCount exercises',
    ];
    return Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.hairline)),
        clipBehavior: Clip.antiAlias,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
              onTap: busy ? null : onDetails ?? onOpen,
              child: SizedBox(
                  height: coach ? 156 : 164,
                  child: Stack(fit: StackFit.expand, children: [
                    photo ??
                        (validImage
                            ? Image.network(uri.toString(),
                                fit: BoxFit.cover,
                                excludeFromSemantics: true,
                                errorBuilder: (_, __, ___) => fallback)
                            : fallback),
                    Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Wrap(spacing: 8, runSpacing: 8, children: [
                          _pill(recommendationTypeLabel(kind)),
                          if (newRecommendation) _pill('New recommendation'),
                          if (general) _pill('General discovery'),
                        ])),
                  ]))),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                        onTap: busy ? null : onDetails ?? onOpen,
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(title,
                                style: text.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800)))),
                    if (metadata.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: metadata
                              .map((value) => Text(value,
                                  style: text.labelLarge
                                      ?.copyWith(color: AppColors.primary)))
                              .toList()),
                    ],
                    if (specialization != null) ...[
                      const SizedBox(height: 8),
                      Text(specialization!, style: text.bodyMedium)
                    ],
                    if (branchLabel != null) ...[
                      const SizedBox(height: 8),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ExcludeSemantics(
                                child: Icon(Icons.location_on_outlined,
                                    size: 20, color: AppColors.primary)),
                            const SizedBox(width: 6),
                            Expanded(
                                child:
                                    Text(branchLabel!, style: text.bodyMedium)),
                          ])
                    ],
                    if (priceMinor != null && currency != null) ...[
                      const SizedBox(height: 8),
                      Text(
                          '$currency ${(priceMinor! / 100).toStringAsFixed(2)}',
                          style: text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700))
                    ],
                    const SizedBox(height: 12),
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(14)),
                        child: Text(reason, style: text.bodyMedium)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                        onPressed: busy ? null : onOpen,
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48)),
                        icon: Icon(coach
                            ? Icons.person_search_rounded
                            : kind == RecommendationKind.routine
                                ? Icons.fitness_center_rounded
                                : Icons.play_arrow_rounded),
                        label: Text(
                            available
                                ? recommendationActionLabel(kind)
                                : 'View details',
                            textAlign: TextAlign.center)),
                    if (onDetails != null || onDismiss != null)
                      Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 8,
                          children: [
                            if (onDetails != null)
                              TextButton(
                                  onPressed: busy ? null : onDetails,
                                  child:
                                      const Text('Why this recommendation?')),
                            if (onDismiss != null)
                              TextButton(
                                  onPressed: busy ? null : onDismiss,
                                  child: const Text('Dismiss')),
                          ]),
                  ])),
        ]));
  }

  Widget _pill(String label) => DecoratedBox(
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w700))));
}
