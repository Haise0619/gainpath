import 'package:flutter/foundation.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

abstract interface class WorkoutPreferencesStore {
  Future<Map<String, Object?>?> read();
  Future<void> write(Map<String, Object?> value);
}

/// Local device preferences, separate from workout evidence and backup.
class WorkoutPreferencesController extends ChangeNotifier {
  WorkoutPreferencesController(
      {required this.scope,
      required this.store,
      this.requiredConsentVersion = consentVersion,
      DateTime Function()? utcNow})
      : _utcNow = utcNow ?? (() => DateTime.now().toUtc());
  static const consentVersion = '1';
  final SessionScope scope;
  final WorkoutPreferencesStore store;
  final String requiredConsentVersion;
  final DateTime Function() _utcNow;
  String? _acceptedVersion;
  DateTime? acceptedAt;
  bool loaded = false;
  bool autoContinue = true;
  bool _autoContinueBetweenSets = false;
  int suggestedRestSeconds = 30;
  String? error;
  int _consentEpoch = 0, _writes = 0;
  bool _disposed = false;
  bool _denyLoadedConsent = false;
  Future<void>? _loading;
  Future<void> _pending = Future.value();
  bool get busy => _writes > 0;
  bool get autoContinueBetweenSets => _autoContinueBetweenSets;
  bool get validConsent =>
      loaded &&
      _acceptedVersion == requiredConsentVersion &&
      acceptedAt != null;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    final epoch = _consentEpoch;
    try {
      final value = await store.read();
      if (value != null &&
          value['schemaVersion'] == 1 &&
          value['organizationId'] == scope.organizationId &&
          value['userId'] == scope.userId) {
        final rest = value['suggestedRestSeconds'];
        if (value['autoContinue'] is bool) {
          autoContinue = value['autoContinue'] as bool;
        }
        _autoContinueBetweenSets = value['autoContinueBetweenSets'] == true;
        if (rest is int && rest >= 0 && rest <= 300) {
          suggestedRestSeconds = rest;
        }
        if (epoch == _consentEpoch && !_denyLoadedConsent) {
          final rawDate = value['acceptedAt'];
          final date = rawDate is String ? DateTime.tryParse(rawDate) : null;
          if (value['consentVersion'] is String && date != null) {
            _acceptedVersion = value['consentVersion'] as String;
            acceptedAt = date.toUtc();
          }
        }
      }
    } catch (_) {
      error =
          'Could not read local workout preferences. AI Tracking remains off until consent is saved.';
    }
    loaded = true;
    _notify();
  }

  Map<String, Object?> _json() => {
        'schemaVersion': 1,
        'organizationId': scope.organizationId,
        'userId': scope.userId,
        'consentVersion': _acceptedVersion,
        'acceptedAt': acceptedAt?.toIso8601String(),
        'autoContinue': autoContinue,
        'autoContinueBetweenSets': autoContinueBetweenSets,
        'suggestedRestSeconds': suggestedRestSeconds,
      };

  Future<void> _write(Future<void> Function() operation) {
    _writes++;
    error = null;
    _notify();
    final result = _pending.then((_) => operation());
    _pending = result.catchError((Object _) {});
    return result.catchError((Object exception) {
      error =
          'This change could not be saved on this device. Please retry before leaving.';
      throw exception;
    }).whenComplete(() {
      _writes--;
      _notify();
    });
  }

  Future<void> grantConsent() async {
    final epoch = ++_consentEpoch;
    await load();
    if (epoch != _consentEpoch) return;
    final accepted = _utcNow().toUtc();
    await _write(() async {
      // A withdrawal queued while this operation waited wins.
      if (epoch != _consentEpoch) return;
      await store.write({
        ..._json(),
        'consentVersion': requiredConsentVersion,
        'acceptedAt': accepted.toIso8601String()
      });
      if (epoch == _consentEpoch) {
        _acceptedVersion = requiredConsentVersion;
        acceptedAt = accepted;
      }
    });
  }

  Future<void> withdrawConsent() {
    ++_consentEpoch;
    _denyLoadedConsent = true;
    _acceptedVersion = null;
    acceptedAt = null;
    _notify(); // Capture listeners must stop before the disk operation finishes.
    return _persistWithdrawal();
  }

  Future<void> _persistWithdrawal() async {
    // Preserve other saved preferences even when withdrawal happens at startup.
    await load();
    await _write(() => store.write(_json()));
  }

  Future<void> updatePreferences(
      {bool? autoContinue,
      bool? autoContinueBetweenSets,
      int? suggestedRestSeconds}) async {
    if (suggestedRestSeconds != null &&
        (suggestedRestSeconds < 0 || suggestedRestSeconds > 300)) {
      throw ArgumentError.value(suggestedRestSeconds, 'suggestedRestSeconds');
    }
    await load();
    await _write(() async {
      await store.write({
        ..._json(),
        'autoContinue': autoContinue ?? this.autoContinue,
        'autoContinueBetweenSets':
            autoContinueBetweenSets ?? _autoContinueBetweenSets,
        'suggestedRestSeconds':
            suggestedRestSeconds ?? this.suggestedRestSeconds
      });
      this.autoContinue = autoContinue ?? this.autoContinue;
      _autoContinueBetweenSets =
          autoContinueBetweenSets ?? _autoContinueBetweenSets;
      this.suggestedRestSeconds =
          suggestedRestSeconds ?? this.suggestedRestSeconds;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
