import 'package:flutter/material.dart';
import 'package:gainpath/app/theme/theme.dart';

/// SD-M2.3 — Recalibrate Camera Position. Replaces the live tracking
/// display while confidence is below 70%: repetition counting suspends and
/// a pulsing alignment guide prompts the member to adjust, re-evaluating
/// every tick until it clears (auto-resume) or degrades further (auto-pause
/// escalation, handled by the parent screen).
class RecalibrationOverlay extends StatefulWidget {
  final double confidence;
  const RecalibrationOverlay({required this.confidence});

  @override
  State<RecalibrationOverlay> createState() => _RecalibrationOverlayState();
}

class _RecalibrationOverlayState extends State<RecalibrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final critical = widget.confidence < 50;
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final scale = 1.0 + (_pulse.value * 0.05);
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 96,
                height: 176,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: critical ? AppColors.danger : AppColors.overlay,
                    width: 2.4,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.accessibility_new_rounded,
                    color: critical ? AppColors.danger : AppColors.overlay, size: 56),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              critical ? 'Tracking lost' : 'Realigning…',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              critical
                  ? 'Step back into frame and hold still.'
                  : 'Step back so your whole body is in view.',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('${widget.confidence.round()}% confidence',
                  style: TextStyle(
                    color: critical ? AppColors.danger : AppColors.overlay,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws a simplified animated stick figure to stand in for the real
/// BlazePose landmark overlay. Reused as both the live tracking overlay
/// and the "playing" state of the simulated tutorial video, since both
/// are meant to depict the same generic squat-pattern motion.
