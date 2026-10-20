import 'package:firebase_app_check/firebase_app_check.dart';

/// Build configuration only. Supply debug tokens through private build inputs.
/// Debug mode never generates or logs a token automatically.
class AdminAppCheckConfig {
  const AdminAppCheckConfig(
      {this.mode = 'off', this.debugToken = '', this.siteKey = ''});
  factory AdminAppCheckConfig.fromEnvironment() => const AdminAppCheckConfig(
        mode: String.fromEnvironment('APP_CHECK_MODE', defaultValue: 'off'),
        debugToken: String.fromEnvironment('APP_CHECK_WEB_DEBUG_TOKEN'),
        siteKey: String.fromEnvironment('APP_CHECK_WEB_SITE_KEY'),
      );
  final String mode;
  final String debugToken;
  final String siteKey;
  WebProvider? provider() {
    switch (mode) {
      case 'off':
        return null;
      case 'debug':
        if (debugToken.trim().isEmpty)
          throw StateError(
              'App Check debug mode requires a privately supplied registered debug token.');
        return WebDebugProvider(debugToken: debugToken);
      case 'production':
        if (siteKey.trim().isEmpty)
          throw StateError(
              'App Check production mode requires APP_CHECK_WEB_SITE_KEY.');
        return ReCaptchaV3Provider(siteKey);
      default:
        throw StateError('APP_CHECK_MODE must be off, debug, or production.');
    }
  }
}

Future<void> initializeAdminAppCheck() async {
  final provider = AdminAppCheckConfig.fromEnvironment().provider();
  if (provider == null) return;
  await FirebaseAppCheck.instance.activate(providerWeb: provider);
  await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
}
