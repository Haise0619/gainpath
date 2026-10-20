import 'package:gainpath_domain/identity.dart';

/// Presentation-only projection. Unknown metrics are marked by the widgets.
Coach publishedCoachPresentation(PublishedCoachProfile value) => Coach(
      id: value.id,
      name: value.fields.displayName,
      specialty: value.fields.specialty,
      specializationTags: value.fields.specializationTags,
      rating: 0,
      reviews: 0,
      bio: value.fields.bio.isEmpty ? '-' : value.fields.bio,
      verified: value.certificationVerified,
      imageUrl: '',
      branch: value.branchIds.isEmpty ? '-' : value.branchIds.join(', '),
      fee: (value.fields.consultationFeeMinor ?? 0) / 100,
      yearsExperience: value.fields.yearsExperience ?? 0,
      sessionsCompleted: 0,
      responseTime: '-',
      topReviews: [],
    );
