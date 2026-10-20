import 'dart:async';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

class AvailabilityFake implements CoachAvailabilityRepository {
  @override
  final scope = SessionScope(userId: 'coach', organizationId: 'org');
  int revision = 0;
  List<DatedCoachWindow> stored = [];
  Completer<CoachAvailabilityContext>? pending;
  String? failure;
  final requests = <String>[];
  CoachAvailabilityContext context(String id) => CoachAvailabilityContext(
          coachId: id,
          serverNowMillis: 1,
          todayLocalDate: '2026-10-15',
          timeZone: 'Asia/Kuala_Lumpur',
          policyVersion: 'booking-v1',
          writableFromLocalDate: '2026-10-16',
          writableThroughLocalDate: '2026-11-14',
          assignedBranchIds: [
            'main'
          ],
          days: [
            CoachAvailabilityDay(
                localDate: '2026-10-16',
                revision: revision,
                editable: true,
                windows: stored,
                boundaries: const [
                  CoachTimeBoundary(
                      atMillis: 1792116000000, label: '10:00 GMT+8'),
                  CoachTimeBoundary(
                      atMillis: 1792117800000, label: '10:30 GMT+8'),
                  CoachTimeBoundary(
                      atMillis: 1792119600000, label: '11:00 GMT+8')
                ])
          ]);
  @override
  Future<CoachAvailabilityContext> load(
          {required String coachId,
          String? firstLocalDate,
          int dayCount = 7}) async =>
      pending?.future ?? context(coachId);
  @override
  Future<CoachAvailabilitySaveResult> save(
      {required CoachAvailabilityDay baseline,
      required CoachAvailabilityContext context,
      required List<DatedCoachWindow> windows,
      required String requestId}) async {
    requests.add(requestId);
    if (failure != null) throw CoachAvailabilityException(failure!);
    stored = List.of(windows);
    revision++;
    return CoachAvailabilitySaveResult(
        requestId: requestId,
        coachId: scope.userId,
        localDate: baseline.localDate,
        revision: revision,
        outcome: stored.isEmpty ? 'removed' : 'saved');
  }
}
