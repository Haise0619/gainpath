import 'dart:async';

import 'package:flutter/services.dart';

enum SoundEffect {
  ready,
  rep,
  workoutComplete,
  pointsClaimed,
  gameHit,
  combo,
  roundEnd
}

/// Device-local preferences and short Android sounds. Playback failure is
/// optional feedback and must never change a workout, claim or game result.
abstract final class SoundEffects {
  static const _channel = MethodChannel('gainpath/sound_effects');

  static Future<T?> _call<T>(String method, [Object? argument]) async {
    try {
      return await _channel.invokeMethod<T>(method, argument);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<bool?> enabled() => _call<bool>('enabled');
  static Future<bool> setEnabled(bool value) async =>
      await _call<bool>('setEnabled', value) == true;

  static void play(SoundEffect effect) {
    unawaited(_call<int>('play', effect.name));
  }

  static Future<void> playCompletion() async {
    final millis = await _call<int>('play', SoundEffect.workoutComplete.name)
        .timeout(const Duration(milliseconds: 250), onTimeout: () => null);
    if (millis != null && millis > 0) {
      await Future<void>.delayed(Duration(milliseconds: millis));
    }
  }
}

/// Feedback only: a combo is three quick hits. The game score is unaffected.
class ArcadeSoundFeedback {
  int? _lastHit;
  int _hits = 0;

  SoundEffect hit(int activeMillis) {
    final last = _lastHit;
    if (last == null || activeMillis < last || activeMillis - last > 2000) {
      _hits = 0;
    }
    _lastHit = activeMillis;
    return ++_hits % 3 == 0 ? SoundEffect.combo : SoundEffect.gameHit;
  }

  void reset() {
    _lastHit = null;
    _hits = 0;
  }
}
