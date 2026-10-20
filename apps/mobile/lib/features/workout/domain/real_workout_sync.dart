import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'real_workout_contract.dart';

enum RealWorkoutSyncStatus { pending, retryable, rejected, accepted }

class WorkoutGatewayFailure implements Exception {
  const WorkoutGatewayFailure(this.code);
  final String code;
  bool get retryable => const {
        'unavailable',
        'deadline-exceeded',
        'internal',
        'unknown',
        'resource-exhausted',
        'not-found'
      }.contains(code);
}

abstract interface class RealWorkoutGateway {
  Future<WorkoutConsentAcknowledgement> acknowledge(
      SessionScope scope, String requestId);
  Future<void> revoke(
      WorkoutConsentAcknowledgement acknowledgement, String requestId);
  Future<WorkoutAcceptance> submit(RealWorkoutSubmission submission);
}

class WorkoutAcceptance {
  WorkoutAcceptance._(this.requestId, this.sessionId, this.acceptedAtMillis);
  factory WorkoutAcceptance.fromJson(Map<String, Object?> json) {
    _exact(json, {
      'schemaVersion',
      'requestId',
      'sessionId',
      'status',
      'acceptedAtMillis'
    });
    final time = json['acceptedAtMillis'];
    if (json['schemaVersion'] != 2 ||
        json['status'] != 'accepted' ||
        time is! int ||
        time <= 0 ||
        time > 8639999996400000) {
      throw const FormatException('Invalid workout acceptance.');
    }
    return WorkoutAcceptance._(
        _id(json['requestId']), _id(json['sessionId']), time);
  }
  final String requestId, sessionId;
  final int acceptedAtMillis;
  bool matches(RealWorkoutSubmission submission) =>
      requestId == submission.toJson()['requestId'] &&
      sessionId == submission.sessionId &&
      acceptedAtMillis >= (submission.toJson()['endedAtMillis'] as int);
  Map<String, Object?> toJson() => {
        'schemaVersion': 2,
        'requestId': requestId,
        'sessionId': sessionId,
        'status': 'accepted',
        'acceptedAtMillis': acceptedAtMillis
      };
}

class RealWorkoutSyncEntry {
  RealWorkoutSyncEntry(
      {required this.submission,
      required this.status,
      this.acceptance,
      this.failureCode}) {
    if ((status == RealWorkoutSyncStatus.accepted) != (acceptance != null) ||
        (acceptance != null && !acceptance!.matches(submission)) ||
        ((status == RealWorkoutSyncStatus.rejected ||
                status == RealWorkoutSyncStatus.retryable) !=
            (failureCode != null))) {
      throw const FormatException('Inconsistent workout sync state.');
    }
    if (failureCode != null) _id(failureCode);
  }
  final RealWorkoutSubmission submission;
  final RealWorkoutSyncStatus status;
  final WorkoutAcceptance? acceptance;
  final String? failureCode;
  factory RealWorkoutSyncEntry.fromJson(Map<String, Object?> json) {
    _exact(json, {'submission', 'status', 'acceptance', 'failureCode'});
    return RealWorkoutSyncEntry(
        submission: RealWorkoutSubmission.fromJson(_map(json['submission'])),
        status: RealWorkoutSyncStatus.values.byName(json['status'] as String),
        acceptance: json['acceptance'] == null
            ? null
            : WorkoutAcceptance.fromJson(_map(json['acceptance'])),
        failureCode: json['failureCode'] as String?);
  }
  Map<String, Object?> toJson() => {
        'submission': submission.toJson(),
        'status': status.name,
        'acceptance': acceptance?.toJson(),
        'failureCode': failureCode
      };
}

class PendingWorkoutRevocation {
  PendingWorkoutRevocation(
      {required this.acknowledgement, required this.requestId}) {
    _id(requestId);
  }
  final WorkoutConsentAcknowledgement acknowledgement;
  final String requestId;
  factory PendingWorkoutRevocation.fromJson(Map<String, Object?> json) {
    _exact(json, {'acknowledgement', 'requestId'});
    return PendingWorkoutRevocation(
        acknowledgement: WorkoutConsentAcknowledgement.fromJson(
            _map(json['acknowledgement'])),
        requestId: _id(json['requestId']));
  }
  Map<String, Object?> toJson() =>
      {'acknowledgement': acknowledgement.toJson(), 'requestId': requestId};
}

