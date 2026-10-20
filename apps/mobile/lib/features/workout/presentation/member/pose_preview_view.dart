import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/pose_preview_controller.dart';
import '../../../../infrastructure/pose/pose_joint_lag_diagnostics.dart';

/// Camera foundation mode of the existing Workout screen. No session metrics
/// or persistence are connected until exercise processing is implemented.
class PosePreviewView extends StatefulWidget {
  const PosePreviewView(
      {super.key, required this.controller, required this.viewport});
  final PosePreviewController controller;
  final Widget viewport;
  @override
  State<PosePreviewView> createState() => _PosePreviewViewState();
}

class _PosePreviewViewState extends State<PosePreviewView>
    with WidgetsBindingObserver {
  String _lagPhase = 'still';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.foreground());
    } else {
      unawaited(widget.controller.background());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.controller.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final paused = c.phase == PosePreviewPhase.paused;
        final tracking = c.phase == PosePreviewPhase.tracking;
        final status = c.errorMessage ??
            (paused
                ? 'Camera paused'
                : tracking
                    ? (c.diagnostics['previewAspectCompatible'] == false
                        ? 'Preview and camera frame sizes differ. Overlay needs device alignment verification.'
                        : c.frame?.landmarks.isNotEmpty == true
                            ? 'Pose detected'
                            : 'Move into view with your whole body visible')
                    : c.phase == PosePreviewPhase.closed
                        ? 'Preview closed'
                        : 'Opening camera and pose models…');
        return PopScope(
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) unawaited(c.close());
            },
            child: Scaffold(
                backgroundColor: AppColors.ink,
                body: SafeArea(
                    child: Column(children: [
                  Expanded(
                      child: Stack(fit: StackFit.expand, children: [
                    if (tracking)
                      widget.viewport
                    else
                      const ColoredBox(color: Colors.black),
                    const Positioned(
                        top: 16,
                        left: 16,
                        child: Chip(
                            label: Text(poseRefinedSkeletonDebugEnabled
                                ? 'Refined skeleton / filtered dots'
                                : 'Local camera preview'))),
                    Positioned(
                        left: 16,
                        right: 16,
                        bottom: 20,
                        child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(14)),
                            child: Text(status,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 15)))),
                  ])),
                  if (c.quality.blanks.enabled)
                    Text(
                        'F ${c.quality.sessionId.substring(c.quality.sessionId.length - 6)} '
                        '${c.quality.blanks.phase ?? "idle"} '
                        't=${(c.quality.clockMicros() / 1e6).toStringAsFixed(1)} '
                        'B${c.quality.blanks.latestEpisodeId ?? 0} '
                        '${c.quality.blanks.overlayBlank ? "blank" : "visible"} '
                        '${c.quality.blanks.latestReason ?? "none"}',
                        style:
                            const TextStyle(color: Colors.yellow, fontSize: 11),
                        textAlign: TextAlign.center),
                  if (c.quality.lag.enabled)
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      DropdownButton<String>(
                          value: _lagPhase,
                          dropdownColor: Colors.black,
                          style: const TextStyle(color: Colors.white),
                          items: [
                            for (final name in [
                              'still',
                              'slow',
                              'fast',
                              'bottomHold',
                              'topHold'
                            ])
                              DropdownMenuItem(value: name, child: Text(name))
                          ],
                          onChanged: (name) =>
                              setState(() => _lagPhase = name!)),
                      const SizedBox(width: 12),
                      FilledButton(
                          onPressed: tracking && c.quality.lag.phase == null
                              ? () => c.startLagPhase(_lagPhase)
                              : null,
                          child: Text(c.quality.lag.phase == null
                              ? 'Capture 20s'
                              : '${c.quality.lag.phase}: ${c.quality.lag.remainingSeconds.ceil()}s')),
                    ]),
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Expanded(
                            child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white),
                                onPressed:
                                    c.phase == PosePreviewPhase.opening ||
                                            c.phase == PosePreviewPhase.closed
                                        ? null
                                        : () => unawaited(
                                            tracking ? c.pause() : c.resume()),
                                child: Text(paused
                                    ? 'Resume'
                                    : tracking
                                        ? 'Pause'
                                        : 'Retry'))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.danger),
                                onPressed: () async {
                                  await c.close();
                                  if (context.mounted) Navigator.pop(context);
                                },
                                child: const Text('End preview'))),
                      ])),
                ]))));
      });
}
