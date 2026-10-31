import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/gamification.dart';
import '../../application/reach_tap_controller.dart';
import '../../domain/reach_tap.dart';
import 'move_catch_result_panel.dart';

class ReachTapView extends StatelessWidget {
  const ReachTapView(
      {super.key,
      required this.controller,
      required this.viewport,
      this.content,
      this.onExit,
      this.onChangeMode,
      this.participationStatus,
      this.competitionStatus,
      this.competitionConsent,
      this.onLeaderboard});
  final ReachTapController controller;
  final Widget viewport;
  final MiniGameContent? content;
  MiniGameContent get _content =>
      content?.organizationId == controller.scope.organizationId &&
              content?.gameId == MiniGameContent.reachTapId
          ? content!
          : MiniGameContent.defaults(controller.scope.organizationId,
              gameId: MiniGameContent.reachTapId);
  final Future<void> Function()? onExit;
  final VoidCallback? onChangeMode;
  final Widget? participationStatus;
  final Widget? competitionStatus, competitionConsent;
  final VoidCallback? onLeaderboard;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller, e = c.engine;
        if (!c.current) {
          return const Scaffold(
              body: SafeArea(
                  child: Center(child: Text('This game session has ended.'))));
        }
        return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: AppBar(
                title: const Text('Reach & Tap'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                      tooltip: 'Back to games',
                      onPressed: onExit,
                      icon: const Icon(Icons.close))
                ]),
            body: SafeArea(
                child: !c.hasConsent
                    ? _consent(context)
                    : e.phase == ReachTapPhase.finished
                        ? _results(context)
                        : LayoutBuilder(
                            builder: (context, box) => SingleChildScrollView(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 8, 12, 20),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Wrap(
                                          alignment: WrapAlignment.spaceBetween,
                                          spacing: 12,
                                          runSpacing: 8,
                                          children: [
                                            _chip(Icons.stars_rounded,
                                                'Game Score ${e.score}'),
                                            _chip(Icons.timer_outlined,
                                                '${e.remainingSeconds.ceil()}s remaining')
                                          ]),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                          height: math.max(
                                              280, box.maxHeight - 210),
                                          child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                              child: Stack(
                                                  key: const ValueKey(
                                                      'reach-tap-board'),
                                                  fit: StackFit.expand,
                                                  children: [
                                                    viewport,
                                                    IgnorePointer(
                                                        child: CustomPaint(
                                                            painter:
                                                                ReachTapBoardPainter(
                                                                    engine:
                                                                        e))),
                                                    if (e.phase ==
                                                            ReachTapPhase
                                                                .playing &&
                                                        (e.leftHand == null ||
                                                            e.rightHand ==
                                                                null))
                                                      Positioned(
                                                        key: const ValueKey(
                                                            'reach-tap-hand-availability'),
                                                        left: 12,
                                                        right: 12,
                                                        bottom: 12,
                                                        child: IgnorePointer(
                                                            child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(10),
                                                          decoration: BoxDecoration(
                                                              color: Colors
                                                                  .black
                                                                  .withValues(
                                                                      alpha:
                                                                          .7),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          16)),
                                                          child: Text(
                                                              e.leftHand == null
                                                                  ? 'Right hand tracking · left hand not visible'
                                                                  : 'Left hand tracking · right hand not visible',
                                                              maxLines: 3,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .white)),
                                                        )),
                                                      ),
                                                    if (e.phase ==
                                                        ReachTapPhase
                                                            .recovering)
                                                      Positioned(
                                                        key: const ValueKey(
                                                            'reach-tap-recovery-overlay'),
                                                        left: 12,
                                                        right: 12,
                                                        bottom: 12,
                                                        child: IgnorePointer(
                                                            child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(12),
                                                          decoration: BoxDecoration(
                                                              color: Colors
                                                                  .black
                                                                  .withValues(
                                                                      alpha:
                                                                          .75),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          16)),
                                                          child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                const Text(
                                                                    'Tracking interrupted',
                                                                    maxLines: 2,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                    style: TextStyle(
                                                                        color: Colors
                                                                            .white,
                                                                        fontWeight:
                                                                            FontWeight.w700)),
                                                                const SizedBox(
                                                                    height: 6),
                                                                const Text(
                                                                    'Show your body and a hand to continue automatically',
                                                                    maxLines: 3,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                    style: TextStyle(
                                                                        color: Colors
                                                                            .white)),
                                                                const SizedBox(
                                                                    height: 8),
                                                                LinearProgressIndicator(
                                                                    value: e
                                                                        .recoveryProgress),
                                                              ]),
                                                        )),
                                                      ),
                                                    if (e.phase == ReachTapPhase.ready || e.phase == ReachTapPhase.countdown)
                                                      Center(
                                                          child: Container(
                                                              padding: const EdgeInsets.all(
                                                                  20),
                                                              decoration: BoxDecoration(
                                                                  color: Colors.black
                                                                      .withValues(
                                                                          alpha:
                                                                              .65),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                          20)),
                                                              child: Text(
                                                                  e.phase == ReachTapPhase.ready
                                                                      ? 'Ready'
                                                                      : '${e.countdownSeconds}',
                                                                  style: const TextStyle(
                                                                      fontSize: 48,
                                                                      fontWeight: FontWeight.w800,
                                                                      color: Colors.white)))),
                                                    // Keep the same effect state across pause and
                                                    // reacquisition; only a new hit changes its key.
                                                    if (e.hitSerial > 0)
                                                      Positioned(
                                                          key: const ValueKey(
                                                              'reach-tap-hit-effect'),
                                                          top: 12,
                                                          left: 0,
                                                          right: 0,
                                                          child: IgnorePointer(
                                                              child: TweenAnimationBuilder<
                                                                      double>(
                                                                  key: ValueKey(e
                                                                      .hitSerial),
                                                                  tween: Tween(
                                                                      begin: 1,
                                                                      end: 0),
                                                                  duration: const Duration(
                                                                      milliseconds:
                                                                          450),
                                                                  builder: (context, value, _) => Opacity(
                                                                      opacity:
                                                                          value,
                                                                      child: const Text(
                                                                          '+10',
                                                                          textAlign:
                                                                              TextAlign.center,
                                                                          style: TextStyle(color: AppColors.accent, fontSize: 28, fontWeight: FontWeight.w900))))))
                                                  ]))),
                                      const SizedBox(height: 12),
                                      Text(_status(e),
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      if (e.phase ==
                                              ReachTapPhase.calibrating ||
                                          e.phase == ReachTapPhase.trackingLost)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 6),
                                            child: Text(e.feedback,
                                                textAlign: TextAlign.center)),
                                      if (e.phase ==
                                          ReachTapPhase.calibrating) ...[
                                        const SizedBox(height: 8),
                                        LinearProgressIndicator(
                                            value: e.calibrationProgress)
                                      ],
                                      if (c.error != null) ...[
                                        const SizedBox(height: 8),
                                        Text(c.error!,
                                            textAlign: TextAlign.center)
                                      ],
                                      const SizedBox(height: 10),
                                      Wrap(
                                          alignment: WrapAlignment.center,
                                          spacing: 12,
                                          runSpacing: 8,
                                          children: [
                                            if (c.loading)
                                              const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator())
                                            else if (c.error != null ||
                                                e.phase == ReachTapPhase.paused)
                                              FilledButton.icon(
                                                  onPressed: c.resume,
                                                  icon: const Icon(
                                                      Icons.play_arrow),
                                                  label: const Text('Resume'))
                                            else
                                              OutlinedButton.icon(
                                                  onPressed: c.pause,
                                                  icon: const Icon(Icons.pause),
                                                  label: const Text('Pause')),
                                          ]),
                                      const SizedBox(height: 8),
                                      const Text(
                                          'L / R cursors follow your hands. Touching the screen does not score.',
                                          textAlign: TextAlign.center),
                                    ])))));
      });
  Widget _consent(BuildContext context) => SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.touch_app_outlined,
            size: 64, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(_content.title,
            style: const TextStyle(
                color: AppColors.ink,
                fontSize: 26,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(_content.introduction),
        const SizedBox(height: 12),
        if (content == null)
          for (var i = 0; i < _content.instructions.length; i++)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${i + 1}. ${_content.instructions[i]}')),
        const Text(
            'Each confirmed hand hit earns +10 local Game Score. Play for 40 active seconds.'),
        const SizedBox(height: 20),
        const Text(
            'Make room to step and reach. Keep your shoulders, hips and both hands visible for alignment. Ready and countdown start automatically.'),
        const SizedBox(height: 12),
        const Text(
            'Camera images and hand positions stay on this device. Only completed-round score, hit count and date are saved locally for your account.'),
        const SizedBox(height: 20),
        const Text('Game Score is separate from Reward Points.'),
        Text(controller.roundTimingConsent
            ? 'Play & Earn · complete a round to check +20 Reward Points'
            : 'Play for fun · no Reward Points'),
        if (controller.earningUnavailable)
          const Text(
              'Earning unavailable or already earned today. Continuing for fun.'),
        if (onChangeMode != null)
          TextButton(
              onPressed: controller.loading ? null : onChangeMode,
              child: const Text('Change mode')),
        if (competitionConsent != null) competitionConsent!,
        const SizedBox(height: 24),
        FilledButton.icon(
            onPressed: controller.loading
                ? null
                : () => controller.startCamera(consented: true),
            icon: const Icon(Icons.videocam_outlined),
            label:
                Text(controller.loading ? 'Opening camera…' : 'Start camera')),
      ]));
  Widget _results(BuildContext context) {
    final c = controller;
    return MoveCatchResultPanel(
      gameTitle: 'Reach & Tap',
      competitionStatus: competitionStatus,
      onLeaderboard: onLeaderboard,
      hitsOnly: true,
      score: c.engine.score,
      caught: c.engine.hits,
      missed: 0,
      obstacles: 0,
      bestScore: c.bestScore ?? 0,
      bestScoreAvailable: c.bestScore != null,
      bestSaved: c.saved,
      scoreSaveFailed: c.saveFailed,
      saving: c.saving,
      newPersonalBest: c.newPersonalBest,
      onRetrySave: c.retrySave,
      onReplay: c.saved && !c.loading ? c.restart : null,
      onExit: () {
        if (!c.saving) onExit?.call();
      },
      error: c.error,
      rewardStatus: c.roundTimingConsent && participationStatus != null
          ? participationStatus
          : const Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text('Reward Points · Not participating',
                      style: TextStyle(
                          color: AppColors.ink, fontWeight: FontWeight.w700)),
                  Text(
                      'Play for fun keeps your local score and personal best. Game Score is separate from Reward Points.'),
                ])),
      footer: c.localHistory == null
          ? null
          : ExpansionTile(
              title: const Text('Local game history'),
              children: [
                for (final round in c.localHistory!.rounds.take(10))
                  ListTile(
                    title:
                        Text('${round.score} Game Score · ${round.hits} hits'),
                    subtitle: Text(round.completedAt
                        .toLocal()
                        .toString()
                        .split('.')
                        .first),
                  )
              ],
            ),
    );
  }

  static String _status(ReachTapEngine e) => switch (e.phase) {
        ReachTapPhase.calibrating =>
          'Align with the silhouette · hold your body and both hands steady',
        ReachTapPhase.ready => 'Ready · keep both hands in view',
        ReachTapPhase.countdown => 'Get ready · keep both hands in view',
        ReachTapPhase.playing => 'Reach a target and hold briefly to confirm',
        ReachTapPhase.paused => 'Paused · Resume when ready',
        ReachTapPhase.recovering =>
          'Tracking interrupted · score and timer paused',
        ReachTapPhase.trackingLost =>
          'Tracking paused · return into view for automatic alignment',
        ReachTapPhase.finished => 'Round complete',
      };
  static Widget _chip(IconData icon, String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Flexible(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w700)))
      ]));
}

