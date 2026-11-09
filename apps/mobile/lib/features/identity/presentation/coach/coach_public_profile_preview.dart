import 'package:flutter/material.dart';
import 'package:gainpath_domain/identity.dart';
import '../../../coaching/presentation/shared/coach_profile_screen.dart';
import '../../../coaching/presentation/shared/published_coach_presentation.dart';
import 'coach_account_presentation.dart' show CoachAccountData;

export '../../../coaching/presentation/shared/coach_profile_screen.dart'
    show CoachProfileStat;

/// Coach profile layout, backed by the selected owner/public snapshot.
/// Reuses the unified [CoachProfileScreen] shared with the Member App.
class CoachPublicProfilePreview extends StatelessWidget {
  const CoachPublicProfilePreview(
      {super.key,
      required this.profile,
      required this.data,
      required this.header,
      this.avatar});
  final PublishedCoachProfile profile;
  final CoachAccountData data;
  final Widget header;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    return CoachProfileScreen(
      coach: publishedCoachPresentation(profile),
      published: profile,
      branchNames: data.branchNames,
      previewOnly: true,
      previewRatingUnavailable: data.reviews == null,
      previewHeader: header,
      photo: avatar ??
          (data.photo == null
              ? const Icon(Icons.person,
                  key: Key('preview-photo-fallback'),
                  color: Colors.white70,
                  size: 42)
              : Image(
                  image: data.photo!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stack) => const Icon(
                      Icons.person,
                      key: Key('preview-photo-fallback'),
                      color: Colors.white70,
                      size: 42))),
      sessionsCount: data.sessions,
      reviewsDisplay: data.reviews,
    );
  }
}
