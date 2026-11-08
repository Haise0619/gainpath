import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_app_check_readiness.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_booking_communication_repository.dart';

void main() {
  FirebaseAppCheckReadiness ready() => FirebaseAppCheckReadiness(
      mode: 'production',
      supported: true,
      activate: (_) async {},
      token: () async => 'synthetic-unit-token');
  Map<String, dynamic> response() => {
        'schemaVersion': 2,
        'conversationId': 'pair',
        'memberId': 'member',
        'coachId': 'coach',
        'peerName': 'Jackson',
        'serverNowMillis': 1,
        'canSend': false,
        'reason': 'Read-only',
        'messages': <dynamic>[],
        'unreadCount': 0
      };
  test(
      'pair adapter sends explicit v2 scope and rejects a counterparty mismatch',
      () async {
    final requests = <Map<String, dynamic>>[];
    var result = response();
    final repo = FirebaseBookingCommunicationRepository(
        scope: SessionScope(userId: 'member', organizationId: 'org'),
        isCurrent: () => true,
        readiness: ready(),
        currentUid: () => 'member',
        call: (name, input) async {
          expect(name, 'bookingCommunicationCommand');
          requests.add(input);
          return result;
        });
    expect((await repo.loadConversation(peerId: 'coach')).canSend, false);
    expect(requests.single, {
      'schemaVersion': 2,
      'organizationId': 'org',
      'peerId': 'coach',
      'markRead': false
    });
    result = {...response(), 'coachId': 'different'};
    await expectLater(
        repo.loadConversation(peerId: 'coach'), throwsFormatException);
  });
  test('late pair responses cannot cross account sessions', () async {
    var current = true;
    final repo = FirebaseBookingCommunicationRepository(
        scope: SessionScope(userId: 'member', organizationId: 'org'),
        isCurrent: () => current,
        readiness: ready(),
        currentUid: () => 'member',
        call: (_, __) async {
          current = false;
          return response();
        });
    await expectLater(repo.loadConversation(peerId: 'coach'),
        throwsA(isA<BookingException>()));
  });
}
