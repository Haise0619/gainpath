import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/infrastructure/firebase/firebase_real_workout_gateway.dart';
import 'package:gainpath_mobile/features/workout/domain/real_workout_sync.dart';
import 'package:gainpath_mobile/features/workout/domain/real_workout_contract.dart';
import 'real_workout_outbox_test.dart' as support;

void main() {
  test('consent command is scoped and validates its server acknowledgement',
      () async {
    String? name;
    Map<String, Object?>? request;
    final gateway = FirebaseRealWorkoutGateway(
        scope: support.scope,
        activeAccount: () => true,
        invoke: (n, p) async {
          name = n;
          request = p;
          return {...support.ackJson, 'requestId': p['requestId']};
        });
    final ack = await gateway.acknowledge(support.scope, 'request');
    expect(name, 'acknowledgeWorkoutConsentCommand');
    expect(request!['consented'], true);
    expect(ack.scope, support.scope);
    await expectLater(
        gateway.acknowledge(
            SessionScope(userId: 'other', organizationId: 'gainpath'),
            'request'),
        throwsA(isA<WorkoutGatewayFailure>()));
  });
  test(
      'revocation rejects an unrelated response and rechecks account after network',
      () async {
    var active = true;
    final gateway = FirebaseRealWorkoutGateway(
        scope: support.scope,
        activeAccount: () => active,
        invoke: (n, p) async {
          active = false;
          return {...p, 'revokedAtMillis': 5000};
        });
    await expectLater(
        gateway.revoke(
            WorkoutConsentAcknowledgement.fromJson(support.ackJson), 'request'),
        throwsA(isA<WorkoutGatewayFailure>()));
  });
  test('revocation accepts only its exact bounded receipt', () async {
    var extra = false;
    final gateway = FirebaseRealWorkoutGateway(
        scope: support.scope,
        activeAccount: () => true,
        invoke: (n, p) async =>
            {...p, 'revokedAtMillis': 5000, if (extra) 'rawPose': []});
    final ack = WorkoutConsentAcknowledgement.fromJson(support.ackJson);
    await gateway.revoke(ack, 'request');
    extra = true;
    await expectLater(gateway.revoke(ack, 'request'), throwsFormatException);
  });
}
