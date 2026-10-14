import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/coaching/application/live_booking_cubit.dart';
import 'firebase_booking_repository_test.dart' show pageJson;

class Options implements MemberBookingOptionsRepository {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'org');
  @override
  Future<BookingOptionsContext> load(
          {required String coachId,
          String? localDate,
          required int durationMinutes}) async =>
      BookingOptionsContext.fromJson({
        'schemaVersion': 1,
        'coachId': coachId,
        'durationMinutes': durationMinutes,
        'serverNowMillis': 1791936000000,
        'todayLocalDate': '2026-10-14',
        'localDate': localDate ?? '2026-10-14',
        'timeZone': 'Asia/Kuala_Lumpur',
        'throughLocalDate': '2026-11-13',
        'permittedBranchIds': ['branch'],
        'options': [
          {
            'branchId': 'branch',
            'startAtMillis': 1792022400000,
            'endAtMillis': 1792022400000 + durationMinutes * 60000,
            'startLabel': '08:00 GMT+8',
            'endLabel': '08:30 GMT+8'
          }
        ]
      });
}

class Writer implements BookingRepository {
  final requests = <CreateBookingHoldRequest>[];
  Completer<BookingHold>? pending;
  String? errorCode;
  @override
  Future<BookingHold> createHold(CreateBookingHoldRequest request) async {
    requests.add(request);
    if (errorCode != null) throw BookingException(errorCode!);
    if (pending != null) return pending!.future;
    if (requests.length == 1) throw const BookingException('unavailable');
    return BookingHold.fromJson({
      'schemaVersion': 1,
      'requestId': request.requestId,
      'bookingId': 'booking',
      'status': 'pending_hold',
      'holdExpiresAtMillis': 1791936600000
    });
  }
}

void main() {
  test(
      'same option keeps ID; duplicate-ID conflicts and subsequent rejection keep intent locked',
      () async {
    var ids = 0;
    final writer = Writer()..errorCode = 'already-exists';
    final cubit = LiveBookingCubit(
        options: Options(),
        writer: writer,
        coachId: 'coach',
        isCurrent: () => true,
        requestId: () => 'intent_${++ids}');
    await cubit.refresh();
    final option = cubit.state.options!.options.single;
    cubit.select(option);
    cubit.select(option);
    expect(ids, 1);
    await cubit.submit();
    expect(cubit.state.uncertain, true);
    writer.errorCode = 'failed-precondition';
    await cubit.submit();
    expect(cubit.state.uncertain, true);
    expect(ids, 1);
    cubit.discardUncertainIntent();
    expect(cubit.state.intent, isNull);
    expect(cubit.state.message, contains('remains unchanged'));
    await cubit.close();
  });
  test('known contention refreshes snapshot and requires explicit reselection',
      () async {
    final cubit = LiveBookingCubit(
        options: Options(),
        writer: Writer()..errorCode = 'aborted',
        coachId: 'coach',
        isCurrent: () => true);
    await cubit.refresh();
    cubit.select(cubit.state.options!.options.single);
    await cubit.submit();
    expect(cubit.state.intent, isNull);
    expect(cubit.state.options, isNotNull);
    expect(cubit.state.message, contains('Select a time again'));
    await cubit.close();
  });
  test(
      'pending elapsed label uses server anchor without persisted status mutation',
      () {
    final page = BookingPage.fromJson(pageJson());
    final record = page.records.single;
    expect(bookingStatusLabel(record, page.serverNowMillis),
        contains('time elapsed'));
    expect(bookingStatusLabel(record, record.holdExpiresAtMillis - 1),
        contains('not a paid'));
    expect(record.rawStatus, 'pending_hold');
  });
  test('uncertain result locks intent and retries exact payload with same id',
      () async {
    final options = Options();
    final writer = Writer();
    final cubit = LiveBookingCubit(
        options: options,
        writer: writer,
        coachId: 'coach',
        isCurrent: () => true,
        requestId: () => 'intent');
    await cubit.refresh();
    cubit.select(cubit.state.options!.options.single);
    await cubit.submit();
    expect(cubit.state.uncertain, true);
    await cubit.refresh(durationMinutes: 60);
    expect(cubit.state.intent!.durationMinutes, 30);
    await cubit.submit();
    expect(identical(writer.requests.first, writer.requests.last), true);
    expect(cubit.state.hold!.bookingId, 'booking');
    await cubit.close();
  });
  test('late result cannot restore data after scope drift', () async {
    var current = true;
    final writer = Writer()..pending = Completer<BookingHold>();
    final cubit = LiveBookingCubit(
        options: Options(),
        writer: writer,
        coachId: 'coach',
        isCurrent: () => current,
        requestId: () => 'intent');
    await cubit.refresh();
    cubit.select(cubit.state.options!.options.single);
    final operation = cubit.submit();
    current = false;
    writer.pending!.complete(BookingHold.fromJson({
      'schemaVersion': 1,
      'requestId': 'intent',
      'bookingId': 'booking',
      'status': 'pending_hold',
      'holdExpiresAtMillis': 1791936600000
    }));
    await operation;
    expect(cubit.state.hold, isNull);
    expect(cubit.state.intent, isNull);
    await cubit.close();
  });
}
