import 'dart:async';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';

/// A repository lifetime cannot become authorized again after session drift.
class CatalogEditSessionGuard {
  CatalogEditSessionGuard(
      {required this.expected,
      required AuthState Function() current,
      required Stream<AuthState> changes})
      : _current = current {
    _subscription = changes.listen((state) {
      if (!_matches(state)) _invalidated = true;
    });
  }
  final AuthSession expected;
  final AuthState Function() _current;
  late final StreamSubscription<AuthState> _subscription;
  bool _invalidated = false;
  bool _matches(AuthState state) =>
      state.status == AuthStatus.signedIn &&
      state.session == expected &&
      expected.role == AppRole.admin &&
      !expected.needsVerification;
  bool isCurrent() {
    if (!_matches(_current())) _invalidated = true;
    return !_invalidated;
  }

  void dispose() {
    _invalidated = true;
    unawaited(_subscription.cancel());
  }
}
