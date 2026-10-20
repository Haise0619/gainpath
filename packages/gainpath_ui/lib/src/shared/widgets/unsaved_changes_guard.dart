import 'package:flutter/material.dart';
import 'confirm_sheet.dart';

/// Protects drafts and in-flight saves when navigating back.
class UnsavedChangesGuard extends StatefulWidget {
  const UnsavedChangesGuard(
      {super.key,
      required this.dirty,
      required this.busy,
      required this.child});
  final bool dirty, busy;
  final Widget child;
  @override
  State<UnsavedChangesGuard> createState() => _UnsavedChangesGuardState();
}

class _UnsavedChangesGuardState extends State<UnsavedChangesGuard> {
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
      child: widget.child);
}
