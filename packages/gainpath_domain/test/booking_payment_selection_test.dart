import 'package:test/test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show PersistedBookingRecord;

void main() {
  test(
      'booking projection retains selection alongside legacy thirty-minute schedule',
      () {
    final start = DateTime.parse('2026-10-20T01:00:00Z').millisecondsSinceEpoch;
    final data = <String, dynamic>{
      'schemaVersion': 1,
      'bookingId': 'booking',
      'organizationId': 'org',
      'memberId': 'member',
      'coachId': 'coach',
      'branchId': 'branch',
      'requestId': 'request',
      'startAtMillis': start,
      'endAtMillis': start + 1800000,
      'durationMinutes': 30,
      'status': 'pending_hold',
      'holdExpiresAtMillis': start - 3600000,
      'createdAtMillis': start - 7200000,
      'localDate': '2026-10-20',
      'timeZone': 'Asia/Kuala_Lumpur',
      'policyVersion': 'v1',
      'startLabel': '09:00',
      'endLabel': '09:30',
      'expiryLabel': '08:00',
      ...SelectedBookingPaymentMethod(
              choice: bookingPaymentChoices.firstWhere((m) => m.code == 'tng'),
              selectedAt: start - 7200000)
          .toJson()
    };
    final record = PersistedBookingRecord.fromJson(data);
    expect(record.durationMinutes, 30);
    expect(record.selectedPaymentMethod!.code, 'tng');
    expect(record.toJson(), data);
  });
  test(
      'canonical catalog includes grouped preferences independently from providers',
      () {
    expect(
        bookingPaymentChoices.map((m) => m.code),
        containsAll([
          'maybank2u',
          'cimbclicks',
          'tng',
          'grabpay',
          'shopeepay',
          'visa_mastercard'
        ]));
    expect(bookingPaymentChoices.map((m) => m.category).toSet(),
        {'fpx', 'ewallet', 'card'});
  });
  test(
      'selected invoice preference roundtrips server timestamp without inventing legacy choice',
      () {
    final json = {
      'selectedPaymentMethodCategory': 'ewallet',
      'selectedPaymentMethodCode': 'grabpay',
      'selectedPaymentMethodLabel': 'GrabPay',
      'selectedPaymentMethodIconKey': 'grabpay',
      'selectedAt': 123
    };
    final selected = SelectedBookingPaymentMethod.fromPaymentJson(json)!;
    expect(selected.toJson(), json);
    expect(SelectedBookingPaymentMethod.fromPaymentJson({}), isNull);
    expect(
        () => SelectedBookingPaymentMethod.fromPaymentJson(
            {...json, 'selectedPaymentMethodLabel': 'Visa'}),
        throwsFormatException);
  });
}
