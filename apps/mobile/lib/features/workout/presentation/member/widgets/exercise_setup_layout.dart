import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// Presentation only: each exercise retains its own choices and start guard.
class SetupViewBanner extends StatelessWidget {
  const SetupViewBanner({super.key, required this.frontView});
  final bool frontView;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Panel(
          background: AppColors.primaryTint,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.videocam_outlined, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      frontView
                          ? 'Front camera view required'
                          : 'Side camera view required',
                      style: MediaQuery.textScalerOf(context).scale(14) > 21
                          ? Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700)
                          : Theme.of(context).textTheme.titleMedium),
                  if (MediaQuery.textScalerOf(context).scale(14) <= 21) ...[
                    const SizedBox(height: 4),
                    Text(frontView
                        ? 'Face the camera. Follow the positioning check below.'
                        : 'Turn side-on. Follow the selected arm or leg instructions below.'),
                  ],
                ])),
          ])));
}

class SetupActionBar extends StatelessWidget {
  const SetupActionBar({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: child),
              ])));
}
