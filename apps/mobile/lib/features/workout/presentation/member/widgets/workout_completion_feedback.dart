import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// A short presentation over frozen results. Never drives analysis or saving.
class WorkoutCompletionFeedback extends StatelessWidget {
  const WorkoutCompletionFeedback(
      {super.key, required this.exerciseName, required this.workoutComplete});
  final String exerciseName;
  final bool workoutComplete;
  static const minimumPresentation = Duration(milliseconds: 1600);

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return BlockSemantics(
        child: Semantics(
            liveRegion: true,
            container: true,
            label: workoutComplete ? 'Workout complete' : 'Exercise complete',
            child: AbsorbPointer(
                child: DecoratedBox(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.ink, AppColors.primaryDark])),
              child: SafeArea(child: LayoutBuilder(builder: (context, bounds) {
                final wide = bounds.maxWidth >= 600 &&
                    bounds.maxWidth > bounds.maxHeight;
                return Center(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 32),
                        child: ConstrainedBox(
                            constraints:
                                BoxConstraints(maxWidth: wide ? 720 : 440),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 1100),
                              builder: (context, progress, _) {
                                final badge = Transform.scale(
                                    scale: reduceMotion
                                        ? 1
                                        : .82 +
                                            .18 *
                                                Curves.easeOutBack
                                                    .transform(progress),
                                    child: SizedBox(
                                        width: wide ? 144 : 172,
                                        height: wide ? 144 : 172,
                                        child: CustomPaint(
                                            painter: _CompletionSeal(progress),
                                            child: Center(
                                                child: Opacity(
                                                    opacity:
                                                        progress.clamp(0, 1),
                                                    child: const Icon(
                                                        Icons.check_rounded,
                                                        size: 82,
                                                        color: AppColors
                                                            .successTint))))));
                                final copy = Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Opacity(
                                          opacity: (progress * 2).clamp(0, 1),
                                          child: Text(
                                              workoutComplete
                                                  ? 'Workout complete!'
                                                  : 'Exercise complete!',
                                              textAlign: TextAlign.center,
                                              style: (Theme.of(context)
                                                          .textTheme
                                                          .headlineMedium ??
                                                      const TextStyle())
                                                  .copyWith(
                                                      fontSize: 36,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      height: 1.12))),
                                      const SizedBox(height: 14),
                                      Text(exerciseName,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                  color:
                                                      AppColors.primaryTint)),
                                      const SizedBox(height: 24),
                                      Text('Great effort. Take a breath.',
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                  color: Colors.white,
                                                  height: 1.5)),
                                    ]);
                                return wide
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                            badge,
                                            const SizedBox(width: 32),
                                            Expanded(child: copy)
                                          ])
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                            badge,
                                            const SizedBox(height: 28),
                                            copy
                                          ]);
                              },
                            ))));
              })),
            ))));
  }
}

class _CompletionSeal extends CustomPainter {
  const _CompletionSeal(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 8;
    canvas.drawCircle(center, radius - 12, Paint()..color = AppColors.primary);
    final ring = Paint()
      ..color = AppColors.successTint
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * Curves.easeOutCubic.transform(progress),
        false,
        ring);
    for (var i = 0; i < 4; i++) {
      final angle = math.pi / 4 + i * math.pi / 2;
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius - 3);
      canvas.drawCircle(
          point, 3 * progress, Paint()..color = AppColors.primaryTint);
    }
  }

  @override
  bool shouldRepaint(_CompletionSeal oldDelegate) =>
      oldDelegate.progress != progress;
}
