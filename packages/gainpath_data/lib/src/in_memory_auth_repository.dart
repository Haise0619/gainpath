import 'dart:async';
import 'dart:convert';
import 'package:gainpath_domain/gainpath_domain.dart';

class InMemoryAuthRepository implements AuthRepository, AuthSessionLifecycle {
  InMemoryAuthRepository({this.organizationId = 'demo-org'});
  final String organizationId;
  final _changes = StreamController<AuthSession?>.broadcast();
  AuthSession? _session;

  @override
  Stream<AuthSession?> get sessionChanges => _changes.stream;
  @override
  Future<AuthSession?> restoreSession() async => _session;

  AuthSession _authenticate(AppRole role, String email,
      {bool registering = false}) {
    final normalized = email.trim().toLowerCase();
    final session = AuthSession(
      userId: 'fake-${base64Url.encode(utf8.encode(normalized))}',
      organizationId: organizationId,
      email: normalized,
      role: role,
      needsVerification: registering && role == AppRole.member,
    );
    session.scope;
    _session = session;
    _changes.add(session);
    return session;
  }

  @override
  Future<AuthSession> signIn(
          {required AppRole role,
          required String email,
          required String password}) async =>
      _authenticate(role, email);
  @override
  Future<AuthSession> register(
          {required AppRole role,
          required String email,
          required String password,
          required String name}) async =>
      _authenticate(role, email, registering: true);
  @override
  Future<void> signOut() async {
    _session = null;
    _changes.add(null);
  }

  @override
  Future<void> dispose() => _changes.close();

  /// Explicit prototype action. Never exposed by a real Firebase repository.
  Future<void> verifyEmailForDemo() async {
    final current = _session;
    if (current == null) throw StateError('No demo session to verify.');
    _session = AuthSession(userId: current.userId, organizationId: current.organizationId,
      email: current.email, role: current.role);
    _changes.add(_session);
  }
}
