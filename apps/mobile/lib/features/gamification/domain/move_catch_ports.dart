import 'package:flutter/foundation.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

class MoveCatchTorsoSample {
  const MoveCatchTorsoSample(
      {required this.centerX,
      required this.shoulderWidth,
      required this.capturedAtMicros,
      this.fullTorso = true});
  final bool fullTorso;
  final double centerX, shoulderWidth;
  final int capturedAtMicros;
}

abstract class MoveCatchCamera extends ChangeNotifier {
  bool get tracking;
  String? get error;
  Future<void> start(void Function(MoveCatchTorsoSample) onSample);
  Future<void> pause();
  Future<void> resume();
  Future<void> close();
}

abstract interface class MoveCatchBestScoreStore {
  Future<int> load(SessionScope scope);
  Future<int> record(SessionScope scope, int score,
      {required bool Function() isCurrent});
}
