import 'package:gainpath_domain/identity.dart';

/// Published profiles use the same authorized aggregate as Member discovery.
/// Inactive profiles are excluded because the ratings command rejects them.
Future<List<PublishedCoachProfile>> loadAdminCoachRatings(
    List<PublishedCoachProfile> profiles,
    Future<Map<String, dynamic>> Function(List<String>) read) async {
  final ids = profiles.where((p) => p.isPublished).map((p) => p.id).toList();
  if (ids.isEmpty) return profiles;
  final response = await read(ids);
  if (response['schemaVersion'] != 1 || response['records'] is! List) {
    throw const CoachRepositoryException('invalid-response');
  }
  final records = <String, Map>{};
  for (final record in response['records'] as List) {
    if (record is! Map ||
        record['coachId'] is! String ||
        !ids.contains(record['coachId']) ||
        records.containsKey(record['coachId'])) {
      throw const CoachRepositoryException('invalid-response');
    }
    records[record['coachId'] as String] = record;
  }
  return profiles.map((profile) {
    if (!profile.isPublished) return profile;
    final record = records[profile.id];
    final count = record?['reviewCount'];
    final average = record?['averageRating'];
    if (count is! int ||
        count < 0 ||
        (count == 0
            ? average != null
            : average is! num ||
                !average.isFinite ||
                average < 1 ||
                average > 5)) {
      throw const CoachRepositoryException('invalid-response');
    }
    return profile.withRatings((average as num?)?.toDouble(), count);
  }).toList();
}
