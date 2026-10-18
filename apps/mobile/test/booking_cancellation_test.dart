import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/coaching/application/booking_cancellation_cubit.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/live_booking_list_view.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_booking_repository.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_app_check_readiness.dart';
import 'firebase_booking_repository_test.dart' show pageJson;

class LifecycleFake
    implements BookingCancellationRepository, BookingListRepository {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'org');
  final requests = <CancelBookingHoldRequest>[];
  bool fail = false, cancelled = false;
  Completer<CancelBookingHoldResult>? pending;
  @override
  Future<BookingPage> load(
      {String? coachId,
      String? firstLocalDate,
      int? dayCount,
      BookingCursor? cursor}) async {
    final data = pageJson();
    if (cancelled) {
      final record = (data['records'] as List).first as Map<String, dynamic>;
      record['status'] = 'cancelled';
    }
    return BookingPage.fromJson(data);
  }

  @override
  Future<CancelBookingHoldResult> cancelHold(
      CancelBookingHoldRequest request) async {
    requests.add(request);
    if (fail) throw const BookingException('unavailable');
    if (pending != null) return pending!.future;
    cancelled = true;
    return result(request);
  }

  CancelBookingHoldResult result(CancelBookingHoldRequest request) =>
      CancelBookingHoldResult.fromJson({
        'schemaVersion': 1,
        'requestId': request.requestId,
        'bookingId': request.bookingId,
        'status': 'cancelled',
        'outcome': 'cancelled',
        'resolvedAtMillis': 1791936000000
      }, request: request);
}

void main() {
  test(
      'uncertain cancellation retains exact ID, blocks other intents and drops stale completion',
      () async {
    final fake = LifecycleFake()..fail = true;
    var current = true, ids = 0;
    final cubit = BookingCancellationCubit(
        repository: fake,
        isCurrent: () => current,
        requestId: () => 'cancel-${++ids}');
    await cubit.cancel('booking');
    expect(cubit.state.uncertain, true);
    await cubit.cancel('other');
    expect(fake.requests.length, 1);
    fake.fail = false;
    fake.pending = Completer();
    final retry = cubit.cancel('booking');
    expect(fake.requests[0], same(fake.requests[1]));
    current = false;
    fake.pending!.complete(fake.result(fake.requests.last));
    await retry;
    expect(cubit.state.request, null);
    expect(cubit.state.message, contains('session'));
    await cubit.close();
  });
  test(
      'Firebase cancellation is guarded, attested and intent-matched with safe errors',
      () async {
    var current = true, calls = 0;
    final source = FirebaseBookingRepository(
        scope: SessionScope(userId: 'member', organizationId: 'org'),
        isCurrent: () => current,
        currentUid: () => 'member',
        readiness: FirebaseAppCheckReadiness(
            mode: 'production',
            supported: true,
            activate: (_) async {},
            token: () async => 'synthetic'),
        call: (name, input) async {
          calls++;
          expect(name, 'cancelBookingHoldCommand');
          expect(input.keys.toSet(),
              {'schemaVersion', 'organizationId', 'bookingId', 'requestId'});
          return {
            'schemaVersion': 1,
            'bookingId': 'other',
            'requestId': input['requestId'],
            'status': 'cancelled',
            'outcome': 'cancelled',
            'resolvedAtMillis': 1791936000000
          };
        });
    final request = CancelBookingHoldRequest(
        organizationId: 'org', bookingId: 'booking', requestId: 'cancel');
    await expectLater(
        source.cancelHold(request),
        throwsA(isA<BookingException>()
            .having((e) => e.code, 'code', 'invalid-response')));
    current = false;
    await expectLater(
        source.cancelHold(request), throwsA(isA<BookingException>()));
    expect(calls, 1);
  });
  testWidgets(
      'Member confirms cancellation and reloads persisted status; read-only lists have no action',
      (tester) async {
    final fake = LifecycleFake();
    await tester.pumpWidget(MaterialApp(
        home: LiveBookingListView(
            repository: fake, cancellation: fake, isCurrent: () => true)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(fake.requests, isEmpty);
    await tester.tap(find.text('Cancel hold'));
    await tester.pumpAndSettle();
    expect(fake.requests.length, 1);
    expect(find.text('cancelled'), findsNWidgets(2));
    expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsNothing);
    await tester.pumpWidget(MaterialApp(
        home: LiveBookingListView(
            key: const ValueKey('readonly'),
            repository: LifecycleFake(),
            isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Cancel'))
            .onPressed,
        isNull);
  });
}
