import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/achievement_sharing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('gainpath/achievement_share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final unlockedAt = DateTime.utc(2026, 11, 17, 16);

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('renders a local PNG and sends only the allowed share fields', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });

    await shareAchievement(
      id: 'century-club',
      name: 'Century Club',
      description: 'Complete 100 full repetitions.',
      unlockedAt: unlockedAt,
    );

    final call = calls.single;
    expect(call.method, 'shareImage');
    final arguments = call.arguments as Map<Object?, Object?>;
    expect(arguments.keys, unorderedEquals(['text', 'png']));
    expect(arguments['text'], 'I unlocked the Century Club badge in GainPath!');
    expect((arguments['png'] as Uint8List).take(8),
        [137, 80, 78, 71, 13, 10, 26, 10]);
  });

  test('reuses allowlisted text sharing when Android rejects the image',
      () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'shareImage') {
        throw PlatformException(code: 'unavailable');
      }
      return null;
    });

    await shareAchievement(
      id: 'check-in-streak-3',
      name: 'Three-day Streak',
      description: 'Check in for three consecutive days.',
      unlockedAt: unlockedAt,
    );

    expect(calls.map((call) => call.method), ['shareImage', 'share']);
    expect(calls.last.arguments, {
      'text': 'I unlocked the Three-day check-in streak badge in GainPath!',
    });
  });

  test('aborts native sharing if the member changes during rendering', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    var current = true;
    final share = shareAchievement(
      id: 'first-workout',
      name: 'First Workout',
      description: 'Complete a workout.',
      unlockedAt: unlockedAt,
      isCurrent: () => current,
    );
    current = false;
    await share;
    expect(calls, isEmpty);
  });
}
