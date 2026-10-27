import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class ExerciseVideoPlayer extends StatefulWidget {
  const ExerciseVideoPlayer({super.key, required this.url, this.bytes});
  final String url;
  final Uint8List? bytes;

  @override
  State<ExerciseVideoPlayer> createState() => _ExerciseVideoPlayerState();
}

class _ExerciseVideoPlayerState extends State<ExerciseVideoPlayer> {
  web.HTMLVideoElement? _video;
  String? _ownedUrl;
  bool _failed = false;
  int _generation = 0;
  late final JSFunction _onError = ((web.Event event) {
    if (mounted) setState(() => _failed = true);
  }).toJS;

  @override
  void didUpdateWidget(covariant ExerciseVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes) ||
        oldWidget.url != widget.url) {
      _release();
      _failed = false;
      _generation++;
    }
  }

  void _release() {
    final video = _video;
    if (video != null) {
      video.removeEventListener('error', _onError);
      video.pause();
      video.removeAttribute('src');
      video.load();
      _video = null;
    }
    if (_ownedUrl != null) {
      web.URL.revokeObjectURL(_ownedUrl!);
      _ownedUrl = null;
    }
  }

  void _attach(Object element) {
    final video = element as web.HTMLVideoElement;
    _video = video;
    video.controls = true;
    video.autoplay = false;
    video.preload = 'metadata';
    video.setAttribute('playsinline', '');
    video.setAttribute('aria-label', 'Tutorial playback controls');
    video.style.width = '100%';
    video.style.height = '100%';
    video.style.objectFit = 'contain';
    video.addEventListener('error', _onError);
    final bytes = widget.bytes;
    if (bytes != null) {
      // Immutable selections need a native ArrayBuffer at the browser boundary.
      final blob = web.Blob([Uint8List.fromList(bytes).toJS].toJS,
          web.BlobPropertyBag(type: 'video/mp4'));
      _ownedUrl = web.URL.createObjectURL(blob);
      video.src = _ownedUrl!;
    } else {
      // No anonymous CORS fetch: media elements can play Storage URLs directly.
      video.src = widget.url;
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
              'Video could not play. Check the file format or connection.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white)),
          TextButton(
            onPressed: () => setState(() {
              _release();
              _failed = false;
              _generation++;
            }),
            child: const Text('Retry video'),
          ),
        ]),
      );
    }
    return HtmlElementView.fromTagName(
      key: ValueKey(_generation),
      tagName: 'video',
      onElementCreated: _attach,
    );
  }
}
