class MemberAccountLifecycle {
  const MemberAccountLifecycle(
      {required this.state,
      required this.revision,
      required this.requestedAtMillis,
      required this.retentionEndsAtMillis,
      required this.policy,
      required this.sessionNotBeforeSeconds,
      required this.sessionRevocationPending,
      required this.reactivationAllowed,
      required this.reactivationAvailableAtMillis,
      required this.currentTimeMillis,
      required this.lastRequestId,
      required this.editBaseline});
  final String state, policy;
  final int revision, sessionNotBeforeSeconds, currentTimeMillis;
  final int? requestedAtMillis,
      retentionEndsAtMillis,
      reactivationAvailableAtMillis;
  final bool sessionRevocationPending, reactivationAllowed;
  final String? lastRequestId;
  final Object editBaseline;
  bool get isPendingDeletion => state == 'pendingDeletion';

  factory MemberAccountLifecycle.fromJson(Map<String, dynamic> json,
      {required Object editBaseline}) {
    int number(String key) {
      final value = json[key];
      if (value is! int || value < 0) {
        throw const FormatException('Invalid account status.');
      }
      return value;
    }

    int? optional(String key) => json[key] == null ? null : number(key);
    final state = json['state'], policy = json['policy'];
    final revision = number('revision'), time = number('currentTimeMillis');
    final requested = optional('requestedAtMillis'),
        deadline = optional('retentionEndsAtMillis');
    final available = optional('reactivationAvailableAtMillis');
    final barrier = number('sessionNotBeforeSeconds');
    final pending = json['sessionRevocationPending'],
        allowed = json['reactivationAllowed'];
    final requestId = json['lastRequestId'];
    if (json['schemaVersion'] != 1 ||
        !['active', 'pendingDeletion'].contains(state) ||
        !['pendingApproval', 'grace30Days'].contains(policy) ||
        pending is! bool ||
        allowed is! bool ||
        (requestId != null &&
            (requestId is! String ||
                !RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(requestId))) ||
        (revision == 0 &&
            (state != 'active' ||
                requested != null ||
                deadline != null ||
                barrier != 0 ||
                requestId != null ||
                pending ||
                allowed)) ||
        (revision > 0 &&
            (requested == null ||
                requested > time ||
                requestId == null ||
                barrier != requested ~/ 1000 + 1)) ||
        (policy == 'grace30Days' &&
            (requested == null || deadline != requested + 30 * 86400000)) ||
        (policy == 'pendingApproval' && deadline != null) ||
        (state == 'active' && (pending || allowed || available != null)) ||
        (state == 'pendingDeletion' &&
            (revision == 0 || (!pending && available == null))) ||
        (allowed &&
            (pending ||
                policy != 'grace30Days' ||
                deadline == null ||
                time >= deadline ||
                available == null ||
                time < available))) {
      throw const FormatException('Invalid account status.');
    }
    return MemberAccountLifecycle(
        state: state as String,
        revision: revision,
        requestedAtMillis: requested,
        retentionEndsAtMillis: deadline,
        policy: policy as String,
        sessionNotBeforeSeconds: barrier,
        sessionRevocationPending: pending,
        reactivationAllowed: allowed,
        reactivationAvailableAtMillis: available,
        currentTimeMillis: time,
        lastRequestId: requestId as String?,
        editBaseline: editBaseline);
  }
}

abstract interface class MemberAccountLifecycleRepository {
  Future<MemberAccountLifecycle> load();
  Future<void> verifyCurrentPassword(String password);
  Future<MemberAccountLifecycle> requestDeactivation(
      MemberAccountLifecycle original);
  Future<MemberAccountLifecycle> cancelDeactivation(
      MemberAccountLifecycle original);
}

class MemberAccountLifecycleException implements Exception {
  const MemberAccountLifecycleException(this.message, {this.uncertain = false});
  final String message;
  final bool uncertain;
}
