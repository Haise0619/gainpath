import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/move_and_catch_controller.dart';
import '../../domain/move_and_catch.dart';
import 'move_catch_result_panel.dart';
import 'mini_game_round_status_panel.dart';

class MoveAndCatchView extends StatefulWidget {
  const MoveAndCatchView(
      {super.key,
      required this.controller,
      required this.viewport,
      this.content,
      this.onExit,
      this.participationStatus,
      this.rewardStatus,
      this.modeSelected = false,
      this.competitionStatus,
      this.competitionConsent,
      this.onLeaderboard});
  final MoveAndCatchController controller;
  final Widget viewport;
  final MiniGameContent? content;
  final Future<void> Function()? onExit;
  final Widget? rewardStatus, competitionStatus, competitionConsent;
  final VoidCallback? onLeaderboard;
  final bool modeSelected;
  final Widget? participationStatus;
  @override
  State<MoveAndCatchView> createState() => _MoveAndCatchViewState();
}

class _MoveAndCatchViewState extends State<MoveAndCatchView> {
  Future<void> _exit() async {
    if (widget.onExit != null) {
      await widget.onExit!();
      return;
    }
    await widget.controller.close();
    if (mounted) await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        if (!controller.current) {
          return const Scaffold(
              body: SafeArea(
                  child: Center(child: Text('This game session has ended.'))));
        }
        if (!controller.hasConsent) return _consent(context);
        final engine = controller.engine;
        final phase = engine.phase.name;
        return Scaffold(
            backgroundColor: AppColors.surface,
            body: SafeArea(
                child: Stack(fit: StackFit.expand, children: [
              ExcludeSemantics(
                  excluding: phase == 'finished',
                  child: IgnorePointer(
                      ignoring: phase == 'finished',
                      child: Column(children: [
                        Expanded(
                            flex: 4,
                            child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 8, 12, 0),
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child:
                                        Stack(fit: StackFit.expand, children: [
                                      // The camera stays in this same slot throughout calibration, play and results.
                                      widget.viewport,
                                      IgnorePointer(
                                          child: CustomPaint(
                                              painter: _GamePainter(
                                                  playerX: engine.playerX,
                                                  objects: [
                                            for (final item in engine.objects)
                                              (
                                                x: item.x,
                                                y: item.y,
                                                star: item.kind.name == 'star'
                                              )
                                          ]))),
                                      Positioned(
                                          top: 10,
                                          left: 10,
                                          right: 10,
                                          child: Semantics(
                                              liveRegion: false,
                                              child: Wrap(
                                                  alignment: WrapAlignment
                                                      .spaceBetween,
                                                  spacing: 8,
                                                  runSpacing: 6,
                                                  children: [
                                                    _badge(
                                                        'Score ${engine.score}',
                                                        Icons.star_rounded),
                                                    _badge(
                                                        '${engine.remainingSeconds.ceil()}s',
                                                        Icons.timer_outlined)
                                                  ]))),
                                      if (phase == 'countdown')
                                        Center(
                                            child: Container(
                                                padding:
                                                    const EdgeInsets.all(26),
                                                decoration: const BoxDecoration(
                                                    color: AppColors.primary,
                                                    shape: BoxShape.circle),
                                                child: Text(
                                                    '${engine.countdownSeconds}',
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 44)))),
                                      if (engine.inTrackingGrace)
                                        Positioned(
                                            top: 64,
                                            left: 12,
                                            right: 12,
                                            child: Semantics(
                                                liveRegion: true,
                                                child: Center(
                                                    child: _badge(
                                                        'Pausing in ${engine.trackingGraceSeconds}s · move into view',
                                                        Icons
                                                            .person_search_outlined)))),
                                      if (phase == 'paused' ||
                                          phase == 'trackingLost')
                                        Positioned(
                                            bottom: 76,
                                            left: 12,
                                            right: 12,
                                            child: Center(
                                                child: _badge(
                                                    phase == 'paused'
                                                        ? 'Paused'
                                                        : 'Tracking lost · time frozen',
                                                    phase == 'paused'
                                                        ? Icons.pause_rounded
                                                        : Icons
                                                            .person_search_outlined))),
                                      if (controller.loading)
                                        const Center(
                                            child: CircularProgressIndicator()),
                                    ])))),
                        Flexible(
                            flex: 1,
                            child: SingleChildScrollView(
                                padding: const EdgeInsets.all(12),
                                child: _controls(context, phase))),
                      ]))),
              if (phase == 'finished')
                MoveCatchResultPanel(
                    score: engine.score,
                    caught: engine.caught,
                    missed: engine.missed,
                    obstacles: engine.obstaclesHit,
                    bestScore: controller.bestScore,
                    bestScoreAvailable: controller.bestScoreAvailable,
                    bestSaved: controller.bestSaved,
                    scoreSaveFailed: controller.scoreSaveFailed,
                    newPersonalBest: controller.newPersonalBest,
                    saving: controller.saving,
                    onRetrySave: controller.retrySave,
                    competitionStatus: widget.competitionStatus,
                    onLeaderboard: widget.onLeaderboard,
                    rewardStatus: widget.modeSelected &&
                            !controller.roundTimingConsent
                        ? const Panel(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                Text('Reward Points · Play for fun',
                                    style: TextStyle(
                                        color: AppColors.ink,
                                        fontWeight: FontWeight.w700)),
                                Text('No Reward Points claim for this round.')
                              ]))
                        : (controller.roundTimingConsent
                                ? widget.participationStatus
                                : null) ??
                            (controller.roundTiming != null &&
                                    controller.roundTimingConsent
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                        if (widget.rewardStatus != null)
                                          widget.rewardStatus!,
                                        const SizedBox(height: 12),
                                        MiniGameRoundStatusPanel(
                                            coordinator:
                                                controller.roundTiming!),
                                      ])
                                : widget.rewardStatus),
                    error: controller.error,
                    onReplay:
                        controller.loading ? null : () => controller.restart(),
                    onExit: _exit),
            ])));
      });
  Widget _badge(String text, IconData icon) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 6),
        Flexible(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.ink, fontWeight: FontWeight.w700)))
      ]));
  Widget _consent(BuildContext context) {
    final c = widget.controller;
    final candidate = widget.content;
    final content = candidate != null &&
            candidate.gameId == MiniGameContent.supportedId &&
            candidate.organizationId == c.scope.organizationId
        ? candidate
        : null;
    return Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                              color: AppColors.primaryTint,
                              borderRadius: BorderRadius.circular(20)),
                          child: const Icon(Icons.sports_esports_outlined,
                              color: AppColors.primary, size: 36)),
                      const SizedBox(height: 20),
                      Text(content?.title ?? 'Move & Catch',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      Text(content?.introduction ??
                          'Lean left and right to catch stars and avoid obstacles in a 40-second round.'),
                      if (content != null && !widget.modeSelected) ...[
                        const SizedBox(height: 16),
                        for (var i = 0; i < content.instructions.length; i++)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child:
                                  Text('${i + 1}. ${content.instructions[i]}')),
                        const SizedBox(height: 8),
                        const Text(
                            '40 seconds · Camera movement · Personal best'),
                      ],
                      const SizedBox(height: 20),
                      const Text(
                          'Clear the floor around you. Face the camera with your shoulders and hips visible. Move gently without jumping.'),
                      const SizedBox(height: 20),
                      const Text(
                          'Camera and movement stay on this device. No video is saved. Game scores are not reward points.'),
                      if (widget.modeSelected) ...[
                        const SizedBox(height: 12),
                        Text(c.roundTimingConsent
                            ? 'Play & Earn · timing shared with your consent'
                            : c.earningUnavailable
                                ? 'Earning is unavailable · continuing for fun'
                                : 'Play for fun · no Reward Points claim'),
                        TextButton(
                            onPressed: c.loading ? null : _exit,
                            child: const Text('Change mode'))
                      ],
                      if (!widget.modeSelected && c.roundTiming != null) ...[
                        const SizedBox(height: 12),
                        CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: c.roundTimingConsent,
                            onChanged: (value) =>
                                c.setRoundTimingConsent(value ?? false),
                            title: Text(widget.participationStatus == null
                                ? 'Send round timing for verification checks'
                                : 'Earn points for this round'),
                            subtitle: Text(widget.participationStatus == null
                                ? 'Optional. Sends round ID, start/end times, checkpoints and active/paused status to GainPath. No video, pose coordinates or game score is sent. Timing alone does not earn points.'
                                : 'Optional. Share round timing to earn points. Camera, pose and score stay on-device.')),
                      ],
                      if (widget.competitionConsent != null)
                        widget.competitionConsent!,
                      const SizedBox(height: 20),
                      if (c.error != null)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(c.error!,
                                style:
                                    const TextStyle(color: AppColors.danger))),
                      if (c.loading) const LinearProgressIndicator(),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        FilledButton.icon(
                            onPressed: c.loading
                                ? null
                                : () => c.startCamera(consented: true),
                            icon: const Icon(Icons.videocam_outlined),
                            label: const Text('Enable camera')),
                        OutlinedButton(
                            onPressed: _exit, child: const Text('Exit'))
                      ]),
                    ]))));
  }

  Widget _controls(BuildContext context, String phase) {
    final c = widget.controller, e = c.engine;
    String title, body;
    switch (phase) {
      case 'ready':
        title = 'Ready to catch';
        body =
            'Calibration complete. Catch the stars; avoid the diamond obstacles.';
      case 'countdown':
        title = 'Get ready';
        body = 'Start in ${e.countdownSeconds}…';
      case 'playing':
        title = 'Lean to move the basket';
        body = 'Catch stars. Avoid obstacles.';
      case 'paused':
        title = 'Take a rest';
        body = 'The game clock is paused. Resume when you are ready.';
      case 'trackingLost':
        title = 'Step back into view';
        body =
            'Keep your shoulders and hips visible. Tap Resume to continue when tracking returns.';
      default:
        title = 'Find your starting position';
        body =
            'Stand comfortably in the centre with your shoulders and hips visible.';
    }
    if (e.inTrackingGrace) {
      title = 'Come back into view';
      body =
          'Basket held in place. Return within ${e.trackingGraceSeconds}s to keep playing.';
    }
    return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(body),
      if (phase == 'calibrating')
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: LinearProgressIndicator(
                value: e.calibrationProgress.clamp(0.0, 1.0),
                semanticsLabel: 'Position calibration')),
      if (c.error != null) ...[
        const SizedBox(height: 8),
        Text(c.error!, style: const TextStyle(color: AppColors.danger))
      ],
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (phase == 'ready' && !c.autoStart)
          FilledButton(
              onPressed: c.loading ? null : () => c.startRound(),
              child: const Text('Start round')),
        if (phase == 'playing' || phase == 'countdown')
          FilledButton.icon(
              onPressed: () => c.pause(),
              icon: const Icon(Icons.pause_rounded),
              label: const Text('Pause')),
        if (phase == 'paused' || phase == 'trackingLost')
          FilledButton(
              onPressed: c.loading ? null : () => c.resume(),
              child: const Text('Resume')),
        if (c.error != null)
          OutlinedButton(
              onPressed:
                  c.loading ? null : () => c.startCamera(consented: true),
              child: const Text('Retry camera')),
        TextButton(onPressed: _exit, child: const Text('Exit')),
      ]),
    ]));
  }
}

