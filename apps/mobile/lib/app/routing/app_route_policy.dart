import 'package:gainpath_domain/gainpath_domain.dart' show AppRole;
import 'package:gainpath_identity/gainpath_identity.dart';

class AppRoutePolicy {
  const AppRoutePolicy._();

  static bool canEnterShell({
    required AuthState auth,
    required AppRole requiredRole,
  }) =>
      AuthRolePolicy.canEnter(auth, allowed: {requiredRole});
}
