import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/app_check_config.dart';

void main() {
  test('off preserves existing Firebase bootstrap', () {
    expect(const AdminAppCheckConfig().provider(), isNull);
  });
  test('debug requires explicitly supplied token without auto generation', () {
    expect(() => const AdminAppCheckConfig(mode: 'debug').provider(),
        throwsStateError);
    final provider =
        const AdminAppCheckConfig(mode: 'debug', debugToken: 'test-placeholder')
            .provider();
    expect(provider, isA<WebDebugProvider>());
    expect((provider as WebDebugProvider).debugToken, 'test-placeholder');
  });
  test('production requires separate site key', () {
    expect(() => const AdminAppCheckConfig(mode: 'production').provider(),
        throwsStateError);
    expect(
        const AdminAppCheckConfig(
                mode: 'production', siteKey: 'public-site-key')
            .provider(),
        isA<ReCaptchaV3Provider>());
  });
  test('unknown mode fails explicitly', () {
    expect(() => const AdminAppCheckConfig(mode: 'typo').provider(),
        throwsStateError);
  });
}
