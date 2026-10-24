/// A callable's deployed name and region. Region selection never changes its
/// authorization, payload or financial behavior.
class FunctionEndpoint {
  const FunctionEndpoint(this.name, this.region);
  final String name;
  final String region;
}

class FunctionEndpointSelector {
  const FunctionEndpointSelector({
    this.callablesRegion = const String.fromEnvironment('FUNCTIONS_REGION',
        defaultValue: 'asia-southeast1'),
    this.singaporeCallables =
        const String.fromEnvironment('SINGAPORE_CALLABLES'),
    this.ratingsRegion = const String.fromEnvironment('COACH_RATINGS_REGION',
        defaultValue: 'asia-southeast1'),
    this.bookingReadsRegion = const String.fromEnvironment(
        'BOOKING_READS_REGION',
        defaultValue: 'asia-southeast1'),
  });
  final String ratingsRegion;
  final String callablesRegion;
  final String bookingReadsRegion;
  final String singaporeCallables;

  /// Logical callable names from the deployed US inventory (24 October 2026).
  /// Runtime release inventory; selection never publishes an undeployed export.
  /// Held Stage B/C exports, HTTP callbacks and workers are deliberately absent.
  static const singaporeEligibleCommands = <String>{
    'acknowledgeWorkoutConsentCommand',
    'archiveCoachCertificationCommand',
    'bookingCommunicationCommand',
    'bookingConsultationNotesCommand',
    'cancelAssignedBookingCommand',
    'cancelBookingHoldCommand',
    'cancelMemberDeactivationCommand',
    'createBookingHold',
    'createBookingPaymentCommand',
    'createMembershipPaymentCommand',
    'fitnessAssistantCommand',
    'getAdminBookingPaymentCommand',
    'getBookingListCommand',
    'getBookingPaymentCommand',
    'getBookingPaymentQuoteCommand',
    'getClientPostureHistoryCommand',
    'getCoachAccountSettingsCommand',
    'getCoachAvailabilityCommand',
    'getCoachCertificationsCommand',
    'getCoachPerformanceCommand',
    'getCoachPublishedPhotoCommand',
    'getCoachRatingsCommand',
    'getCoachRosterCommand',
    'getMemberAccountLifecycleCommand',
    'getMemberBookingOptionsCommand',
    'getMembershipAccessCommand',
    'getMembershipOverviewCommand',
    'getMembershipPaymentCommand',
    'getMembershipQuoteCommand',
    'googleGymConnectionCommand',
    'identifyEquipmentCommand',
    'listAdminBookingPaymentsCommand',
    'manageAdminBookingPaymentCommand',
    'memberBookingChangeCommand',
    'module9MemberCommandCallable',
    'provisionMemberRegistration',
    'publishRoutineCommand',
    'requestMemberDeactivationCommand',
    'requestMembershipRefundCommand',
    'reviewCoachCertificationCommand',
    'revokeWorkoutConsentCommand',
    'saveCoachAccountSettingsCommand',
    'saveCoachAvailabilityDayCommand',
    'saveCoachProfileCommand',
    'saveCoachRosterCommand',
    'setCoachDirectoryStatusCommand',
    'submitBookingReviewCommand',
    'submitCoachCertificationCommand',
    'submitWorkoutSessionCommand',
    'syncGymBookingCommand',
    'verifyMemberMembershipCommand',
  };

  Set<String> _singaporeCommands() {
    if (singaporeCallables.trim().isEmpty) return const {};
    final commands =
        singaporeCallables.split(',').map((name) => name.trim()).toSet();
    if (commands.any((name) => !singaporeEligibleCommands.contains(name))) {
      throw ArgumentError.value(singaporeCallables, 'SINGAPORE_CALLABLES',
          'Use deployed logical callable names; held commands and workers are unavailable.');
    }
    return commands;
  }

  FunctionEndpoint forCommand(String name) {
    if (!const ['us-central1', 'asia-southeast1'].contains(callablesRegion)) {
      throw ArgumentError.value(callablesRegion, 'FUNCTIONS_REGION');
    }
    final singaporeCommands = _singaporeCommands();
    const replacements = {
      'getBookingListCommand': 'getBookingListReadCommand',
      'getCoachAvailabilityCommand': 'getCoachAvailabilityReadCommand',
    };
    final replacement = replacements[name];
    if (replacement != null) {
      switch (bookingReadsRegion) {
        case 'asia-southeast1':
          return FunctionEndpoint(replacement, 'asia-southeast1');
        case 'us-central1':
          return FunctionEndpoint(name, 'us-central1');
        default:
          throw ArgumentError.value(bookingReadsRegion, 'BOOKING_READS_REGION');
      }
    }
    if (name != 'getCoachRatingsCommand') {
      return FunctionEndpoint(
          name,
          singaporeCommands.contains(name)
              ? 'asia-southeast1'
              : singaporeEligibleCommands.contains(name)
                  ? callablesRegion
                  : 'us-central1');
    }
    switch (ratingsRegion) {
      case 'asia-southeast1':
        return const FunctionEndpoint(
            'getCoachRatingsPilotCommand', 'asia-southeast1');
      case 'us-central1':
        return const FunctionEndpoint('getCoachRatingsCommand', 'us-central1');
      default:
        throw ArgumentError.value(ratingsRegion, 'COACH_RATINGS_REGION');
    }
  }
}

/// Repository-owned, in-flight reads only. No completed-response cache, shared
/// account state, retries or mutation coalescing.
class InFlightRead<T> {
  final Map<String, Future<T>> _pending = {};
  Future<T> run(String key, Future<T> Function() load) {
    final pending = _pending[key];
    if (pending != null) return pending;
    late final Future<T> operation;
    operation = Future<T>.sync(load).whenComplete(() {
      if (identical(_pending[key], operation)) _pending.remove(key);
    });
    _pending[key] = operation;
    return operation;
  }
}