/// All circles use the shortest side as their radius unit, matching collisions.
class ReachTapBoardPainter extends CustomPainter {
  ReachTapBoardPainter({required this.engine});
  final ReachTapEngine engine;
  @override
  void paint(Canvas canvas, Size size) {
    final unit = math.min(size.width, size.height);
    Offset at(math.Point<double> p) =>
        Offset(p.x * size.width, p.y * size.height);
    if (engine.phase != ReachTapPhase.playing &&
        engine.phase != ReachTapPhase.recovering) {
      final p = Paint()
        ..color = Colors.white.withValues(alpha: .38)
        ..strokeWidth = unit * .035
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final cx = size.width / 2, sy = size.height * .32, hy = size.height * .63;
      canvas.drawCircle(Offset(cx, size.height * .19), unit * .065, p);
      canvas.drawLine(Offset(cx, sy), Offset(cx, hy), p);
      canvas.drawLine(
          Offset(cx - unit * .14, sy), Offset(cx + unit * .14, sy), p);
      for (final sign in [-1, 1]) {
        final shoulder = Offset(cx + sign * unit * .14, sy),
            elbow = Offset(cx + sign * unit * .25, size.height * .43),
            hand = Offset(cx + sign * unit * .30, size.height * .52);
        canvas.drawLine(shoulder, elbow, p);
        canvas.drawLine(elbow, hand, p);
        canvas.drawCircle(hand, unit * .04, p);
        canvas.drawLine(Offset(cx, hy),
            Offset(cx + sign * unit * .14, size.height * .84), p);
      }
    }
    final target = engine.target;
    if (target != null &&
        (engine.phase == ReachTapPhase.playing ||
            engine.phase == ReachTapPhase.recovering)) {
      final recovering = engine.phase == ReachTapPhase.recovering;
      canvas.drawCircle(
          at(target),
          engine.targetRadius * unit,
          Paint()
            ..color =
                AppColors.accent.withValues(alpha: recovering ? .12 : .45));
      canvas.drawCircle(
          at(target),
          engine.targetRadius * unit,
          Paint()
            ..color = recovering ? Colors.amber : AppColors.accent
            ..strokeWidth = 3
            ..style = PaintingStyle.stroke);
      canvas.drawCircle(at(target), 3, Paint()..color = Colors.white);
    }
    if (engine.trackingReady ||
        engine.phase == ReachTapPhase.calibrating ||
        engine.phase == ReachTapPhase.recovering) {
      for (final entry in [
        (engine.leftHand, 'L', Colors.cyanAccent),
        (engine.rightHand, 'R', Colors.pinkAccent)
      ]) {
        if (entry.$1 == null) continue;
        final point = at(entry.$1!);
        canvas.drawCircle(
            point, engine.cursorRadius * unit, Paint()..color = entry.$3);
        canvas.drawCircle(
            point,
            engine.cursorRadius * unit,
            Paint()
              ..color = Colors.white
              ..strokeWidth = 2
              ..style = PaintingStyle.stroke);
        final label = TextPainter(
            text: TextSpan(
                text: entry.$2,
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w900)),
            textDirection: TextDirection.ltr)
          ..layout();
        label.paint(canvas, point - Offset(label.width / 2, label.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant ReachTapBoardPainter oldDelegate) => true;
}
