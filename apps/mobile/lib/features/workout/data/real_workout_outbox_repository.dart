import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../domain/real_workout_contract.dart';
import '../domain/real_workout_sync.dart';
import '../domain/real_workout_sync_presentation.dart';
import '../domain/workout_contracts.dart';

/// Separate from the legacy/demo repository. Only explicit real-camera v2
/// requests with a prior server acknowledgement enter this durable outbox.
class RealWorkoutOutboxRepository extends ChangeNotifier
    implements RealWorkoutSyncPresentation {
  RealWorkoutOutboxRepository(
      {required this.scope,
      required this.activeScope,
      required this.store,
      required this.gateway,
      required this.newRequestId}) {
    if (store.scope != scope) {
      throw ArgumentError('Workout sync scope mismatch.');
    }
  }
  final SessionScope scope;
  final SessionScope? Function() activeScope;
  final RealWorkoutSyncStore store;
  final RealWorkoutGateway gateway;
  final String Function() newRequestId;
  RealWorkoutSyncState _state = RealWorkoutSyncState();
  bool _disposed = false, _localRevoked = false;
  int _consentEpoch = 0;
  Future<void>? _syncing;
  Future<WorkoutConsentAcknowledgement?>? _granting;
  bool get _active => !_disposed && activeScope() == scope;
  @override
  WorkoutConsentAcknowledgement? get consent =>
      _active && !_localRevoked ? _state.consent : null;
  @override
  List<RealWorkoutSyncEntry> get entries => _active ? _state.entries : const [];
  @override
  bool get revocationPending =>
      _active &&
      (_state.pendingRevocation != null ||
          !_state.consentDesired && _state.pendingConsentRequestId != null);
  @override
  bool get syncing => _syncing != null;
  String? lastErrorCode;
  void _publish(RealWorkoutSyncState state) {
    if (!_active) return;
    _state = state;
    notifyListeners();
  }

  Future<void> load() async {
    if (!_active) return;
    final state = await store.exclusive(() => store.read());
    state.validateScope(scope);
    _publish(state);
  }

  Future<RealWorkoutSyncState> _mutate(
      RealWorkoutSyncState Function(RealWorkoutSyncState) update) async {
    final state = await store.exclusive(() async {
      final old = await store.read();
      old.validateScope(scope);
      if (!_active) return old;
      final next = update(old);
      next.validateScope(scope);
      await store.write(next);
      return next;
    });
    _publish(state);
    return state;
  }

  RealWorkoutSyncState _copy(RealWorkoutSyncState s,
          {WorkoutConsentAcknowledgement? consent,
          bool? desired,
          String? pendingRequest,
          PendingWorkoutRevocation? revocation,
          Map<String, WorkoutConsentAcknowledgement>? intents,
          List<RealWorkoutSyncEntry>? entries}) =>
      RealWorkoutSyncState(
          consent: consent,
          consentDesired: desired ?? s.consentDesired,
          pendingConsentRequestId: pendingRequest,
          pendingRevocation: revocation,
          captureIntents: intents ?? s.captureIntents,
          entries: entries ?? s.entries);

  Future<WorkoutConsentAcknowledgement?> acknowledgeConsent() {
    if (_granting != null) return _granting!;
    final epoch = ++_consentEpoch;
    _localRevoked = false;
    return _granting = _acknowledge(epoch).whenComplete(() => _granting = null);
  }

  Future<WorkoutConsentAcknowledgement?> _acknowledge(int epoch) async {
    if (!_active) return null;
    await load();
    if (!_active ||
        revocationPending ||
        epoch != _consentEpoch ||
        _localRevoked) {
      return null;
    }
    lastErrorCode = null;
    final state = await _mutate((s) =>
        epoch != _consentEpoch || _localRevoked || s.consent != null
            ? s
            : _copy(s,
                desired: true,
                pendingRequest: s.pendingConsentRequestId ?? newRequestId()));
    if (!_active || epoch != _consentEpoch || _localRevoked) return null;
    if (state.consent != null) return consent;
    await _recoverGrant(state.pendingConsentRequestId!);
    return consent;
  }

  Future<void> _recoverGrant(String requestId) async {
    try {
      final ack = await gateway.acknowledge(scope, requestId);
      if (ack.scope != scope || ack.requestId != requestId) {
        throw const FormatException('Consent response mismatch.');
      }
      if (!_active) return;
      await _mutate((s) {
        if (s.pendingConsentRequestId != requestId) return s;
        if (!s.consentDesired || _localRevoked) {
          return _copy(s,
              desired: false,
              revocation: PendingWorkoutRevocation(
                  acknowledgement: ack, requestId: newRequestId()));
        }
        return _copy(s, consent: ack, desired: true);
      });
    } catch (error) {
      if (!_active) return;
      final failure = _failure(error);
      lastErrorCode = failure.code;
      if (!failure.retryable) {
        await _mutate((s) => s.pendingConsentRequestId != requestId
            ? s
            : _copy(s, desired: false, revocation: s.pendingRevocation));
      }
    }
  }

  @override
  Future<void> revokeConsent() async {
    if (!_active) return;
    ++_consentEpoch;
    // Immediately stop eligibility, even while another network call is pending.
    _localRevoked = true;
    notifyListeners();
    await _mutate((s) => _copy(s,
        desired: false,
        intents: const {},
        pendingRequest: s.pendingConsentRequestId,
        revocation: s.pendingRevocation ??
            (s.consent == null
                ? null
                : PendingWorkoutRevocation(
                    acknowledgement: s.consent!, requestId: newRequestId())),
        entries: s.entries
            .map((e) => e.status == RealWorkoutSyncStatus.accepted ||
                    e.status == RealWorkoutSyncStatus.rejected
                ? e
                : RealWorkoutSyncEntry(
                    submission: e.submission,
                    status: RealWorkoutSyncStatus.rejected,
                    failureCode: 'consent-revoked'))
            .toList()));
    await _revokePending();
  }

  Future<void> _revokePending() async {
    final revocation = _state.pendingRevocation;
    if (!_active || revocation == null) return;
    try {
      await gateway.revoke(revocation.acknowledgement, revocation.requestId);
      if (!_active) return;
      await _mutate((s) =>
          s.pendingRevocation?.requestId != revocation.requestId
              ? s
              : _copy(s,
                  desired: false, pendingRequest: s.pendingConsentRequestId));
      lastErrorCode = null;
    } catch (error) {
      if (_active) {
        lastErrorCode = _failure(error).code;
        notifyListeners();
      }
    }
  }

  Future<bool> enqueue(
      WorkoutSessionSummary summary, WorkoutConsentAcknowledgement ack) async {
    if (!_active ||
        _localRevoked ||
        summary.scope != scope ||
        summary.provenance != WorkoutProvenance.realCamera ||
        summary.poseMetrics == null) {
      return false;
    }
    summary.validateForLocalStorage();
    final m = summary.poseMetrics!;
    if (m.publishedRoutineId == null ||
        m.consentVersion != workoutConsentVersion) {
      return false;
    }
    var added = false;
    try {
      await _mutate((s) {
        if (_localRevoked ||
            s.consent?.acknowledgementId != ack.acknowledgementId ||
            !s.consentDesired) {
          return s;
        }
        final existing = s.entries
            .where((e) => e.submission.sessionId == summary.sessionId)
            .firstOrNull;
        final payload = RealWorkoutSubmission.fromJson({
          'schemaVersion': 2,
          'requestId':
              existing?.submission.toJson()['requestId'] ?? newRequestId(),
          'organizationId': scope.organizationId,
          'memberId': scope.userId,
          'sessionId': summary.sessionId,
          'exerciseId': summary.exerciseId,
          'publishedRoutineId': m.publishedRoutineId,
          'provenance': 'real_camera',
          'cameraView': m.cameraView,
          'detectorId': m.detectorId,
          'detectorVersion': m.detectorVersion,
          'scoringVersion': m.scoringVersion,
          'consentVersion': m.consentVersion,
          'consentAcknowledgementId': ack.acknowledgementId,
          'startedAtMillis': summary.startedAt.millisecondsSinceEpoch,
          'endedAtMillis': summary.endedAt.millisecondsSinceEpoch,
          'repetitions': summary.repetitions,
          'formScorePercent': summary.formScorePercent,
          'trackedDurationMillis': m.trackedDurationMicros ~/ 1000,
          'rejectedDurationMillis': m.rejectedDurationMicros ~/ 1000
        });
        if (!ack.authorizes(payload)) return s;
        if (existing != null) {
          added = jsonEncode(existing.submission.toJson()) ==
              jsonEncode(payload.toJson());
          return s;
        }
        added = true;
        return _copy(s,
            consent: s.consent,
            desired: s.consentDesired,
            pendingRequest: s.pendingConsentRequestId,
            revocation: s.pendingRevocation,
            entries: [
              ...s.entries,
              RealWorkoutSyncEntry(
                  submission: payload, status: RealWorkoutSyncStatus.pending)
            ],
            intents: Map.of(s.captureIntents)..remove(summary.sessionId));
      });
      return added && _active;
    } on FormatException {
      return false;
    }
  }

  Future<bool> prepareCapture(
      String sessionId, WorkoutConsentAcknowledgement ack) async {
    if (!_active || _localRevoked) return false;
    var prepared = false;
    await _mutate((s) {
      if (s.consent?.acknowledgementId != ack.acknowledgementId ||
          !s.consentDesired) {
        return s;
      }
      final existing = s.captureIntents[sessionId];
      if (existing != null &&
          existing.acknowledgementId != ack.acknowledgementId) {
        return s;
      }
      prepared = true;
      return _copy(s,
          consent: s.consent,
          desired: s.consentDesired,
          pendingRequest: s.pendingConsentRequestId,
          revocation: s.pendingRevocation,
          intents: {...s.captureIntents, sessionId: ack});
    });
    return prepared && _active;
  }

  Future<bool> enqueueFromIntent(WorkoutSessionSummary summary) async {
    if (!_active) return false;
    await load();
    final ack = _state.captureIntents[summary.sessionId];
    if (ack == null) return false;
    return enqueue(summary, ack);
  }

  @override
  Future<void> sync() {
    if (_syncing != null) return _syncing!;
    return _syncing = _sync().whenComplete(() {
      _syncing = null;
      if (_active) notifyListeners();
    });
  }

  Future<void> _sync() async {
    if (!_active) return;
    await load();
    final request = _state.pendingConsentRequestId;
    if (request != null) await _recoverGrant(request);
    await _revokePending();
    if (!_active ||
        _localRevoked ||
        _state.consent == null ||
        revocationPending) {
      return;
    }
    for (final entry in List<RealWorkoutSyncEntry>.of(_state.entries)) {
      if (!_active || _localRevoked) return;
      if (entry.status != RealWorkoutSyncStatus.pending &&
          entry.status != RealWorkoutSyncStatus.retryable) {
        continue;
      }
      WorkoutAcceptance? acceptance;
      WorkoutGatewayFailure? failure;
      try {
        if (!_state.consent!.authorizes(entry.submission)) {
          throw const WorkoutGatewayFailure('consent-changed');
        }
        acceptance = await gateway.submit(entry.submission);
        if (!acceptance.matches(entry.submission)) {
          throw const FormatException('Acceptance response mismatch.');
        }
      } catch (error) {
        failure = _failure(error);
      }
      if (!_active) return;
      await _mutate((s) => _copy(s,
          consent: s.consent,
          desired: s.consentDesired,
          pendingRequest: s.pendingConsentRequestId,
          revocation: s.pendingRevocation,
          entries: s.entries.map((current) {
            if (current.submission.sessionId != entry.submission.sessionId ||
                current.status == RealWorkoutSyncStatus.accepted ||
                current.status == RealWorkoutSyncStatus.rejected &&
                    !(current.failureCode == 'consent-revoked' &&
                        failure == null &&
                        acceptance != null)) {
              return current;
            }
            // Revocation cannot undo a submission accepted before it. Preserve
            // the validated receipt, without restoring consent or sending again.
            if (failure == null && acceptance != null) {
              return RealWorkoutSyncEntry(
                  submission: current.submission,
                  status: RealWorkoutSyncStatus.accepted,
                  acceptance: acceptance);
            }
            if (_localRevoked ||
                s.consent?.acknowledgementId !=
                    entry.submission.consentAcknowledgementId) {
              return RealWorkoutSyncEntry(
                  submission: current.submission,
                  status: RealWorkoutSyncStatus.rejected,
                  failureCode: 'consent-revoked');
            }
            return RealWorkoutSyncEntry(
                submission: current.submission,
                status: failure == null
                    ? RealWorkoutSyncStatus.accepted
                    : failure.retryable
                        ? RealWorkoutSyncStatus.retryable
                        : RealWorkoutSyncStatus.rejected,
                acceptance: failure == null ? acceptance : null,
                failureCode: failure?.code);
          }).toList()));
    }
  }

  WorkoutGatewayFailure _failure(Object error) => error is WorkoutGatewayFailure
      ? error
      : error is FormatException
          ? const WorkoutGatewayFailure('invalid-response')
          : const WorkoutGatewayFailure('unknown');
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
