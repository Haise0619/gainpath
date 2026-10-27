import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'video_preview_stub.dart'
    if (dart.library.js_interop) 'video_preview_web.dart' as platform;

/// Browser playback uses the saved URL directly; local selections stay local.
class ContentVideoPreview extends StatelessWidget {
  const ContentVideoPreview(
      {super.key,
      this.url = '',
      this.bytes,
      this.semanticsLabel = 'Exercise tutorial video preview'});
  final String url;
  final Uint8List? bytes;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        explicitChildNodes: true,
        label: semanticsLabel,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: Colors.black,
              child: platform.ContentVideoPlayer(url: url, bytes: bytes),
            ),
          ),
        ),
      );
}
