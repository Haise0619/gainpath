import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/app/di/catalog_edit_session_guard.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';

const original = AuthSession(
    userId: 'a',
    organizationId: 'o',
    email: 'a@example.test',
    role: AppRole.admin);
void main() {
  for (final next in [
    const AuthState(status: AuthStatus.signedOut),
    const AuthState(
        status: AuthStatus.signedIn,
        session: AuthSession(
            userId: 'b',
            organizationId: 'o',
            email: 'a@example.test',
            role: AppRole.admin)),
    const AuthState(
        status: AuthStatus.signedIn,
        session: AuthSession(
            userId: 'a',
            organizationId: 'other',
            email: 'a@example.test',
            role: AppRole.admin)),
    const AuthState(
        status: AuthStatus.signedIn,
        session: AuthSession(
            userId: 'a',
            organizationId: 'o',
            email: 'a@example.test',
            role: AppRole.coach)),
    const AuthState(status: AuthStatus.needsVerification, session: original),
  ]) {
    test(
        'session boundary invalidates permanently: ${next.status}/${next.session?.scope}',
        () async {
      final stream = StreamController<AuthState>(sync: true);
      const valid = AuthState(status: AuthStatus.signedIn, session: original);
      var current = valid;
      final guard = CatalogEditSessionGuard(
          expected: original, current: () => current, changes: stream.stream);
      expect(guard.isCurrent(), isTrue);
      current = next;
      stream.add(next);
      expect(guard.isCurrent(), isFalse);
      current = valid;
      stream.add(valid);
      expect(guard.isCurrent(), isFalse);
      guard.dispose();
      await stream.close();
    });
  }
  test('disposal closes repository authorization even if session remains',
      () async {
    final stream = StreamController<AuthState>();
    final guard = CatalogEditSessionGuard(
        expected: original,
        current: () =>
            const AuthState(status: AuthStatus.signedIn, session: original),
        changes: stream.stream);
    expect(guard.isCurrent(), isTrue);
    guard.dispose();
    expect(guard.isCurrent(), isFalse);
    await stream.close();
  });
}
