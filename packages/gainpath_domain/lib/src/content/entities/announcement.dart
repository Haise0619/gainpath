/// AD-M11.4 — the data dictionary's `Broadcast` entity: a member-facing
/// announcement with a validity window. [isActive] is computed from
/// [validFrom]/[validTo] against the current time rather than stored,
/// so it can never go stale.
class Announcement {
  final String id;
  final String title;
  final String body;
  final DateTime validFrom;
  final DateTime validTo;
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.validFrom,
    required this.validTo,
  });

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(validFrom) && now.isBefore(validTo);
  }
}
