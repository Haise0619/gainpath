/// BR: a charge may be disputed only within [windowDays] of the charge date.
class RefundPolicy {
  const RefundPolicy({this.windowDays = defaultWindowDays});

  static const defaultWindowDays = 7;
  final int windowDays;

  bool isEligible(DateTime chargedAt, {DateTime? now}) =>
      (now ?? DateTime.now()).difference(chargedAt).inDays <= windowDays;
}
