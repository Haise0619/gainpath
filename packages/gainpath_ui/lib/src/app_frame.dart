import 'package:flutter/material.dart';

import 'theme.dart';

class GainPathAppFrame extends StatelessWidget {
  const GainPathAppFrame({
    super.key,
    required this.title,
    required this.home,
    this.admin = false,
  });

  final String title;
  final Widget home;
  final bool admin;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: GainPathUiTheme.build(admin: admin),
      home: home,
    );
  }
}
