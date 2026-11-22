import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// Presentation-only progress. The existing rest controller owns all timing.
class RestCountdownDial extends StatelessWidget {
  const RestCountdownDial(
      {super.key,
      required this.seconds,
      required this.totalSeconds,
      required this.running,
      this.diameter = 248});
  final int seconds, totalSeconds;
  final bool running;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final finalSeconds = running && seconds > 0 && seconds <= 3;
    final progress =
        totalSeconds <= 0 ? 0.0 : (seconds / totalSeconds).clamp(0.0, 1.0);
    final countdown = '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
    return Semantics(
        label: '$seconds seconds until the next exercise',
        value: '${(progress * 100).round()}% rest remaining',
        child: ExcludeSemantics(
            child: TweenAnimationBuilder<double>(
          key: ValueKey((finalSeconds ? seconds : 0, reduced)),
          tween: Tween(begin: 0, end: 1),
          duration: reduced ? Duration.zero : const Duration(milliseconds: 650),
          builder: (context, value, child) => Transform.scale(
              scale: finalSeconds && !reduced
                  ? 1 + .035 * (1 - (2 * value - 1).abs())
                  : 1,
              child: child),
          child: SizedBox(
              width: diameter,
              height: diameter,
              child: Stack(alignment: Alignment.center, children: [
                Positioned.fill(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              AppColors.primaryTint.withValues(alpha: .7),
                              Theme.of(context).colorScheme.surface,
                            ])))),
                Positioned.fill(
                    child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: TweenAnimationBuilder<double>(
                            tween: Tween(end: progress),
                            duration: reduced || !running
                                ? Duration.zero
                                : const Duration(milliseconds: 240),
                            builder: (context, value, _) =>
                                CircularProgressIndicator(
                                    value: value,
                                    strokeWidth: finalSeconds ? 9 : 7,
                                    strokeCap: StrokeCap.round,
                                    color: finalSeconds
                                        ? AppColors.primaryDark
                                        : AppColors.primary,
                                    backgroundColor: AppColors.primaryTint)))),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 23),
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                              running ? Icons.air_rounded : Icons.pause_rounded,
                              color: AppColors.primarySoft,
                              size: 25),
                          const SizedBox(height: 6),
                          Text(countdown,
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(
                                  fontSize: 60,
                                  height: 1.1,
                                  letterSpacing: -2,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                  fontWeight: FontWeight.w800,
                                  color: finalSeconds
                                      ? AppColors.primaryDark
                                      : AppColors.primary)),
                          const SizedBox(height: 8),
                          Text(
                              finalSeconds
                                  ? 'GET READY'
                                  : running
                                      ? 'REST & RECOVER'
                                      : 'PAUSED',
                              style: const TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1.5,
                                  color: AppColors.inkSoft,
                                  fontWeight: FontWeight.w700)),
                        ]))),
              ])),
        )));
  }
}
