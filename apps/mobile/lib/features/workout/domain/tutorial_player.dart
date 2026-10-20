import 'package:flutter/widgets.dart';

typedef TutorialPlayerFactory = TutorialPlayer Function(Uri uri);

/// Presentation port; native plugin/resource ownership stays in infrastructure.
abstract class TutorialPlayer extends ChangeNotifier {
  bool get ready;
  bool get playing;
  bool get buffering;
  String? get error;
  Duration get duration;
  Duration get position;
  double get aspectRatio;
  Future<void> initialize();
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Widget buildVideo();
}
