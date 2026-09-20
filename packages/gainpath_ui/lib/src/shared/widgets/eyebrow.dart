import 'package:flutter/material.dart';

/// Small uppercase label used to head a group of content.
class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall),
      );
}
