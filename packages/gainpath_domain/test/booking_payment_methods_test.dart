import 'package:test/test.dart';
import 'package:gainpath_domain/coaching.dart';

void main() {
  final session = {
    'schemaVersion': 1,
    'amountMinor': 12000,
    'currency': 'MYR',
    'coachName': 'Coach',
    'branchName': 'Studio',
    'durationMinutes': 60,
    'localDate': '2026-11-20',
    'startLabel': '09:00',
    'endLabel': '10:00',
    'holdExpiresAtMillis': 2000,
    'quoteToken': 'a' * 64
  };
  Map<String, dynamic> input() => {
        'schemaVersion': 1,
        'serverNowMillis': 1000,
        'methods': [
          {'code': 'BCBB0235', 'name': 'CIMB Clicks', 'category': 'fpx'}
        ],
        'session': session
      };
  test('validates immutable server-enabled options and reviewed session', () {
    final x = BookingPaymentMethods.fromJson(input(), bookingId: 'booking');
    expect(x.quote!.quoteToken, 'a' * 64);
    expect(x.methods.single.code, 'BCBB0235');
    expect(() => x.methods.clear(), throwsUnsupportedError);
  });
  test('rejects invalid/unsupported methods and duplicate or missing sessions',
      () {
    for (final patch in [
      {
        'methods': [null]
      },
      {
        'methods': [
          {'code': 'FAKE', 'name': 'Card', 'category': 'card'}
        ]
      },
      {'session': null},
      {'serverNowMillis': 0},
      {
        'methods': List.filled(
            2, {'code': 'BCBB0235', 'name': 'CIMB', 'category': 'fpx'})
      }
    ]) {
      expect(
          () => BookingPaymentMethods.fromJson({...input(), ...patch},
              bookingId: 'booking'),
          throwsFormatException);
    }
  });
  test('existing invoice cannot be presented alongside changeable methods', () {
    expect(
        () => BookingPaymentMethods.fromJson(
            {...input(), 'existingPayment': session},
            bookingId: 'booking'),
        throwsFormatException);
  });
}
