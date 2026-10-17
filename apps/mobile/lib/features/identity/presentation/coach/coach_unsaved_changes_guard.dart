import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class CoachUnsavedChangesGuard extends StatefulWidget {
  const CoachUnsavedChangesGuard(
      {super.key,
      required this.dirty,
      required this.busy,
      required this.isCurrent,
      required this.child});
  final bool dirty, busy;
  final bool Function() isCurrent;
  final Widget child;
  @override
  State<CoachUnsavedChangesGuard> createState() =>
      _CoachUnsavedChangesGuardState();
}

class _CoachUnsavedChangesGuardState extends State<CoachUnsavedChangesGuard> {
  bool allowExit = false, confirming = false;
  @override
  Widget build(BuildContext context) => PopScope(
      canPop:
          allowExit || !widget.isCurrent() || (!widget.dirty && !widget.busy),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || widget.busy || confirming || !widget.isCurrent()) return;
        confirming = true;
        final discard = await confirmSheet(context,
            title: 'Discard unsaved changes?',
            message: 'Your unsaved changes will be lost.',
            confirmLabel: 'Discard',
            destructive: true);
        confirming = false;
        if (discard && mounted && widget.isCurrent()) {
          setState(() => allowExit = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      },
      child: widget.child);
}
