import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// A preview is informational: only the foreground membership actions are live.
class LockedRewardsPreview extends StatelessWidget {
  const LockedRewardsPreview(
      {super.key,
      this.sectionTitle,
      required this.title,
      required this.description,
      required this.previewLabel,
      required this.onViewPlans,
      required this.child,
      this.onBrowse});
  final String? sectionTitle;
  final String title, description, previewLabel;
  final Future<void> Function() onViewPlans;
  final VoidCallback? onBrowse;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final overlay = Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.hairline),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: .07),
                  blurRadius: 18,
                  offset: const Offset(0, 5))
            ]),
        child: Column(children: [
          Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                  color: AppColors.accentTint, shape: BoxShape.circle),
              child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                      color: AppColors.accent, shape: BoxShape.circle),
                  child: const Icon(Icons.lock_outline_rounded,
                      color: AppColors.primaryDark, size: 24))),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.inkSoft, fontSize: 14, height: 1.45)),
          const SizedBox(height: 16),
          SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: onViewPlans,
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 50),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: const Text('View membership plans',
                      textAlign: TextAlign.center))),
          if (onBrowse != null)
            TextButton(
                onPressed: onBrowse,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child:
                    const Text('Browse rewards', textAlign: TextAlign.center)),
        ]));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (sectionTitle case final heading?) ...[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 4,
              height: 19,
              margin: const EdgeInsets.only(top: 3, right: 9),
              decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(4))),
          Expanded(
              child: Text(heading,
                  style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 19,
                      height: 1.25,
                      fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 12),
      ],
      DecoratedBox(
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryTint, AppColors.bg]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.hairline)),
          child: Column(children: [
            Semantics(
                label: previewLabel,
                child: IgnorePointer(
                    key: const ValueKey('locked-preview-content'),
                    child: ExcludeFocus(
                        child: ExcludeSemantics(
                            child: Opacity(
                                opacity: .78,
                                child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 12, 12, 30),
                                    child: child)))))),
            // The foreground overlaps the preview surface without fixing its height.
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Transform.translate(
                    offset: const Offset(0, -18),
                    child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 240),
                        child: overlay,
                        builder: (context, value, child) => Opacity(
                            opacity: value,
                            child: Transform.translate(
                                offset: Offset(0, (1 - value) * 6),
                                child: child))))),
          ])),
    ]);
  }
}
