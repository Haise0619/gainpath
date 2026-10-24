import 'dart:async';
import 'package:test/test.dart';
import 'package:gainpath_data/gainpath_data.dart';

void main() {
  test('ignores a late response after account changes', () async {
    var current = true;
    final pending = Completer<Map<String, dynamic>>();
    final r = ScopedGoogleIntegrationRepository(
        organizationId: 'org',
        userId: 'admin',
        isCurrent: () => current,
        currentUid: () => 'admin',
        call: (_, __) => pending.future);
    final result = r.load();
    current = false;
    pending.complete({
      'schemaVersion': 1,
      'connectionStatus': 'connected',
      'calendarStatus': 'ready'
    });
    await expectLater(result, throwsStateError);
  });
  test('rejects an authorization URL outside Google', () async {
    final r = ScopedGoogleIntegrationRepository(
        organizationId: 'org',
        userId: 'admin',
        isCurrent: () => true,
        currentUid: () => 'admin',
        call: (_, __) async =>
            {'authorizationUrl': 'https://evil.example/consent'});
    await expectLater(r.beginConnect(), throwsFormatException);
  });
  test('never allows caller-selected org, recipient, Calendar ID or tokens',
      () async {
    Map<String, dynamic>? sent;
    final r = ScopedGoogleIntegrationRepository(
        organizationId: 'org',
        userId: 'admin',
        isCurrent: () => true,
        currentUid: () => 'admin',
        call: (name, input) async {
          sent = input;
          return {'status': 'delivered'};
        });
    expect(await r.syncBooking('booking', email: true), 'delivered');
    expect(sent, {
      'organizationId': 'org',
      'bookingId': 'booking',
      'kind': 'email',
      'confirmed': true
    });
  });
}
