import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// Maps application integration contracts into the shared presentation API.
GoogleIntegrationPanelActions googleIntegrationPanelActions(
        GoogleIntegrationRepository repository) =>
    GoogleIntegrationPanelActions(
      identity: repository,
      load: ({String? coachId}) async {
        final status = await repository.load(coachId: coachId);
        return GoogleIntegrationPanelStatus(
          connectionStatus: status.connectionStatus,
          calendarStatus: status.calendarStatus,
          syncStatus: status.syncStatus,
          senderEmail: status.senderEmail,
          lastSyncedAtMillis: status.lastSyncedAtMillis,
          automationEnabled: status.automationEnabled,
          automationStatus: status.automationStatus,
          emailSyncStatus: status.emailSyncStatus,
          revocationPending: status.revocationPending,
        );
      },
      beginConnect: repository.beginConnect,
      disconnect: repository.disconnect,
      acknowledgeRevocation: repository.acknowledgeRevocation,
      createCoachCalendar: repository.createCoachCalendar,
      syncBooking: repository.syncBooking,
    );
