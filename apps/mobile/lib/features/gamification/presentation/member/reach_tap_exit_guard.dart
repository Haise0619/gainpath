import 'dart:async';
import 'package:flutter/material.dart';
import '../../application/reach_tap_controller.dart';
import '../../domain/reach_tap.dart';

class ReachTapExitGuard extends StatefulWidget {
  const ReachTapExitGuard(
      {super.key, required this.controller, required this.builder});
  final ReachTapController controller;
  final Widget Function(Future<void> Function() exit) builder;
  @override
  State<ReachTapExitGuard> createState() => _ReachTapExitGuardState();
}

class _ReachTapExitGuardState extends State<ReachTapExitGuard> {
  bool _exiting = false, _allowPop = false;
  Future<void> _exit() async {
    if (_exiting) return;
    _exiting = true;
    final c = widget.controller;
    try {
      if (c.current && c.engine.phase == ReachTapPhase.finished) {
        await c.settleSave();
      }
      if (!mounted) return;
      if (c.current &&
          c.hasConsent &&
          (c.engine.phase != ReachTapPhase.finished || !c.saved)) {
        await c.pause();
        if (!mounted) return;
        final leave = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('Leave this round?'),
                    content: Text(c.engine.phase == ReachTapPhase.finished
                        ? 'This completed result has not been saved. Leave without saving?'
                        : 'Your unfinished Game Score will not be saved.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Stay')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Leave round'))
                    ]));
        if (leave != true) return;
      }
      await c.finishAndClose();
      if (!mounted) return;
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) {
        Navigator.of(context).pop(c.engine.phase == ReachTapPhase.finished);
      }
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
            if (!didPop) unawaited(_exit());
          },
          child: widget.builder(_exit)));
}
