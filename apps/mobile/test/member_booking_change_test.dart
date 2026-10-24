import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_member_booking_change_repository.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_app_check_readiness.dart';
import 'firebase_booking_repository_test.dart' show pageJson;
import 'package:gainpath_mobile/features/coaching/presentation/member/member_booking_change_screen.dart';

class RetryRepository implements MemberBookingChangeRepository {
  final requests = <MemberBookingChangeRequest>[];
  @override
  SessionScope get scope => SessionScope(
      userId: confirmedBooking().memberId,
      organizationId: confirmedBooking().organizationId);
  @override
  Future<BookingOptionsContext> loadReplacementOptions(
          PersistedBookingRecord booking,
          {String? localDate}) =>
      throw UnimplementedError();
  @override
  Future<MemberBookingChangeResult> change(
      MemberBookingChangeRequest request) async {
    requests.add(request);
    if (requests.length == 1) throw const BookingException('unavailable');
    final b = request.booking;
    return MemberBookingChangeResult.fromJson({
      'schemaVersion': 1,
      'requestId': request.requestId,
      'bookingId': b.bookingId,
      'action': 'cancel',
      'status': 'cancelled',
      'startAtMillis': b.startAtMillis,
      'endAtMillis': b.endAtMillis,
      'localDate': b.localDate,
      'timeZone': b.timeZone,
      'changedAtMillis': b.createdAtMillis,
      'refundReviewRequired': true
    }, request);
  }
}

PersistedBookingRecord confirmedBooking() {
  final data = pageJson();
  (data['records'] as List).first['status'] = 'confirmed';
  return BookingPage.fromJson(data).records.first;
}

void main() {
  testWidgets(
      'unknown cancellation outcome freezes the proposal and retries the identical request',
      (tester) async {
    final repo = RetryRepository();
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => MemberBookingChangeScreen(
                                repository: repo,
                                booking: confirmedBooking(),
                                reschedule: false,
                                isCurrent: () => true))),
                    child: const Text('Open change'))))));
    await tester.tap(find.text('Open change'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Cannot attend');
    await tester.ensureVisible(find.text('Review cancellation'));
    await tester.tap(find.text('Review cancellation'));
    await tester.pumpAndSettle();
    expect(find.textContaining('no refund is guaranteed'), findsOneWidget);
    await tester.tap(find.text('Confirm cancellation'));
    await tester.pumpAndSettle();
    expect(repo.requests, hasLength(1));
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    await tester.ensureVisible(find.text('Retry same change'));
    await tester.tap(find.text('Retry same change'));
    await tester.pumpAndSettle();
    expect(repo.requests, hasLength(2));
    expect(identical(repo.requests[0], repo.requests[1]), isTrue);
    expect(find.text('Open change'), findsOneWidget);
  });
  test(
      'request binds the displayed booking baseline and rejects mismatched result identity',
      () {
    final b = confirmedBooking();
    final request = MemberBookingChangeRequest(
        booking: b,
        action: 'cancel',
        requestId: 'change1',
        reason: 'Cannot attend');
    expect(request.toJson()['expectedStartAtMillis'], b.startAtMillis);
    expect(
        () => MemberBookingChangeResult.fromJson({
              'schemaVersion': 1,
              'requestId': 'wrong',
              'bookingId': b.bookingId,
              'action': 'cancel',
              'status': 'cancelled',
              'startAtMillis': b.startAtMillis,
              'endAtMillis': b.endAtMillis,
              'localDate': b.localDate,
              'timeZone': b.timeZone,
              'changedAtMillis': b.createdAtMillis,
              'refundReviewRequired': true
            }, request),
        throwsFormatException);
  });
  test(
      'transport rejects foreign booking and drops late response after account change',
      () async {
    final b = confirmedBooking();
    var current = true, calls = 0;
    final repo = FirebaseMemberBookingChangeRepository(
        scope:
            SessionScope(userId: b.memberId, organizationId: b.organizationId),
        isCurrent: () => current,
        currentUid: () => b.memberId,
        readiness: FirebaseAppCheckReadiness(
            mode: 'production',
            supported: true,
            activate: (_) async {},
            token: () async => 'fixture'),
        call: (name, input) async {
          calls++;
          current = false;
          return {};
        });
    await expectLater(
        repo.change(MemberBookingChangeRequest(
            booking: b,
            action: 'cancel',
            requestId: 'same-intent',
            reason: 'Cannot attend')),
        throwsA(isA<BookingException>()));
    expect(calls, 1);
  });
}
