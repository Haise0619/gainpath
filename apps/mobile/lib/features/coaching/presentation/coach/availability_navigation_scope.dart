import 'package:flutter/widgets.dart';

/// Lets the Coach shell consult the active Availability draft before tab changes.
class AvailabilityNavigationController {
  Future<bool> Function()? beforeLeave;
}

class AvailabilityNavigationScope extends InheritedWidget {
  const AvailabilityNavigationScope(
      {super.key, required this.controller, required super.child});
  final AvailabilityNavigationController controller;
  static AvailabilityNavigationController? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AvailabilityNavigationScope>()
      ?.controller;
  @override
  bool updateShouldNotify(AvailabilityNavigationScope old) =>
      old.controller != controller;
}
