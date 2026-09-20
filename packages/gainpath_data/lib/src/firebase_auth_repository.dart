import 'dart:async';

import 'package:gainpath_domain/gainpath_domain.dart';

class FirebaseAuthUser {
  const FirebaseAuthUser({
    required this.userId,
    required this.email,
    this.emailVerified = false,
    this.claims = const {},
  });

  final String userId;
  final String email;
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

/// Serializes provider mutations and invalidates results immediately on logout.
class FirebaseAuthRepository implements AuthRepository, AuthSessionLifecycle {
  FirebaseAuthRepository(this._gateway) {
    final gateway = _gateway;
    if (gateway is FirebaseAuthSessionGateway) {
      _subscription =
          (gateway as FirebaseAuthSessionGateway).userChanges.listen((user) {
        if (_pending != 0 || _disposed || (_signedOut && user != null)) return;
        try {
          final session = user == null ? null : _sessionFromClaims(user);
          _changes.add(session);
        } catch (error) {
          _changes.add(null);
          _changes.addError(error);
        }
      }, onError: (Object error) {
        if (!_disposed) {
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
      AppRole role, Future<FirebaseAuthUser> Function() action,
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
        if (register) {
          await _gateway.sendEmailVerification();
          _check(revision);
        }
        _changes.add(session);
        return session;
      } catch (error) {
        if (revision == _revision && !_disposed) {
          _signedOut = true;
          _changes.add(null);
          await _gateway.signOut();
        }
        if (error is AuthException) rethrow;
        throw const AuthException('Unable to complete authentication.');
      }
    });
  }

  @override
  Future<AuthSession> signIn(
          {required AppRole role,
          required String email,
          required String password}) =>
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
        _signedOut = session == null;
        _changes.add(session);
        return session;
      } catch (error) {
        if (revision == _revision && !_disposed) {
          _signedOut = true;
          _changes.add(null);
          await _gateway.signOut();
        }
        rethrow;
      }
    });
  }

  @override
  Future<void> signOut() {
    ++_revision;
    _signedOut = true;
    if (!_disposed) _changes.add(null);
    return _serialize(_gateway.signOut);
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
    return AuthSession(
        userId: user.userId,
        organizationId: organizationId,
        email: user.email,
        role: role,
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