class RealWorkoutSyncState {
  RealWorkoutSyncState(
      {this.consent,
      this.consentDesired = false,
      this.pendingConsentRequestId,
      this.pendingRevocation,
      Map<String, WorkoutConsentAcknowledgement> captureIntents = const {},
      List<RealWorkoutSyncEntry> entries = const []})
      : entries = List.unmodifiable(entries),
        captureIntents = Map.unmodifiable(captureIntents) {
    if (entries.length > 1000 ||
        entries.map((e) => e.submission.sessionId).toSet().length !=
            entries.length ||
        entries.map((e) => e.submission.toJson()['requestId']).toSet().length !=
            entries.length ||
        (consent != null &&
            (!consentDesired || pendingConsentRequestId != null)) ||
        (pendingRevocation != null && (consentDesired || consent != null))) {
      throw const FormatException('Invalid workout sync snapshot.');
    }
    if (pendingConsentRequestId != null) _id(pendingConsentRequestId);
    if (captureIntents.length + entries.length > 1000) {
      throw const FormatException('Workout sync capacity exceeded.');
    }
    for (final id in captureIntents.keys) {
      _id(id);
    }
  }
  final WorkoutConsentAcknowledgement? consent;
  final bool consentDesired;
  final String? pendingConsentRequestId;
  final PendingWorkoutRevocation? pendingRevocation;
  final List<RealWorkoutSyncEntry> entries;

  /// Prior server grant and session opt-in are persisted before camera capture.
  final Map<String, WorkoutConsentAcknowledgement> captureIntents;
  void validateScope(SessionScope scope) {
    if (consent != null && consent!.scope != scope ||
        pendingRevocation != null &&
            pendingRevocation!.acknowledgement.scope != scope ||
        entries.any((e) => e.submission.scope != scope) ||
        captureIntents.values.any((ack) => ack.scope != scope)) {
      throw StateError('Workout sync account mismatch.');
    }
  }

  factory RealWorkoutSyncState.fromJson(Map<String, Object?> json) {
    _exact(json, {
      'schemaVersion',
      'consent',
      'consentDesired',
      'pendingConsentRequestId',
      'pendingRevocation',
      'captureIntents',
      'entries'
    });
    if (json['schemaVersion'] != 1 ||
        json['consentDesired'] is! bool ||
        json['entries'] is! List) {
      throw const FormatException('Invalid workout sync snapshot.');
    }
    return RealWorkoutSyncState(
        consent: json['consent'] == null
            ? null
            : WorkoutConsentAcknowledgement.fromJson(_map(json['consent'])),
        consentDesired: json['consentDesired'] as bool,
        pendingConsentRequestId: json['pendingConsentRequestId'] as String?,
        pendingRevocation: json['pendingRevocation'] == null
            ? null
            : PendingWorkoutRevocation.fromJson(
                _map(json['pendingRevocation'])),
        entries: (json['entries'] as List)
            .map((e) => RealWorkoutSyncEntry.fromJson(_map(e)))
            .toList(),
        captureIntents: _map(json['captureIntents']).map((id, ack) =>
            MapEntry(id, WorkoutConsentAcknowledgement.fromJson(_map(ack)))));
  }
  Map<String, Object?> toJson() => {
        'schemaVersion': 1,
        'consent': consent?.toJson(),
        'consentDesired': consentDesired,
        'pendingConsentRequestId': pendingConsentRequestId,
        'pendingRevocation': pendingRevocation?.toJson(),
        'captureIntents':
            captureIntents.map((id, ack) => MapEntry(id, ack.toJson())),
        'entries': entries.map((e) => e.toJson()).toList()
      };
}

abstract interface class RealWorkoutSyncStore {
  SessionScope get scope;
  Future<T> exclusive<T>(Future<T> Function() action);
  Future<RealWorkoutSyncState> read();
  Future<void> write(RealWorkoutSyncState state);
}

class MemoryRealWorkoutSyncStore implements RealWorkoutSyncStore {
  MemoryRealWorkoutSyncStore({required this.scope});
  @override
  final SessionScope scope;
  RealWorkoutSyncState _state = RealWorkoutSyncState();
  Future<void> _tail = Future.value();
  @override
  Future<T> exclusive<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object e) {});
    return result;
  }

  @override
  Future<RealWorkoutSyncState> read() async => _state;
  @override
  Future<void> write(RealWorkoutSyncState state) async {
    state.validateScope(scope);
    _state = RealWorkoutSyncState.fromJson(state.toJson());
  }
}

Map<String, Object?> _map(Object? value) =>
    Map<String, Object?>.from(value as Map);
void _exact(Map<String, Object?> value, Set<String> fields) {
  if (value.length != fields.length || !fields.every(value.containsKey)) {
    throw const FormatException('Invalid sync fields.');
  }
}

String _id(Object? value) {
  if (value is! String || !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value)) {
    throw const FormatException('Invalid sync identifier.');
  }
  return value;
}
