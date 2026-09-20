/// Cross-feature navigation contracts. Only the application builds destinations.
abstract final class FeatureNavigation {
  static const equipment = '/equipment/details';
  static const coach = '/coaches/profile';
  static const membership = '/membership';
  static const progress = '/progress';
  static const checkout = '/checkout';
}

class CheckoutArguments {
  const CheckoutArguments({required this.amount, required this.description});
  final double amount;
  final String description;
}
