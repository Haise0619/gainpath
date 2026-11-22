import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class CompletionChip extends StatelessWidget {
  const CompletionChip(this.label,
      {super.key, required this.color, required this.background, this.icon});
  final String label;
  final Color color, background;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5)
        ],
        Flexible(
            child: Text(label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 12,
                    height: 1.2,
                    color: color,
                    fontWeight: FontWeight.w700))),
      ]));
}

class CompletionStatGrid extends StatelessWidget {
  const CompletionStatGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = bounds.maxWidth / scale < 230
            ? 1
            : bounds.maxWidth > 700
                ? 4
                : 2;
        final width = (bounds.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: children
                .map((child) => SizedBox(width: width, child: child))
                .toList());
      });
}

class WorkoutCompletionHero extends StatelessWidget {
  const WorkoutCompletionHero(
      {super.key,
      required this.title,
      required this.status,
      required this.detail,
      required this.complete});
  final String title, status, detail;
  final bool complete;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CompletionChip(status,
          color: complete ? const Color(0xFF166534) : AppColors.primaryDark,
          background: complete ? AppColors.successTint : AppColors.primaryTint,
          icon: complete
              ? Icons.check_circle_rounded
              : Icons.fitness_center_rounded),
      const SizedBox(height: 16),
      Text(title,
          style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 30,
              height: 1.1,
              color: AppColors.ink,
              fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      Text(detail,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: AppColors.inkSoft, height: 1.5)),
      if (complete) ...[
        const SizedBox(height: 14),
        Text('A strong finish. Well done.',
            style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
      ],
    ]);
    return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.hairline),
            gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryTint, AppColors.bg])),
        child: LayoutBuilder(builder: (context, bounds) {
          final stacked = bounds.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(14) > 21;
          final medal = ExcludeSemantics(
              child: SizedBox(
                  width: 86,
                  height: 102,
                  child: Stack(alignment: Alignment.center, children: [
                    if (complete)
                      Positioned(
                          bottom: 0,
                          child: Icon(Icons.bookmark_rounded,
                              color: AppColors.primarySoft, size: 58)),
                    Positioned(
                        top: 6,
                        child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: complete
                                    ? AppColors.accentTint
                                    : AppColors.primaryTint,
                                border: Border.all(
                                    color: complete
                                        ? AppColors.accent
                                            .withValues(alpha: .45)
                                        : AppColors.hairline,
                                    width: 3)),
                            child: Icon(
                                complete
                                    ? Icons.workspace_premium_rounded
                                    : Icons.fitness_center_rounded,
                                size: 43,
                                color: complete
                                    ? AppColors.accentDark
                                    : AppColors.primary))),
                    if (complete)
                      const Positioned(
                          right: 0,
                          bottom: 19,
                          child: Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 27)),
                    if (complete)
                      const Positioned(
                          left: 0,
                          top: 0,
                          child: Icon(Icons.auto_awesome,
                              color: AppColors.accentDark, size: 17)),
                  ])));
          return stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [medal, const SizedBox(height: 12), copy])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: copy),
                  const SizedBox(width: 12),
                  medal
                ]);
        }));
  }
}
