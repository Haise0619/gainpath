class OrganizationId {
  const OrganizationId(this.value) : assert(value != '');
  final String value;

  @override
  bool operator ==(Object other) =>
      other is OrganizationId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

class BranchId {
  const BranchId(this.value) : assert(value != '');
  final String value;

  @override
  bool operator ==(Object other) => other is BranchId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

class UserId {
  const UserId(this.value) : assert(value != '');
  final String value;

  @override
  bool operator ==(Object other) => other is UserId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

class Money {
  const Money({
    required this.minorUnits,
    required this.currency,
  });

  final int minorUnits;
  final String currency;

  @override
  String toString() {
    final absolute = minorUnits.abs();
    final major = absolute ~/ 100;
    final minor = (absolute % 100).toString().padLeft(2, '0');
    final sign = minorUnits < 0 ? '-' : '';
    return '$sign$currency $major.$minor';
  }
}
