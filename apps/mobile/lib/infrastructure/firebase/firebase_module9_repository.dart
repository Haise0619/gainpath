import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, BookingException;
import 'firebase_booking_repository.dart';
import 'firebase_app_check_readiness.dart';

class FirebaseModule9Repository implements Module9Repository {
  FirebaseModule9Repository(
      {required SessionScope scope,
      required bool Function() isCurrent,
      BookingCallable? call,
      String? Function()? currentUid,
      FirebaseAppCheckReadiness? readiness})
      : _scope = scope,
        _readiness = readiness ?? FirebaseAppCheckReadiness.instance,
        _transport = BookingTransport(
            scope: scope,
            isCurrent: isCurrent,
            call: call,
            currentUid: currentUid);
  final SessionScope _scope;
  final FirebaseAppCheckReadiness _readiness;
  final BookingTransport _transport;
  Future<Map<String, dynamic>> _call(
      String name, Map<String, dynamic> payload) async {
    _transport.check();
    if (!await _readiness.ensureReady(check: _transport.check))
      throw const BookingException('app-check-unavailable');
    final data = await _transport.call(name, {
      'schemaVersion': 1,
      'organizationId': _scope.organizationId,
      ...payload
    });
    if (data['schemaVersion'] != 1)
      throw const BookingException('unsupported-payload');
    return data;
  }

  CoachSharing _sharing(Map<String, dynamic> data) {
    if (data['enabled'] is! bool ||
        data['revision'] is! int ||
        data['revision'] < 0)
      throw const BookingException('unsupported-payload');
    return CoachSharing(data['enabled'], data['revision']);
  }

  @override
  Stream<void> watchInbox() async* {
    _transport.check();
    if (!await _readiness.ensureReady(check: _transport.check))
      throw const BookingException('app-check-unavailable');
    await for (final _ in FirebaseFirestore.instance
        .collection('orgs/${_scope.organizationId}/notifications')
        .where('recipientId', isEqualTo: _scope.userId)
        .orderBy('createdAtMillis', descending: true)
        .limit(30)
        .snapshots()) {
      _transport.check();
      yield null;
    }
  }

  @override
  Future<CoachSharing> loadSharing() async => _sharing(
      await _call('module9MemberCommandCallable', {'action': 'sharing'}));
  @override
  Future<CoachSharing> saveSharing(bool enabled, int expectedRevision) async =>
      _sharing(await _call('module9MemberCommandCallable', {
        'action': 'sharing',
        'enabled': enabled,
        'expectedRevision': expectedRevision
      }));
  @override
  Future<void> markRead(String id) async {
    await _call('module9MemberCommandCallable',
        {'action': 'readNotification', 'notificationId': id});
  }

  @override
  Future<NoticePage> loadInbox({String? afterId}) async {
    final data = await _call('module9MemberCommandCallable',
        {'action': 'inbox', if (afterId != null) 'afterId': afterId});
    return NoticePage(
        (data['records'] as List)
            .map((r) => MemberNotice(
                id: r['id'] as String,
                title: r['title'] as String,
                message: r['message'] as String,
                read: r['read'] as bool,
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                    r['createdAtMillis'] as int),
                bookingId: r['bookingId'] as String?))
            .toList(),
        data['nextAfterId'] as String?);
  }

  @override
  Future<CoachReport> loadPerformance() async {
    final data = await _call('getCoachPerformanceCommand', {});
    if (data['coachId'] != _scope.userId ||
        data['currency'] != 'MYR' ||
        data['environment'] != 'sandbox')
      throw const BookingException('unsupported-payload');
    final sessions = (data['sessions'] as List)
        .map((s) => CoachReportSession(
            booking: Booking(
                id: s['bookingId'] as String,
                coachId: _scope.userId,
                coachName: 'Coach',
                memberName: s['memberName'] as String,
                start: DateTime.fromMillisecondsSinceEpoch(
                    s['startAtMillis'] as int),
                durationMin: s['durationMinutes'] as int,
                branch: s['branchId'] as String,
                status: BookingStatus.values.firstWhere(
                    (v) => v.name == s['status'],
                    orElse: () => BookingStatus.cancelled),
                fee: (s['coachMinor'] as int) / 100),
            grossMinor: s['grossMinor'] as int,
            coachMinor: s['coachMinor'] as int,
            platformMinor: s['platformMinor'] as int,
            reversedMinor: s['reversedMinor'] as int,
            eligible: s['eligible'] as bool))
        .toList();
    return CoachReport(
        firstDate: data['firstLocalDate'] as String,
        throughDate: data['throughLocalDate'] as String,
        policyVersion: data['policyVersion'] as String,
        sessions: sessions,
        reviewCount: data['reviewCount'] as int,
        averageRating: (data['averageRating'] as num?)?.toDouble(),
        coachBasisPoints: data['coachBasisPoints'] as int,
        grossMinor: data['grossMinor'] as int,
        coachMinor: data['coachMinor'] as int,
        platformMinor: data['platformMinor'] as int,
        reversedMinor: data['reversedMinor'] as int);
  }
}
