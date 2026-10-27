import 'package:flutter/material.dart';
import '../../application/move_and_catch_controller.dart';
import '../../domain/move_and_catch.dart';

/// Explicit and Android system back share one lifecycle-aware exit path.
class MoveCatchExitGuard extends StatefulWidget {
  const MoveCatchExitGuard(
      {super.key, required this.controller, required this.builder});
  final MoveAndCatchController controller;
  final Widget Function(Future<void> Function() exit) builder;
  @override
  State<MoveCatchExitGuard> createState() => _MoveCatchExitGuardState();
}

class _MoveCatchExitGuardState extends State<MoveCatchExitGuard> {
  bool _exiting = false, _allowPop = false;
  Future<void> _exit() async {
    if (_exiting) return;
    _exiting = true;
    final c = widget.controller;
    var completed = c.engine.phase == MoveCatchPhase.finished;
    final running = c.engine.phase == MoveCatchPhase.playing ||
        c.engine.phase == MoveCatchPhase.countdown;
    try {
      if (c.current && c.hasConsent && !completed) {
        if (running) await c.pause();
        if (!mounted) return;
        final leave = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('Leave this round?'),
                    content: const Text(
                        'Your unfinished game score will not be saved. Reward points are unchanged.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Continue playing')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Leave round'))
                    ]));
        if (!mounted) return;
        if (leave != true && c.current) {
          if (running) await c.resume();
          return;
        }
      }
      completed = c.engine.phase == MoveCatchPhase.finished;
      if (completed) {
        await c.finishAndClose();
      } else {
        await c.close();
      }
      if (!mounted) return;
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).pop(completed);
    } finally {
      _exiting = false;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => PopScope<bool>(
          canPop: _allowPop || !widget.controller.current,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _exit();
          },
          child: widget.builder(_exit)));
}
