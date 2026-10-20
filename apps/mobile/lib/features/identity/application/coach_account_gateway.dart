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
      {this.branch, this.rating, this.sessions, this.reviews});
  final String? branch;
  final double? rating;
  final int? sessions, reviews;
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
