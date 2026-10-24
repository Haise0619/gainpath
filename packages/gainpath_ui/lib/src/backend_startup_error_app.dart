import 'package:flutter/material.dart';

/// A failed bootstrap never creates Auth or feature repositories.
/// Only fixed guidance is displayed; SDK errors can contain private details.
class BackendStartupErrorApp extends StatelessWidget {
  const BackendStartupErrorApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'GainPath setup required',
        home: Scaffold(
          appBar: AppBar(title: const Text('GainPath')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: const [
                Text('Firebase could not initialize'),
                SizedBox(height: 12),
                Text(
                    'Check the app Firebase configuration and existing App Check setup, then restart.'),
              ]),
            ),
          ),
        ),
      );
}
