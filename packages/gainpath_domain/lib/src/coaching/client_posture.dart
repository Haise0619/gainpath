import 'booking_wire_validation.dart' as wire;

class ClientPostureRequest {
  const ClientPostureRequest({
    required this.organizationId,
    required this.memberId,
  });

  final String organizationId;
  final String memberId;

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'organizationId': organizationId,
        'memberId': memberId,
      };

  factory ClientPostureRequest.fromJson(Map<String, dynamic> data) {
    wire.bookingShape(data, ['schemaVersion', 'organizationId', 'memberId']);
    wire.bookingVersion(data['schemaVersion']);
    return ClientPostureRequest(
      organizationId: wire.bookingId(data['organizationId']),
      memberId: wire.bookingId(data['memberId']),
    );
  }
}

class ClientPostureSession {
  const ClientPostureSession({
    required this.sessionId,
    required this.exerciseId,
    required this.completedAtMillis,
    required this.overallScore,
  });

  final String sessionId;
  final String exerciseId;
  final int completedAtMillis;
  final int overallScore;

  factory ClientPostureSession.fromJson(Map<String, dynamic> data) {
    wire.bookingShape(
        data, ['sessionId', 'exerciseId', 'completedAtMillis', 'overallScore']);
    return ClientPostureSession(
      sessionId: wire.bookingId(data['sessionId']),
      exerciseId: wire.bookingId(data['exerciseId']),
      completedAtMillis: wire.bookingInt(data['completedAtMillis']),
      overallScore: wire.bookingInt(data['overallScore'], min: 0, max: 100),
    );
  }
}

class ClientPostureResult {
  const ClientPostureResult({
    required this.memberId,
    required this.authorized,
    required this.sharingStatus,
    required this.measurementsStatus,
    required this.message,
    required this.sessions,
  });

  final String memberId;
  final bool authorized;
  final String sharingStatus;
  final String measurementsStatus;
  final String message;
  final List<ClientPostureSession> sessions;

  factory ClientPostureResult.fromJson(
    Map<String, dynamic> data, {
    required String expectedMemberId,
  }) {
    wire.bookingShape(data, [
      'schemaVersion',
      'memberId',
      'authorized',
      'sharingStatus',
      'measurementsStatus',
      'message',
      'sessions',
    ]);
    wire.bookingVersion(data['schemaVersion']);
    if (wire.bookingId(data['memberId']) != expectedMemberId ||
        data['authorized'] is! bool ||
        data['sessions'] is! List) {
      wire.invalidBookingData();
    }
    return ClientPostureResult(
      memberId: expectedMemberId,
      authorized: data['authorized'],
      sharingStatus: wire.bookingText(data['sharingStatus'], max: 64),
      measurementsStatus: wire.bookingText(data['measurementsStatus'], max: 64),
      message: wire.bookingText(data['message'], max: 500),
      sessions: (data['sessions'] as List)
          .map((s) => ClientPostureSession.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

abstract class ClientPostureRepository {
  Future<ClientPostureResult> loadPostureHistory(String memberId);
}
