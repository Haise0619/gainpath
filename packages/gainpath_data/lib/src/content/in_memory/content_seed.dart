import 'package:gainpath_domain/content.dart';

/// In-memory seed data for the content feature (frontend prototype).
class ContentSeed {
  /// AD-M11.4 — `Broadcast` records. Previously the Announcements screen
  /// was write-only: a compose form with no way to see what had already
  /// been published or when it stops showing. Mutable so publishing a
  /// new one actually appends here instead of just toasting.
  final announcements = <Announcement>[
    Announcement(
      id: 'an1',
      title: 'Merdeka Day operating hours',
      body:
          '31 August: all branches open 8am-2pm only. Normal hours resume 1 September.',
      validFrom: DateTime.now().subtract(const Duration(days: 2)),
      validTo: DateTime.now().add(const Duration(days: 5)),
    ),
    Announcement(
      id: 'an2',
      title: 'New squat rack at Sungai Petani',
      body:
          'A second squat rack is now installed at the Sungai Petani branch to reduce peak-hour waiting.',
      validFrom: DateTime.now().subtract(const Duration(days: 20)),
      validTo: DateTime.now().subtract(const Duration(days: 6)),
    ),
  ];
}
