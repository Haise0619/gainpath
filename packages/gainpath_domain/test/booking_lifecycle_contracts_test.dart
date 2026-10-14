import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:test/test.dart';
import 'booking_read_contracts_test.dart' show record;

void main() {
  test('cancellation intent is strict, scoped and contains no client status',
      () {
    final request = CancelBookingHoldRequest(
        organizationId: 'org', bookingId: 'booking', requestId: 'cancel');
    expect(request.toJson(), {
      'schemaVersion': 1,
      'organizationId': 'org',
      'bookingId': 'booking',
      'requestId': 'cancel'
    });
    expect(
        () => CancelBookingHoldRequest(
            organizationId: 'org', bookingId: '../x', requestId: 'c'),
        throwsFormatException);
  });
  test(
      'expired history needs consistent resolution metadata; old cancelled records remain readable',
      () {
    final data = record();
    expect(
        PersistedBookingRecord.fromJson({...data, 'status': 'cancelled'})
            .resolution,
        null);
    final expired = {
      ...data,
      'status': 'expired',
      'resolution': 'hold_expired',
      'resolvedAtMillis': data['holdExpiresAtMillis']
    };
    expect(PersistedBookingRecord.fromJson(expired).toJson(), expired);
    for (final patch in [
      {'resolvedAtMillis': 1},
      {'resolution': 'member_cancelled'},
      {'status': 'confirmed'},
      {'resolvedAtMillis': null}
    ]) {
      expect(() => PersistedBookingRecord.fromJson({...expired, ...patch}),
          throwsFormatException);
    }
  });
  test('terminal response matches intent and rejects fabricated or extra data',
      () {
    final request = CancelBookingHoldRequest(
        organizationId: 'org', bookingId: 'booking', requestId: 'cancel');
    final json = <String, dynamic>{
      'schemaVersion': 1,
      'requestId': 'cancel',
      'bookingId': 'booking',
      'status': 'expired',
      'outcome': 'expired',
      'resolvedAtMillis': 1791936000000
    };
    expect(CancelBookingHoldResult.fromJson(json, request: request).status,
        BookingStatus.expired);
    for (final patch in [
      {'status': 'confirmed'},
      {'bookingId': 'other'},
      {'outcome': 'cancelled'},
      {'resolvedAtMillis': null},
      {'private': 'x'}
    ]) {
      expect(
          () => CancelBookingHoldResult.fromJson({...json, ...patch},
              request: request),
          throwsFormatException);
    }
  });
}
