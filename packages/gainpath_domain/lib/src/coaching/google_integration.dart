class GoogleIntegrationStatus {
  const GoogleIntegrationStatus(
      {this.connectionStatus = 'disconnected',
      this.calendarStatus = 'not_created',
      this.syncStatus = 'not_synced',
      this.senderEmail,
      this.lastSyncedAtMillis,
      this.automationEnabled = false,
      this.automationStatus = 'not_started',
      this.emailSyncStatus = 'not_sent',
      this.revocationPending = false});
  final String connectionStatus, calendarStatus, syncStatus;
  final String? senderEmail;
  final int? lastSyncedAtMillis;
  final bool revocationPending;
  final bool automationEnabled;
  final String automationStatus, emailSyncStatus;
  bool get connected => connectionStatus == 'connected';
  factory GoogleIntegrationStatus.fromJson(Map<String, dynamic> d) {
    if (d['schemaVersion'] != 1 ||
        !['disconnected', 'connecting', 'connected', 'needs_reconnect']
            .contains(d['connectionStatus']) ||
        !['not_created', 'creating', 'ready', 'uncertain', 'needs_review']
            .contains(d['calendarStatus'])) {
      throw const FormatException('Invalid Google integration status.');
    }
    return GoogleIntegrationStatus(
        connectionStatus: d['connectionStatus'] as String,
        calendarStatus: d['calendarStatus'] as String,
        syncStatus: d['syncStatus'] as String? ?? 'not_synced',
        senderEmail: d['senderEmail'] as String?,
        lastSyncedAtMillis: d['lastSyncedAtMillis'] as int?,
        automationEnabled: d['automationEnabled'] == true,
        automationStatus: d['automationStatus'] as String? ?? 'not_started',
        emailSyncStatus: d['emailSyncStatus'] as String? ?? 'not_sent',
        revocationPending: d['revocationPending'] == true);
  }
}

abstract interface class GoogleIntegrationRepository {
  Future<GoogleIntegrationStatus> load({String? coachId});
  Future<String> beginConnect();
  Future<void> disconnect();
  Future<void> acknowledgeRevocation();
  Future<void> createCoachCalendar(String coachId);
  Future<String> syncBooking(String bookingId, {required bool email});
}

/// Mock mode uses the same presentation without pretending a Google grant exists.
class DisconnectedGoogleIntegrationRepository
    implements GoogleIntegrationRepository {
  const DisconnectedGoogleIntegrationRepository();
  @override
  Future<GoogleIntegrationStatus> load({String? coachId}) async =>
      const GoogleIntegrationStatus();
  Never _unavailable() => throw StateError(
      'Google account connection is unavailable in mock mode.');
  @override
  Future<String> beginConnect() async => _unavailable();
  @override
  Future<void> disconnect() async => _unavailable();
  @override
  Future<void> acknowledgeRevocation() async => _unavailable();
  @override
  Future<void> createCoachCalendar(String coachId) async => _unavailable();
  @override
  Future<String> syncBooking(String bookingId, {required bool email}) async =>
      _unavailable();
}
