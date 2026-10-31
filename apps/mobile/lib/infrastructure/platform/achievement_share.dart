import 'package:flutter/services.dart';
import '../../features/gamification/domain/app_check_in.dart';

/// Explicit user share of a fixed achievement label; never identity, QR or media.
class NativeAchievementShare {
  static const _channel = MethodChannel('gainpath/achievement_share');
  Future<void> badge(AppCheckInBadge badge) async {
    const names = {
      'first-check-in': 'First check-in',
      'check-in-streak-3': 'Three-day check-in streak',
      'check-in-streak-7': 'Seven-day check-in streak'
    };
    final name = names[badge.id];
    if (name == null || badge.unlockedAtMillis == null) {
      throw ArgumentError('Unlocked check-in badge required.');
    }
    await _channel.invokeMethod<void>(
        'share', {'text': 'I unlocked the $name badge in GainPath!'});
  }
}
