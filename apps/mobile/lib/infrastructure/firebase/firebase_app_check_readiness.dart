import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Booking capability only: failure never replaces the authenticated backend.
class FirebaseAppCheckReadiness {
  FirebaseAppCheckReadiness({
    this.mode =
        const String.fromEnvironment('APP_CHECK_MODE',
            defaultValue: kReleaseMode ? 'production' : 'debug'),
    this.release = kReleaseMode,
    bool? supported,
    Future<void> Function(String)? activate,
    Future<String?> Function()? token,
  })  : supported = supported ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.android),
        _activate = activate ?? _nativeActivate,
        _token = token ?? (() => FirebaseAppCheck.instance.getToken());
  static final instance = FirebaseAppCheckReadiness();
  final String mode;
  final bool release, supported;
  final Future<void> Function(String) _activate;
  final Future<String?> Function() _token;
  bool _activated = false;
  Future<void>? _initializing;
  bool get configured =>
      supported &&
      (mode == 'production' || (mode == 'debug' && !release && !kReleaseMode));
  static Future<void> _nativeActivate(String mode) =>
      FirebaseAppCheck.instance.activate(
          providerAndroid: mode == 'debug'
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider());
  Future<void> initialize() async {
    if (!configured || _activated) return;
    final pending = _initializing;
    if (pending != null) return pending;
    final operation = _setup();
    _initializing = operation;
    await operation;
    _initializing = null;
  }

  Future<void> _setup() async {
    try {
      await _activate(mode);
      _activated = true;
    } catch (_) {
      _activated = false;
    }
  }

  Future<bool> ensureReady({void Function()? check}) async {
    check?.call();
    await initialize();
    check?.call();
    if (!_activated) return false;
    String? token;
    try {
      token = await _token();
    } catch (_) {
      check?.call();
      return false;
    }
    check?.call();
    return token?.trim().isNotEmpty == true;
  }
}