class _GamePainter extends CustomPainter {
  _GamePainter({required this.playerX, required this.objects});
  final double playerX;
  final List<({double x, double y, bool star})> objects;
  @override
  void paint(Canvas canvas, Size size) {
    for (final object in objects) {
      final centre = Offset(object.x * size.width, object.y * size.height);
      final path = Path();
      if (object.star) {
        for (var i = 0; i < 10; i++) {
          final radius = i.isEven ? 18.0 : 8.0,
              angle = -math.pi / 2 + i * math.pi / 5;
          final point = centre +
              Offset(math.cos(angle) * radius, math.sin(angle) * radius);
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
        canvas.drawPath(path, Paint()..color = const Color(0xFFFFD34E));
        canvas.drawPath(
            path,
            Paint()
              ..color = AppColors.primary
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5);
      } else {
        path.moveTo(centre.dx, centre.dy - 19);
        path.lineTo(centre.dx + 19, centre.dy);
        path.lineTo(centre.dx, centre.dy + 19);
        path.lineTo(centre.dx - 19, centre.dy);
        path.close();
        canvas.drawPath(path, Paint()..color = const Color(0xFFB52E5F));
        final mark = Paint()
          ..color = Colors.white
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
            centre + const Offset(-6, -6), centre + const Offset(6, 6), mark);
        canvas.drawLine(
            centre + const Offset(6, -6), centre + const Offset(-6, 6), mark);
      }
    }
    final x = playerX * size.width,
        y = size.height * MoveCatchEngine.catchY,
        halfWidth = size.width * MoveCatchEngine.catchHalfWidth;
    final basket = Path()
      ..moveTo(x - halfWidth, y)
      ..lineTo(x + halfWidth, y)
      ..lineTo(x + halfWidth * .76, y + 27)
      ..lineTo(x - halfWidth * .76, y + 27)
      ..close();
    canvas.drawPath(
        basket, Paint()..color = Colors.white.withValues(alpha: .95));
    canvas.drawPath(
        basket,
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);
    canvas.drawLine(
        Offset(x - halfWidth, y),
        Offset(x + halfWidth, y),
        Paint()
          ..color = AppColors.primary
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_GamePainter old) => true;
}
