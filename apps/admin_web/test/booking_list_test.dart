import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_admin_web/features/coaching/application/booking_list_cubit.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_booking_list_repository.dart';

Map<String, dynamic> page() => {
      'schemaVersion': 1,
      'serverNowMillis': 1791936000000,
      'timeZone': 'Asia/Kuala_Lumpur',
      'firstLocalDate': '2026-10-14',
      'throughLocalDate': '2026-11-13',
      'records': []
    };
void main() {
  test(
      'Admin requires selected Coach and sends scoped read without attestation dependency',
      () async {
    Map<String, dynamic>? sent;
    String? name;
    final repository = FirebaseBookingListRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'org'),
        isCurrent: () => true,
        currentUid: () => 'admin',
        call: (callName, input) async {
          name = callName;
          sent = input;
          return page();
        });
    await expectLater(repository.load(), throwsA(isA<BookingException>()));
    expect(sent, isNull);
    final cubit = BookingListCubit(
        repository: repository,
        isCurrent: () => true,
        coachId: 'selected-coach');
    await cubit.refresh();
    expect(name, 'getBookingListCommand');
    expect(sent, {
      'schemaVersion': 1,
      'organizationId': 'org',
      'coachId': 'selected-coach'
    });
    expect(cubit.state.page, isNotNull);
    await cubit.close();
  });
  test('Admin post-SDK drift clears list state and does not expose payload',
      () async {
    var current = true;
    final pending = Completer<Map<String, dynamic>>();
    final repository = FirebaseBookingListRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'org'),
        isCurrent: () => current,
        currentUid: () => 'admin',
        call: (_, __) => pending.future);
    final cubit = BookingListCubit(
        repository: repository, isCurrent: () => current, coachId: 'coach');
    final operation = cubit.refresh();
    current = false;
    pending.complete(page());
    await operation;
    expect(cubit.state.page, isNull);
    expect(cubit.state.records, isEmpty);
    expect(cubit.state.message, contains('unavailable'));
    await cubit.close();
  });
}
