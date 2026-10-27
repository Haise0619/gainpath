import 'dart:typed_data';
import 'package:flutter/material.dart';

class ExerciseVideoPlayer extends StatelessWidget {
  const ExerciseVideoPlayer({super.key, required this.url, this.bytes});
  final String url;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) => const Center(
        child: Text('Video playback is available in the web console.',
            style: TextStyle(color: Colors.white)),
      );
}
