import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gainpath_domain/coaching.dart' show BookingChangeSource;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_data/gainpath_data.dart'
    show BookingRemoteDataSource, CreateBookingHoldRequestDto, BookingHoldDto;
import 'package:gainpath_domain/gainpath_domain.dart';
import 'firebase_app_check_readiness.dart';
import 'firebase_function_transport.dart';

typedef BookingCallable = Future<Map<String, dynamic>> Function(
    String, Map<String, dynamic>);

/// SDK access is deferred until a booking route actually performs an operation.
class BookingTransport {
  BookingTransport(
      {required this.scope,
      required this.isCurrent,
      String? Function()? currentUid,
      BookingCallable? call})
      : _uid = currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
        _call = call ?? _regionalCall;
  static Future<Map<String, dynamic>> _regionalCall(
      String name, Map<String, dynamic> input) async {
    return (await firebaseCallable(name).call<Map<String, dynamic>>(input))
        .data;
  }

  final SessionScope scope;
  final bool Function() isCurrent;
  final String? Function() _uid;
  final BookingCallable _call;
  void check() {
    if (!isCurrent() || _uid() != scope.userId) {
      throw const BookingException('permission-denied');
    }
  }

  Future<Map<String, dynamic>> call(
      String name, Map<String, dynamic> input) async {
    check();
    try {
      final result = await _call(name, input);
      check();
      return result;
    } on FirebaseException catch (error) {
      check();
      throw BookingException(error.code);
    } on BookingException {
      check();
      rethrow;
    } catch (_) {
      check();
      throw const BookingException('unknown');
    }
  }
}

class FirebaseBookingRepository
    implements
        BookingRemoteDataSource,
        MemberBookingOptionsRepository,
        BookingCancellationRepository {
  FirebaseBookingRepository(
      {required this.scope,
      required bool Function() isCurrent,
      FirebaseAppCheckReadiness? readiness,
      String? Function()? currentUid,
      BookingCallable? call})
      : _readiness = readiness ?? FirebaseAppCheckReadiness.instance,
        _transport = BookingTransport(
            scope: scope,
            isCurrent: isCurrent,
            currentUid: currentUid,
            call: call);
  @override
  final SessionScope scope;
  final FirebaseAppCheckReadiness _readiness;
  final BookingTransport _transport;
  Future<void> _ready() async {
    _transport.check();
    final ready = await _readiness.ensureReady(check: _transport.check);
    _transport.check();
    if (!ready) throw const BookingException('app-check-unavailable');
  }

  @override
  Future<CancelBookingHoldResult> cancelHold(
      CancelBookingHoldRequest request) async {
    _transport.check();
    if (request.organizationId != scope.organizationId) {
      throw const BookingException('permission-denied');
    }
    await _ready();
    try {
      return CancelBookingHoldResult.fromJson(
          await _transport.call('cancelBookingHoldCommand', request.toJson()),
          request: request);
    } on FormatException {
      throw const BookingException('invalid-response');
    }
  }

  @override
  Future<BookingHoldDto> createHold(CreateBookingHoldRequestDto request) async {
    _transport.check();
    if (request.memberId != scope.userId ||
        request.organizationId != scope.organizationId) {
      throw const BookingException('permission-denied');
    }
    await _ready();
    try {
      return BookingHoldDto.fromJson(
          await _transport.call('createBookingHold', request.toJson()),
          expectedRequestId: request.requestId);
    } on FormatException {
      throw const BookingException('invalid-response');
    }
  }

  @override
  Future<BookingOptionsContext> load(
      {required String coachId,
      String? localDate,
      required int durationMinutes}) async {
    await _ready();
    try {
      final result = BookingOptionsContext.fromJson(
          await _transport.call('getMemberBookingOptionsCommand', {
            'schemaVersion': 1,
            'organizationId': scope.organizationId,
            'coachId': coachId,
            'durationMinutes': durationMinutes,
            if (localDate != null) 'localDate': localDate
          }),
          expectedCoachId: coachId,
          expectedDurationMinutes: durationMinutes,
          expectedLocalDate: localDate);
      if (localDate == null && result.localDate != result.todayLocalDate) {
        throw const FormatException();
      }
      return result;
    } on FormatException {
      throw const BookingException('failed-precondition');
    }
  }
}

class FirebaseBookingListRepository
    implements BookingListRepository, BookingChangeSource {
  FirebaseBookingListRepository(
      {required this.scope,
      required this.role,
      required List<String> branchIds,
      required bool Function() isCurrent,
      String? Function()? currentUid,
      BookingCallable? call})
      : _branches = List.unmodifiable(branchIds),
        _transport = BookingTransport(
            scope: scope,
            isCurrent: isCurrent,
            currentUid: currentUid,
            call: call);
  @override
  final SessionScope scope;
  final AppRole role;
  final List<String> _branches;
  final BookingTransport _transport;
  @override
  Stream<void> watchBookingChanges() async* {
    _transport.check();
    if (role != AppRole.member && role != AppRole.coach) return;
    if (role == AppRole.coach && _branches.isEmpty) return;
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('orgs/${scope.organizationId}/bookings')
        .where(role == AppRole.coach ? 'coachId' : 'memberId',
            isEqualTo: scope.userId);
    if (role == AppRole.coach) {
      query = query.where('branchId', whereIn: _branches);
    }
    await for (final _ in query
        .where('startAtMillis',
            isGreaterThanOrEqualTo: DateTime.now()
                .subtract(const Duration(days: 90))
                .millisecondsSinceEpoch)
        .orderBy('startAtMillis')
        .limit(2000)
        .snapshots()) {
      _transport.check();
      yield null;
    }
  }

  @override
  Future<BookingPage> load(
      {String? coachId,
      String? firstLocalDate,
      int? dayCount,
      BookingCursor? cursor}) async {
    _transport.check();
    if ((role == AppRole.member && coachId != null) ||
        (role == AppRole.coach && coachId != null && coachId != scope.userId) ||
        (role == AppRole.admin && coachId == null)) {
      throw const BookingException('permission-denied');
    }
    try {
      return BookingPage.fromJson(
          await _transport.call('getBookingListCommand', {
            'schemaVersion': 1,
            'includeParticipantNames': true,
            'includeReviewDetails': true,
            'includeCancellationDetails': true,
            'includeMemberChangeDetails': true,
            'organizationId': scope.organizationId,
            if (coachId != null) 'coachId': coachId,
            if (firstLocalDate != null) 'firstLocalDate': firstLocalDate,
            if (dayCount != null) 'dayCount': dayCount,
            if (cursor != null) 'cursor': cursor.toJson()
          }),
          expectedOrganizationId: scope.organizationId,
          expectedMemberId: role == AppRole.member ? scope.userId : null,
          expectedCoachId: role == AppRole.coach ? scope.userId : coachId,
          permittedBranchIds: role == AppRole.coach ? _branches : null,
          expectedFirstLocalDate: firstLocalDate);
    } on FormatException {
      throw const BookingException('failed-precondition');
    }
  }
}
