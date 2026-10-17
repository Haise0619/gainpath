import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'firebase_app_check_readiness.dart';
import 'firebase_password_actions.dart';

typedef MemberLifecycleCallable = Future<Map<String, dynamic>> Function(
    String, Map<String, dynamic>);

class FirebaseMemberAccountLifecycleRepository
    implements MemberAccountLifecycleRepository {
  FirebaseMemberAccountLifecycleRepository(
      {required this.scope,
      required this.isCurrent,
      FirebaseAppCheckReadiness? readiness,
      String? Function()? currentUid,
      MemberLifecycleCallable? call,
      Future<void> Function(String)? verifyCurrentPassword})
      : _readiness = readiness ?? FirebaseAppCheckReadiness.instance,
        _uid = currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
        _call = call ??
            ((name, data) async => (await FirebaseFunctions.instance
                    .httpsCallable(name)
                    .call<Map<String, dynamic>>(data))
                .data),
        _verify = verifyCurrentPassword ??
            ((password) =>
                FirebasePasswordActions(scope: scope).verifyCurrent(password));
  final SessionScope scope;
  final bool Function() isCurrent;
  final FirebaseAppCheckReadiness _readiness;
  final String? Function() _uid;
  final MemberLifecycleCallable _call;
  final Future<void> Function(String) _verify;
  final Object _lifetime = Object();
  bool _invalidated = false;
  _PendingCommand? _pending;
  void _check() {
    if (_invalidated || !isCurrent() || _uid() != scope.userId) {
      _invalidated = true;
      throw const MemberAccountLifecycleException(
          'Your session changed. Sign in again.');
    }
  }

  Future<void> _ready() async {
    _check();
    if (!await _readiness.ensureReady(check: _check)) {
      throw const MemberAccountLifecycleException(
          'Account security verification is unavailable on this build. Please use the configured Android app.');
    }
    _check();
  }

  Future<MemberAccountLifecycle> _invoke(
      String name, Map<String, dynamic> data) async {
    _check();
    final response =
        await _call(name, data).timeout(const Duration(seconds: 35));
    _check();
    return MemberAccountLifecycle.fromJson(response, editBaseline: _lifetime);
  }

  MemberAccountLifecycleException _error(Object error,
      {bool uncertain = false}) {
    if (error is MemberAccountLifecycleException) return error;
    if (error is AuthException) {
      return MemberAccountLifecycleException(error.message);
    }
    if (error is FirebaseFunctionsException) {
      return MemberAccountLifecycleException(
          switch (error.code) {
            'unauthenticated' =>
              'Confirm your password again. If your session expired, sign out and sign in again.',
            'permission-denied' =>
              'Account access changed. Sign out and sign in again.',
            'aborted' ||
            'already-exists' =>
              'Account status changed. Reload before trying again.',
            'failed-precondition' =>
              'This account change is unavailable. Reload the current account status.',
            'not-found' ||
            'unimplemented' =>
              'Account lifecycle is not available on this server yet.',
            _ =>
              'Account change was not confirmed. Reload account status before retrying.',
          },
          uncertain: uncertain);
    }
    return MemberAccountLifecycleException(
        'Account change was not confirmed. Check your connection and reload account status before retrying.',
        uncertain: uncertain);
  }

  @override
  Future<MemberAccountLifecycle> load() async {
    await _ready();
    try {
      final result = await _invoke(
          'getMemberAccountLifecycleCommand', {'schemaVersion': 1});
      if (_pending != null && result.revision != _pending!.revision) {
        _pending = null;
      }
      return result;
    } catch (error) {
      _check();
      throw _error(error);
    }
  }

  @override
  Future<void> verifyCurrentPassword(String password) async {
    _check();
    if (password.isEmpty) {
      throw const MemberAccountLifecycleException(
          'Enter your current password.');
    }
    try {
      await _verify(password);
      _check();
    } catch (error) {
      _check();
      throw _error(error);
    }
  }

  @override
  Future<MemberAccountLifecycle> requestDeactivation(
          MemberAccountLifecycle original) =>
      _transition(original, false);
  @override
  Future<MemberAccountLifecycle> cancelDeactivation(
          MemberAccountLifecycle original) =>
      _transition(original, true);
  Future<MemberAccountLifecycle> _transition(
      MemberAccountLifecycle original, bool restore) async {
    _check();
    if (!identical(original.editBaseline, _lifetime)) {
      throw const MemberAccountLifecycleException(
          'Reload account status before continuing.');
    }
    if (restore ? !original.reactivationAllowed : original.isPendingDeletion) {
      throw const MemberAccountLifecycleException(
          'Reload the current account status before continuing.');
    }
    await _ready();
    var pending = _pending;
    if (pending == null) {
      final random = Random.secure();
      final id = List.generate(
              16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
          .join();
      pending = _PendingCommand(id, original.revision, restore);
      _pending = pending;
    } else if (pending.revision != original.revision ||
        pending.restore != restore) {
      throw const MemberAccountLifecycleException(
          'A previous account change is unconfirmed. Reload account status before continuing.',
          uncertain: true);
    }
    final command = {
      'schemaVersion': 1,
      'requestId': pending.id,
      'expectedRevision': pending.revision
    };
    final name = restore
        ? 'cancelMemberDeactivationCommand'
        : 'requestMemberDeactivationCommand';
    try {
      final result = await _invoke(name, command);
      if (!_confirmed(result, pending)) {
        throw const FormatException('Unconfirmed account command.');
      }
      _pending = null;
      return result;
    } catch (error) {
      _check();
      try {
        final actual = await _invoke(
            'getMemberAccountLifecycleCommand', {'schemaVersion': 1});
        if (_confirmed(actual, pending)) {
          _pending = null;
          return actual;
        }
      } catch (_) {
        _check();
      }
      throw _error(error, uncertain: true);
    }
  }

  bool _confirmed(MemberAccountLifecycle value, _PendingCommand pending) =>
      value.revision == pending.revision + 1 &&
      value.lastRequestId == pending.id &&
      value.isPendingDeletion != pending.restore;
}

class _PendingCommand {
  const _PendingCommand(this.id, this.revision, this.restore);
  final String id;
  final int revision;
  final bool restore;
}
