import 'package:flutter/material.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../application/guided_workout_progress.dart';
import '../../../application/measured_workout_session.dart';
import '../../../application/pose_preview_controller.dart';

/// Observes accepted display snapshots only. Never drives capture or counting.
class WorkoutTrackingFeedback extends StatefulWidget {
  const WorkoutTrackingFeedback(
      {super.key, required this.session, this.alignment = Alignment.center});
  final MeasuredWorkoutSession session;
  final Alignment alignment;
  @override
  State<WorkoutTrackingFeedback> createState() =>
      _WorkoutTrackingFeedbackState();
}

class _WorkoutTrackingFeedbackState extends State<WorkoutTrackingFeedback>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _label = null);
      }
    });
  int? _previousReps;
  (int, String)? _readyToken;
  bool _wasWorking = false, _wasHealthy = false, _foreground = true;
  String? _label;
  bool _isRep = false;
  bool _boundaryRep = false;

  @override
  void initState() {
    super.initState();
    _previousReps = widget.session.analysis?.repetitions;
    widget.session.addListener(_observe);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _observe();
  }

  @override
  void didUpdateWidget(covariant WorkoutTrackingFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      oldWidget.session.removeListener(_observe);
      _dismiss();
      _previousReps = widget.session.analysis?.repetitions;
      _readyToken = null;
      _wasWorking = _wasHealthy = false;
      widget.session.addListener(_observe);
      _observe();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _wasWorking = _wasHealthy = false;
      _dismiss();
    }
  }

  void _dismiss() {
    _motion.stop();
    _boundaryRep = false;
    if (_label != null) setState(() => _label = null);
  }

  void _present(String label, {required bool rep}) {
    if (!rep) _boundaryRep = false;
    setState(() {
      _label = label;
      _isRep = rep;
    });
    _motion.duration = Duration(milliseconds: rep ? 760 : 900);
    _motion.forward(from: 0);
  }

  void _observe() {
    final c = widget.session;
    final analysis = c.analysis;
    final previous = _previousReps;
    _previousReps = analysis?.repetitions ?? previous;
    final working =
        c.guidance == null || c.guidance!.stage == GuidedWorkoutStage.working;
    final switching = c is UnilateralWorkoutSession &&
        (c as UnilateralWorkoutSession).awaitingArmSwitch;
    final validSession = _foreground &&
        c.viewPhase == MeasuredWorkoutPhase.active &&
        c.preview.phase == PosePreviewPhase.tracking &&
        !c.isManuallyPaused &&
        !c.isRecalibrating &&
        analysis != null;
    final validSnapshot = validSession &&
        !analysis.needsCalibration &&
        analysis.health == TrackingStatus.healthy;
    final automaticBoundary = !working || switching;
    final healthy = validSnapshot &&
        c.analysisAvailable &&
        !c.isPaused &&
        !automaticBoundary;
    // Automatic rest can synchronously clear live-analysis availability after
    // accepting the final rep, and analyzer-owned sessions also invalidate
    // calibration. A new accepted count at that boundary is independent of
    // readiness for the next rep; never treat it as healthy live tracking.
    final counted = validSession &&
        analysis.health != TrackingStatus.lost &&
        (healthy || automaticBoundary) &&
        _wasHealthy &&
        _wasWorking &&
        previous != null &&
        analysis.repetitions > previous;
    _wasWorking = working && !switching;
    _wasHealthy = healthy;
    if (counted) {
      _boundaryRep = automaticBoundary;
      final count = c is UnilateralWorkoutSession
          ? (c as UnilateralWorkoutSession)
              .armRepetitionLabel
              .split(' / ')
              .first
          : '${c.guidance?.setRepetitions ?? analysis.repetitions}';
      _present(count, rep: true);
      return;
    }
    if (!healthy) {
      if (!(validSession &&
          automaticBoundary &&
          _boundaryRep &&
          analysis.health != TrackingStatus.lost &&
          _label != null)) {
        _dismiss();
      }
      return;
    }
    final token = (
      c.guidance?.currentSet ?? 1,
      c is UnilateralWorkoutSession
          ? (c as UnilateralWorkoutSession).armLabel
          : ''
    );
    if (_readyToken != token) {
      _readyToken = token;
      _present('Ready', rep: false);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_observe);
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = _label;
    if (label == null) return const SizedBox.shrink();
    final reduced = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
        child: RepaintBoundary(
            child: Align(
      alignment: widget.alignment,
      child: Semantics(
        liveRegion: true,
        label: _isRep ? 'Rep $label counted' : 'Tracking ready',
        child: ExcludeSemantics(
            child: AnimatedBuilder(
          animation: _motion,
          builder: (context, child) {
            final t = _motion.value;
            final opacity = reduced
                ? 1.0
                : t < .12
                    ? t / .12
                    : t > .55
                        ? (1 - t) / .45
                        : 1.0;
            final scale = reduced
                ? 1.0
                : .78 +
                    .22 *
                        Curves.easeOutBack.transform((t / .38).clamp(0.0, 1.0));
            return Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(scale: scale, child: child));
          },
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(label,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                            fontSize: _isRep ? 112 : 76,
                            height: 1,
                            letterSpacing: -3,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: Colors.white,
                            shadows: const [
                              Shadow(
                                  color: AppColors.primaryDark, blurRadius: 18),
                              Shadow(
                                  color: Colors.black87,
                                  blurRadius: 4,
                                  offset: Offset(0, 2))
                            ])),
                    const SizedBox(height: 12),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: AppColors.primarySoft)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                              _isRep
                                  ? Icons.check_circle_rounded
                                  : Icons.sensors_rounded,
                              color: AppColors.overlay,
                              size: 18),
                          const SizedBox(width: 7),
                          Text(_isRep ? 'Rep Counted' : 'Tracking Ready',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ])),
                  ]))),
        )),
      ),
    )));
  }
}
