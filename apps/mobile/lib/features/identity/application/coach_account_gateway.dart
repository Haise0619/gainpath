import 'dart:math';
import 'dart:typed_data';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';

String newCoachRequestId() {
  final random = Random.secure();
  return List.generate(
      16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

class CoachCertificationSummary {
  const CoachCertificationSummary(
      {required this.approved, this.pending, required this.verified});
  final int approved;
  final int? pending;
  final bool verified;
}

class CoachCertificationDetail {
  const CoachCertificationDetail(this.certification, this.history);
  final PrivateCoachCertification certification;
  final List<Map<String, dynamic>> history;
}

class CoachAccountMetrics {
  const CoachAccountMetrics(
      {this.branch,
      this.rating,
      this.sessions,
      this.reviews,
      this.branchNames = const {}});
  final String? branch;
  final double? rating;
  final int? sessions, reviews;
  final Map<String, String> branchNames;
  factory CoachAccountMetrics.fromJson(
      Map<String, dynamic> data, String coachId) {
    final records = data['records'], summary = data['accountSummary'];
    if (data['schemaVersion'] != 1 ||
        records is! List ||
        records.length != 1 ||
        records.single is! Map ||
        summary is! Map) {
      throw const FormatException('Invalid account summary.');
    }
    final r = records.single as Map,
        count = r['reviewCount'],
        rating = r['averageRating'],
        sessions = summary['completedSessions'],
        branches = summary['branches'];
    if (r['coachId'] != coachId ||
        count is! int ||
        count < 0 ||
        sessions is! int ||
        sessions < 0 ||
        branches is! List ||
        (count == 0
            ? rating != null
            : rating is! num || !rating.isFinite || rating < 1 || rating > 5)) {
      throw const FormatException('Invalid account statistics.');
    }
    final names = <String, String>{};
    for (final b in branches) {
      if (b is! Map ||
          b['id'] is! String ||
          (b['name'] != null && b['name'] is! String)) {
        throw const FormatException('Invalid branch.');
      }
      if (b['name'] is String && (b['name'] as String).trim().isNotEmpty) {
        names[b['id'] as String] = (b['name'] as String).trim();
      }
    }
    return CoachAccountMetrics(
        branch: names.isEmpty
            ? 'No branch name available'
            : names.values.join(' · '),
        rating: (rating as num?)?.toDouble(),
        sessions: sessions,
        reviews: count,
        branchNames: Map.unmodifiable(names));
  }
}

abstract interface class CoachAccountMetricsSource {
  Future<CoachAccountMetrics> loadMetrics();
}

/// Data/capabilities only. Every backend uses the same Module 8 screen classes.
abstract interface class CoachAccountGateway {
  SessionScope get scope;
  bool Function() get isCurrent;
  String get email;
  String? get publicAvatarUrl;
  bool get passwordManagementAvailable;
  CoachAccountMetrics get metrics;
  void check();
  Future<void> verifyCurrentPassword(String password);
  Future<void> changePassword(String password);
  Future<CoachAccountSettings> loadSettings();
  Future<CoachAccountSettings> saveSettings(
      CoachAccountSettings baseline,
      String phone,
      bool bookings,
      bool cancellations,
      bool reminders,
      String requestId);
  Future<CoachCertificationSummary> loadCertificationSummary();
  Future<List<PrivateCoachCertification>> loadCertifications({String? afterId});
  String? get certificationCursor;
  Future<CoachCertificationDetail> loadCertificationDetail(String id);
  Future<void> submitCertification(
      String id, String title, String issuer, String path, String requestId);
  Future<void> archive(
      PrivateCoachCertification certification, String requestId);
  Future<String> upload(
      String collection, String id, Uint8List bytes, String contentType);
  Future<Uint8List> read(String path);
  Future<Uint8List?> loadProfilePhoto(String? path);
}

String coachCertificationStatus(String value) => switch (value) {
      'pending' => 'Pending review',
      'approved' => 'Verified',
      'rejected' => 'Rejected',
      'archived' => 'Archived',
      _ => 'Unavailable',
    };
