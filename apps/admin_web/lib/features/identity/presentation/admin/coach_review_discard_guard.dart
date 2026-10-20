import 'package:flutter/material.dart';

/// Scoped to one Admin shell; never retains review values or credentials.
class CoachReviewDiscardGuard {
  Future<bool> Function()? confirm;
  Future<bool> canLeave() async => await confirm?.call() ?? true;
}

Future<bool> confirmCoachReviewDiscard(BuildContext context) async =>
    await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Discard unsaved review reasons?'),
              content: const Text(
                  'Your typed certification review reasons have not been submitted.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep editing')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Discard')),
              ],
            )) ??
    false;
