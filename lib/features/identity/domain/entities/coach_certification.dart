import 'package:gainpath/features/identity/domain/enums/certification_status.dart';

/// AD-M8.3 — a certification document a coach uploads for gym-staff
/// verification. [status] is one of Verified / Pending review / Rejected;
/// [rejectionReason] is set only when rejected. Mutable + stored in a
/// mutable list so uploading actually adds a Pending entry the coach can
/// then see, matching the CertificationDocument entity in the data
/// dictionary (without a backend behind it).
class CoachCertification {
  final String name;
  CertificationStatus status;
  final DateTime uploadedAt;
  final String? rejectionReason;
  CoachCertification(this.name, this.status, this.uploadedAt, {this.rejectionReason});
}
