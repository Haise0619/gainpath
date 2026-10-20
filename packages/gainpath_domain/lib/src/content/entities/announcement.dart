/// AD-M11.4 — the data dictionary's `Broadcast` entity: a member-facing
/// announcement with a validity window. [isActive] is computed from
/// [validFrom]/[validTo] against the current time rather than stored,
/// so it can never go stale.
enum AnnouncementStatus { draft, published, inactive }

abstract class AnnouncementEditBaseline {}

class Announcement {
  final String id;
  final String title;
  final String body;
  final DateTime validFrom;
  final DateTime validTo;
  final AnnouncementStatus status;
  final int revision;
  final AnnouncementEditBaseline? editBaseline;
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.validFrom,
    required this.validTo,
    this.status = AnnouncementStatus.published,
    this.revision = 0,
    this.editBaseline,
  });

  bool get isActive {
    final now = DateTime.now();
    return status == AnnouncementStatus.published &&
        !now.isBefore(validFrom) &&
        now.isBefore(validTo);
  }

  void validate() {
    if (title.trim().isEmpty ||
        title.trim().length > 120 ||
        body.trim().isEmpty ||
        body.trim().length > 4000 ||
        !validTo.isAfter(validFrom)) {
      throw const FormatException(
          'Use a title (1–120 characters), message (1–4000), and an end after the start.');
    }
  }

  Announcement copyWith(
          {String? title,
          String? body,
          DateTime? validFrom,
          DateTime? validTo,
          AnnouncementStatus? status}) =>
      Announcement(
          id: id,
          title: title ?? this.title,
          body: body ?? this.body,
          validFrom: validFrom ?? this.validFrom,
          validTo: validTo ?? this.validTo,
          status: status ?? this.status,
          revision: revision,
          editBaseline: editBaseline);
}
