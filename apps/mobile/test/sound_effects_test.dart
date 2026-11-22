import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/gamification/application/app_check_in_cubit.dart';
import 'package:gainpath_mobile/infrastructure/audio/sound_effects.dart';

import 'app_check_in_test.dart' show FakeCheckIn;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('claim sound plays once for a newly awarded claim', () async {
    const channel = MethodChannel('gainpath/sound_effects');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final played = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'play');
      played.add(call.arguments as String);
      return 0;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final scope = SessionScope(userId: 'sfx', organizationId: 'gainpath');
    final repository = FakeCheckIn(scope)..offline = true;
    final cubit = AppCheckInCubit(
        repository: repository,
        activeScope: () => scope,
        onAwarded: () => SoundEffects.play(SoundEffect.pointsClaimed));
    await cubit.claim();
    expect(played, isEmpty);
    repository.offline = false;
    await cubit.refresh();
    expect(played, isEmpty);
    await cubit.claim();
    await cubit.claim();
    expect(played, ['pointsClaimed']);
    await cubit.close();
  });

  test('fast hits earn combo audio and gaps or resets break the chain', () {
    final feedback = ArcadeSoundFeedback();
    expect(feedback.hit(0), SoundEffect.gameHit);
    expect(feedback.hit(350), SoundEffect.gameHit);
    expect(feedback.hit(600), SoundEffect.combo);
    expect(feedback.hit(2900), SoundEffect.gameHit);
    expect(feedback.hit(3100), SoundEffect.gameHit);
    feedback.reset();
    expect(feedback.hit(3500), SoundEffect.gameHit);
  });
}
