import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

/// Cross-feature navigation contracts. Only the application builds destinations.
abstract final class FeatureNavigation {
  static const reachAndTap = '/mini-games/reach-and-tap';
  static const moveAndCatch = '/mini-games/move-and-catch';
  static const equipment = '/equipment/details';
  static const coach = '/coaches/profile';
  static const membership = '/membership';
  static const membershipPlans = '/membership/plans';
  static const workoutPrivacy = '/workout/privacy';
  static const progress = '/progress';
  static const checkout = '/checkout';
}

class CheckoutArguments {
  const CheckoutArguments({required this.amount, required this.description});
  final double amount;
  final String description;
}

class WorkoutPrivacyArguments {
  const WorkoutPrivacyArguments({
    required this.scope,
    required this.isCurrent,
  });

  final SessionScope scope;
  final bool Function() isCurrent;
}
