import 'dart:async';

import 'package:gainpath_domain/gainpath_domain.dart';

class FirebaseAuthUser {
  const FirebaseAuthUser({
    required this.userId,
    required this.email,
    this.displayName,
    this.emailVerified = false,
    this.claims = const {},
  });

  final String userId;
  final String email;
  final String? displayName;
  final bool emailVerified;
  final Map<String, Object?> claims;
}

abstract interface class FirebaseAuthGateway {
  Future<FirebaseAuthUser> signIn({
    required String email,
    required String password,
  });

  Future<FirebaseAuthUser> register({
    required String email,
    required String password,
    required String name,
  });

  Future<void> sendEmailVerification();

  Future<void> signOut();
}

abstract interface class FirebaseAuthSessionGateway {
  Stream<FirebaseAuthUser?> get userChanges;
  Future<FirebaseAuthUser?> restoreUser();
}

/// A reload failed before authoritative identity/membership could be checked.
/// An existing gated session can retry without creating another account.
class FirebaseAuthRefreshUnavailable extends AuthException {
  const FirebaseAuthRefreshUnavailable(super.message);
}

/// Serializes provider mutations and invalidates results immediately on logout.
class FirebaseAuthRepository
    implements AuthRepository, AuthSessionLifecycle, AuthVerificationActions {
  FirebaseAuthRepository(this._gateway) {
    final gateway = _gateway;
    if (gateway is FirebaseAuthSessionGateway) {
      _subscription =
          (gateway as FirebaseAuthSessionGateway).userChanges.listen((user) {
        if (_pending != 0 || _disposed || _signedOut) return;
        try {
          final session = user == null ? null : _sessionFromClaims(user);
          _currentSession = session;
          _changes.add(session);
        } catch (error) {
          _changes.add(null);
          _changes.addError(error);
        }
      }, onError: (Object error) {
        if (_pending == 0 && !_disposed && !_signedOut) {
          _changes.add(null);
          _changes.addError(error);
        }
      });
    }
  }

  final FirebaseAuthGateway _gateway;
  final _changes = StreamController<AuthSession?>.broadcast();
  StreamSubscription<FirebaseAuthUser?>? _subscription;
  Future<void> _tail = Future<void>.value();
  int _revision = 0;
  int _pending = 0;
  bool _signedOut = false;
  bool _disposed = false;
  AuthSession? _currentSession;
  DateTime? _lastVerificationSentAt;

  @override
  Stream<AuthSession?> get sessionChanges => _changes.stream;

  Future<T> _serialize<T>(Future<T> Function() action) {
    _pending++;
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {
      _pending--;
    }, onError: (Object error, StackTrace stack) {
      _pending--;
    });
    return result;
  }

  void _check(int revision) {
    if (_disposed || revision != _revision) {
      throw const AuthException('Authentication cancelled.');
    }
  }

  Future<AuthSession> _authenticate(
      AppRole? role, Future<FirebaseAuthUser> Function() action,
      {bool register = false}) {
    final revision = ++_revision;
    _signedOut = false;
    return _serialize(() async {
      _check(revision);
      try {
        final user = await action();
        _check(revision);
        final session = _sessionFromClaims(user,
            requestedRole: role, requireVerification: register);
        if (_currentSession?.userId != session.userId) {
          _lastVerificationSentAt = null;
        }
        _currentSession = session;
        if (register) {
          try {
            await _sendVerification();
          } catch (_) {
            // Account creation and provisioning have succeeded. Keep the
            // pending session so delivery can be retried without registration.
          }
          _check(revision);
        }
        _changes.add(session);
        return session;
      } catch (error) {
        if (revision == _revision && !_disposed) {
          _signedOut = true;
          _currentSession = null;
          // The login BLoC owns the failure state. A null session here races
          // with its error handler and can hide the failure from the form.
          try {
            await _gateway.signOut();
          } catch (_) {
            // Keep the original authentication error visible.
          }
        }
        if (error is AuthException) rethrow;
        throw const AuthException('Unable to complete authentication.');
      }
    });
  }

  @override
  Future<AuthSession> signIn(
          {AppRole? role, required String email, required String password}) =>
      _authenticate(
          role, () => _gateway.signIn(email: email, password: password));

  @override
  Future<AuthSession> register(
      {required AppRole role,
      required String email,
      required String password,
      required String name}) {
    if (role != AppRole.member) {
      return Future.error(
          const AuthException('Only member self-registration is allowed.'));
    }
    return _authenticate(role,
        () => _gateway.register(email: email, password: password, name: name),
        register: true);
  }

  @override
  Future<AuthSession?> restoreSession() {
    final revision = ++_revision;
    return _serialize(() async {
      _check(revision);
      final gateway = _gateway;
      if (gateway is! FirebaseAuthSessionGateway) return null;
      try {
        final user =
            await (gateway as FirebaseAuthSessionGateway).restoreUser();
        _check(revision);
        final session = user == null ? null : _sessionFromClaims(user);
        final previous = _currentSession;
        if (previous != null &&
            previous.needsVerification &&
            previous == session) {
          // No protected data is mounted yet. Preserve the pending screen so
          // an explicit verification check can display its inline feedback.
          return previous;
        }
        _currentSession = session;
        _signedOut = session == null;
        _changes.add(session);
        return session;
      } catch (error) {
        if (error is FirebaseAuthRefreshUnavailable &&
            revision == _revision &&
            !_disposed &&
            _currentSession != null) {
          rethrow;
        }
        if (revision == _revision && !_disposed) {
          _signedOut = true;
          _currentSession = null;
          _changes.add(null);
          try {
            await _gateway.signOut();
          } catch (_) {
            // Preserve the actionable original session-restoration failure.
          }
        }
        rethrow;
      }
    });
  }

  @override
  Future<void> signOut() {
    ++_revision;
    _signedOut = true;
    _currentSession = null;
    _lastVerificationSentAt = null;
    if (!_disposed) _changes.add(null);
    return _serialize(_gateway.signOut);
  }

  @override
  Future<void> resendEmailVerification() {
    final revision = _revision;
    return _serialize(() async {
      _check(revision);
      await _sendVerification();
      _check(revision);
    });
  }

  Future<void> _sendVerification() async {
    final session = _currentSession;
    if (_signedOut ||
        session == null ||
        session.accountLifecycleState != 'active') {
      throw const AuthException(
          'Sign in again to request a verification link.');
    }
    if (!session.needsVerification) {
      throw const AuthException('Your email is already verified.');
    }
    final lastSent = _lastVerificationSentAt;
    if (lastSent != null &&
        DateTime.now().difference(lastSent).inSeconds < 30) {
      throw const AuthException(
          'Wait 30 seconds before requesting another link.');
    }
    await _gateway.sendEmailVerification();
    _lastVerificationSentAt = DateTime.now();
  }

  AuthSession _sessionFromClaims(FirebaseAuthUser user,
      {AppRole? requestedRole, bool requireVerification = false}) {
    final organizationId = user.claims['organizationId'];
    if (user.userId.trim().isEmpty ||
        organizationId is! String ||
        organizationId.trim().isEmpty) {
      throw const AuthException(
          'This account has no valid user/organization assignment.');
    }
    final rawRole = user.claims['role'];
    final role =
        switch (rawRole is String ? rawRole.trim().toLowerCase() : null) {
      'member' => AppRole.member,
      'coach' => AppRole.coach,
      'admin' || 'staff' || 'branch_staff' => AppRole.admin,
      _ =>
        throw const AuthException('This account has no valid role assignment.'),
    };
    if (requestedRole != null && role != requestedRole) {
      throw const AuthException(
          'This account is not authorized for this application.');
    }
    final rawBranchIds = user.claims['branchIds'];
    if (rawBranchIds is! List ||
        rawBranchIds.any((id) => id is! String || id.trim().isEmpty)) {
      throw const AuthException('This account has no valid branch assignment.');
    }
    final branchIds = List<String>.unmodifiable(rawBranchIds.cast<String>());
    if ((role == AppRole.member || role == AppRole.coach) &&
        branchIds.isEmpty) {
      throw const AuthException('This account has no valid branch assignment.');
    }
    final lifecycle = user.claims['accountLifecycleState'] ?? 'active';
    final membershipStatus = user.claims['status'];
    if (lifecycle != 'active' &&
        !(role == AppRole.member && lifecycle == 'pendingDeletion')) {
      throw const AuthException(
          'This account is unavailable. Contact gym staff.');
    }
    if (membershipStatus != null &&
        membershipStatus !=
            (lifecycle == 'pendingDeletion' ? 'pendingDeletion' : 'active')) {
      throw const AuthException(
          'This account has an unavailable or inconsistent membership. Contact gym staff.');
    }
    return AuthSession(
        userId: user.userId,
        organizationId: organizationId,
        branchIds: branchIds,
        email: user.email,
        displayName: user.displayName,
        role: role,
        accountLifecycleState: lifecycle as String,
        needsVerification: requireVerification || !user.emailVerified);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    ++_revision;
    await _subscription?.cancel();
    await _tail;
    await _changes.close();
  }
}
