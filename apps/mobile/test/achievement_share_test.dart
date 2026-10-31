import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/domain/app_check_in.dart';
import 'package:gainpath_mobile/infrastructure/platform/achievement_share.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'only real unlocked check-in badges open native sharing without private data',
      () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('gainpath/achievement_share'), (call) async {
      calls.add(call);
      return null;
    });
    final share = NativeAchievementShare();
    await expectLater(
        share.badge(const AppCheckInBadge(
            id: 'check-in-streak-3', title: 'Three days', requiredStreak: 3)),
        throwsArgumentError);
    await expectLater(
        share.badge(const AppCheckInBadge(
            id: 'fake',
            title: 'Fake',
            requiredStreak: 1,
            unlockedAtMillis: 1800000000000)),
        throwsArgumentError);
    expect(calls, isEmpty);
    await share.badge(const AppCheckInBadge(
        id: 'check-in-streak-3',
        title: 'Three days',
        requiredStreak: 3,
        unlockedAtMillis: 1800000000000));
    expect(calls.single.method, 'share');
    expect(calls.single.arguments, {
      'text': 'I unlocked the Three-day check-in streak badge in GainPath!'
    });
  });
}
