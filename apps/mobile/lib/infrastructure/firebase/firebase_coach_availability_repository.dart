import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

class FirebaseCoachAvailabilityRepository
    implements CoachAvailabilityRepository, CoachRosterRepository {
  FirebaseCoachAvailabilityRepository(
      {required this.scope,
      required this.isCurrent,
      FirebaseFunctions? functions,
      FirebaseAuth? auth})
      : _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance;
  @override
  final SessionScope scope;
  final bool Function() isCurrent;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  void _check() {
    if (!isCurrent() || _auth.currentUser?.uid != scope.userId) {
      throw const CoachAvailabilityException('permission-denied');
    }
  }

  Future<Map<String, dynamic>> _call(
      String name, Map<String, dynamic> input) async {
    _check();
    try {
      final result = await _functions
          .httpsCallable(name)
          .call<Map<String, dynamic>>(input);
      _check();
      return result.data;
    } on FirebaseException catch (e) {
      throw CoachAvailabilityException(e.code);
    }
  }

  @override
  Future<CoachAvailabilityContext> load(
      {required String coachId,
      String? firstLocalDate,
      int dayCount = 7}) async {
    final result = CoachAvailabilityContext.fromJson(
        await _call('getCoachAvailabilityCommand', {
      'schemaVersion': 1,
      'organizationId': scope.organizationId,
      'coachId': coachId,
      'dayCount': dayCount,
      if (firstLocalDate != null) 'firstLocalDate': firstLocalDate
    }));
    if (result.coachId != coachId) {
      throw const CoachAvailabilityException('failed-precondition');
    }
    return result;
  }

  @override
  Future<CoachAvailabilitySaveResult> save(
      {required CoachAvailabilityDay baseline,
      required CoachAvailabilityContext context,
      required List<DatedCoachWindow> windows,
      required String requestId}) async {
    if (context.coachId != scope.userId ||
        !baseline.editable ||
        baseline.revision == null ||
        context.policyVersion == null) {
      throw const CoachAvailabilityException('permission-denied');
    }
    final result = CoachAvailabilitySaveResult.fromJson(
        await _call('saveCoachAvailabilityDayCommand', {
      'schemaVersion': 1,
      'organizationId': scope.organizationId,
      'requestId': requestId,
      'localDate': baseline.localDate,
      'expectedRevision': baseline.revision,
      'expectedRosterRevision': context.rosterRevision ?? 0,
      'expectedPolicyVersion': context.policyVersion,
      'expectedTimeZone': context.timeZone,
      'expectedCoachBranchIds': context.assignedBranchIds,
      'windows': windows.map((w) => w.toJson()).toList()
    }));
    if (result.coachId != scope.userId ||
        result.localDate != baseline.localDate ||
        result.requestId != requestId) {
      throw const CoachAvailabilityException('failed-precondition');
    }
    return result;
  }

  @override
  Future<CoachRosterSnapshot> loadRoster({required String coachId}) async {
    final result = CoachRosterSnapshot.fromJson(await _call(
        'getCoachRosterCommand', {
      'schemaVersion': 1,
      'organizationId': scope.organizationId,
      'coachId': coachId
    }));
    if (result.coachId != coachId) {
      throw const CoachAvailabilityException('failed-precondition');
    }
    return result;
  }

  @override
  Future<CoachRosterSnapshot> saveRoster(
      {required CoachRosterSnapshot baseline,
      required CoachWeeklyAvailability weeklyAvailability,
      required List<CoachTimeException> exceptions,
      required String requestId}) async {
    if (baseline.coachId != scope.userId) {
      throw const CoachAvailabilityException('permission-denied');
    }
    final result =
        CoachRosterSnapshot.fromJson(await _call('saveCoachRosterCommand', {
      'schemaVersion': 1,
      'organizationId': scope.organizationId,
      'requestId': requestId,
      'expectedRevision': baseline.revision,
      'expectedPolicyVersion': baseline.policyVersion,
      'expectedTimeZone': baseline.timeZone,
      'expectedCoachBranchIds': baseline.assignedBranchIds,
      'weeklyAvailability': weeklyAvailability.toJson(),
      'exceptions': exceptions.map((e) => e.toJson()).toList()
    }));
    if (result.coachId != scope.userId ||
        result.revision != baseline.revision + 1) {
      throw const CoachAvailabilityException('failed-precondition');
    }
    return result;
  }
}
