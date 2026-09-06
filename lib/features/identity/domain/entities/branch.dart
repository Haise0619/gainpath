/// A physical facility location, per the data dictionary's `Branch`
/// entity. Every `Coach.branch` / `Booking.branch` string is expected to
/// match one of these `name` values.
class Branch {
  final String id;
  final String name;
  final String address;
  final String contactPhone;
  final bool isActive;
  const Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.contactPhone,
    required this.isActive,
  });
}
