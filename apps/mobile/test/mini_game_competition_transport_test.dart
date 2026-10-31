import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_mini_game_competition_repository.dart';

void main() {
  test(
      'competition uses existing round command namespace and strict account scope',
      () async {
    final scope = SessionScope(userId: 'member', organizationId: 'gym');
    Map<String, dynamic>? sent;
    var uid = 'member';
    final repo = FirebaseMiniGameCompetitionRepository(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => uid,
        call: (input) async {
          sent = input;
          return {
            'schemaVersion': 1,
            'organizationId': 'gym',
            'memberId': 'member',
            'enabled': false,
            'policyVersion': miniGameCompetitionPolicyVersion,
            'revision': 0,
            'changedAtMillis': 0
          };
        });
    final preference = await repo.preference();
    expect(preference.enabled, false);
    expect(sent, {
      'schemaVersion': 1,
      'organizationId': 'gym',
      'action': 'competition',
      'command': {'action': 'preference'}
    });
    uid = 'other';
    expect(repo.current, false);
    await expectLater(
        repo.preference(), throwsA(isA<MiniGameCompetitionSessionChanged>()));
  });
}
