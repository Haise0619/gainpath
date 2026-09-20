import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/app/routing/app_route_policy.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AppRole, AuthSession;
import 'package:gainpath_identity/gainpath_identity.dart';

void main() {
  test('only a signed-in user with the matching role can enter a shell route',
      () {
    expect(
      AppRoutePolicy.canEnterShell(
        auth:
            const AuthState(status: AuthStatus.signedIn, role: AppRole.member,
              session: AuthSession(email: 'member@example.com', role: AppRole.member)),
        requiredRole: AppRole.member,
      ),
      isTrue,
    );
    expect(
      AppRoutePolicy.canEnterShell(
        auth: const AuthState(status: AuthStatus.signedIn, role: AppRole.coach),
        requiredRole: AppRole.member,
      ),
      isFalse,
    );
    expect(
      AppRoutePolicy.canEnterShell(
        auth:
            const AuthState(status: AuthStatus.signedOut, role: AppRole.member),
        requiredRole: AppRole.member,
      ),
      isFalse,
    );
  });
}
