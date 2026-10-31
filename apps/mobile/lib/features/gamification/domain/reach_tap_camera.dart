import 'package:flutter/foundation.dart';
import 'reach_tap.dart';

/// An unavailable observation is explicit; the game never reuses a hidden hand.
abstract class ReachTapCamera extends ChangeNotifier {
  bool get tracking;
  String? get error;
  Future<void> start(void Function(ReachTapSample?) onSample);
  Future<void> pause();
  Future<void> resume();
  Future<void> close();
}
