/// AD-M11.4 — the data dictionary's `Broadcast` entity: a member-facing
/// announcement with a validity window. [isActive] is computed from
/// [validFrom]/[validTo] against the current time rather than stored,
/// so it can never go stale.
enum AnnouncementStatus { draft, published, inactive }

enum AnnouncementDisplayStatus {
  draft,
  scheduled,
  active,
  expired,
  deactivated
}

enum AnnouncementCategory {
  general,
  maintenance,
  closure,
  promotion,
  event,
  update
}

enum AnnouncementPriority { normal, important }

enum AnnouncementAudience { all, branches }

abstract class AnnouncementEditBaseline {}

class Announcement {
  final String id;
  final String title;
  final String body;
  final DateTime validFrom;
  final DateTime validTo;
  final AnnouncementStatus status;
  final AnnouncementCategory category;
  final AnnouncementPriority priority;
  final AnnouncementAudience audience;
  final List<String> targetBranchIds;
  final List<String> targetBranchNames;
  final int revision;
  final AnnouncementEditBaseline? editBaseline;
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.validFrom,
    required this.validTo,
    this.status = AnnouncementStatus.published,
    this.category = AnnouncementCategory.general,
    this.priority = AnnouncementPriority.normal,
    this.audience = AnnouncementAudience.all,
    this.targetBranchIds = const [],
    this.targetBranchNames = const [],
    this.revision = 0,
    this.editBaseline,
  });

  bool get isActive =>
      displayStatusAt(DateTime.now()) == AnnouncementDisplayStatus.active;

  AnnouncementDisplayStatus displayStatusAt(DateTime now) => switch (status) {
        AnnouncementStatus.draft => AnnouncementDisplayStatus.draft,
        AnnouncementStatus.inactive => AnnouncementDisplayStatus.deactivated,
        AnnouncementStatus.published when now.isBefore(validFrom) =>
          AnnouncementDisplayStatus.scheduled,
        AnnouncementStatus.published when !now.isBefore(validTo) =>
          AnnouncementDisplayStatus.expired,
        AnnouncementStatus.published => AnnouncementDisplayStatus.active,
      };

  void validate() {
    if (title.trim().length > 120 ||
        body.trim().length > 4000 ||
        (status != AnnouncementStatus.draft &&
            (title.trim().isEmpty ||
                body.trim().isEmpty ||
                !validTo.isAfter(validFrom)))) {
      throw const FormatException(
          'Use a title (1–120 characters), message (1–4000), and an end after the start.');
    }
    if (targetBranchIds.length > 8 ||
        (audience == AnnouncementAudience.all && targetBranchIds.isNotEmpty) ||
        (audience == AnnouncementAudience.branches &&
            status != AnnouncementStatus.draft &&
            targetBranchIds.isEmpty)) {
      throw const FormatException(
          'Select between 1 and 8 branches to publish.');
    }
  }

  String get audienceLabel => audience == AnnouncementAudience.all
      ? 'All branches'
      : targetBranchNames.isEmpty
          ? 'Specific branches'
          : targetBranchNames.join(', ');

  Announcement copyWith(
          {String? title,
          String? body,
          DateTime? validFrom,
          DateTime? validTo,
          AnnouncementStatus? status,
          AnnouncementCategory? category,
          AnnouncementPriority? priority,
          AnnouncementAudience? audience,
          List<String>? targetBranchIds}) =>
      Announcement(
          id: id,
          title: title ?? this.title,
          body: body ?? this.body,
          validFrom: validFrom ?? this.validFrom,
          validTo: validTo ?? this.validTo,
          status: status ?? this.status,
          category: category ?? this.category,
          priority: priority ?? this.priority,
          audience: audience ?? this.audience,
          targetBranchIds: targetBranchIds ?? this.targetBranchIds,
          targetBranchNames: targetBranchNames,
          revision: revision,
          editBaseline: editBaseline);
}
