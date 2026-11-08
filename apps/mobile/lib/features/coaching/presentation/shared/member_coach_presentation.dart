import 'package:gainpath_domain/identity.dart';
import 'package:flutter/material.dart';

/// Fill Material's unspecified small text slots with the app's member font.
TextTheme memberCoachTypography(BuildContext context) {
  final text = Theme.of(context).textTheme;
  return text.apply(fontFamily: text.bodyMedium?.fontFamily);
}

/// Display only: booking options remain authoritative for price and eligibility.
int? memberCoachFeeMinor(Coach coach, PublishedCoachProfile? published) {
  final minor = published != null
      ? published.fields.consultationFeeMinor
      : (coach.fee * 100).round();
  // The current paid consultation flow requires a positive price.
  return minor != null && minor > 0 ? minor : null;
}

String memberCoachPrice(int? minor) => minor == null
    ? 'Price unavailable'
    : 'RM ${(minor / 100).toStringAsFixed(2)}';

String memberCoachRating(Coach coach, PublishedCoachProfile? published) {
  final count = published?.reviewCount ?? coach.reviews;
  final rating = published != null ? published.averageRating : coach.rating;
  return rating == null || count <= 0
      ? 'Not yet rated'
      : '${rating.toStringAsFixed(1)} · $count ${count == 1 ? 'review' : 'reviews'}';
}

/// Resolve labels supplied by an authorized source; never prettify internal IDs.
String memberCoachLocation(List<String> ids,
    {Map<String, String> branchNames = const {}}) {
  final names = ids
      .map((id) => branchNames[id]?.trim())
      .whereType<String>()
      .where((name) => name.isNotEmpty)
      .toSet()
      .toList();
  return names.isEmpty ? 'Location confirmed when booking' : names.join(' · ');
}
