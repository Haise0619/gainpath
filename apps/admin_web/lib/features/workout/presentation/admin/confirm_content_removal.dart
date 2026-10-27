import 'package:flutter/material.dart';

Future<bool> confirmContentRemoval(BuildContext context,
        {required String title, required String detail}) async =>
    await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Remove "$title"?'),
              content: Text(detail),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Remove')),
              ],
            )) ??
    false;
