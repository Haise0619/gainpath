import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// System/back-button protection. A confirmed save may still pop directly.
class Module1EditGuard extends StatefulWidget {
  const Module1EditGuard(
      {super.key,
      required this.dirty,
      required this.busy,
      required this.child});
  final bool dirty, busy;
  final Widget child;
  @override
  State<Module1EditGuard> createState() => _Module1EditGuardState();
}

class _Module1EditGuardState extends State<Module1EditGuard> {
  bool _asking = false;
  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !widget.dirty && !widget.busy,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop || widget.busy || _asking) return;
          _asking = true;
          final discard = await confirmSheet(context,
              title: 'Discard unsaved changes?',
              message: 'Your changes have not been saved.',
              confirmLabel: 'Discard changes');
          _asking = false;
          if (discard && context.mounted) Navigator.pop(context);
        },
        child: widget.child,
      );
}
