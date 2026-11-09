import 'package:flutter/material.dart';

/// Standard page body padding.
class PageBody extends StatelessWidget {
  final List<Widget> children;
  final ScrollPhysics? physics;
  const PageBody({super.key, required this.children, this.physics});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: physics,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: children,
    );
  }
}
