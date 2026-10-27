import 'package:gainpath_domain/gamification.dart';

Map<String, dynamic> participationFixture(
        {String status = 'overview',
        bool active = false,
        String? attemptId,
        int balance = 0,
        int earned = 0}) =>
    {
      'schemaVersion': 2,
      'organizationId': 'gainpath',
      'memberId': 'member',
      'mode': 'participation',
      'redeemable': true,
      'physicalVerified': false,
      'overview': {
        'today': '2026-10-27',
        'timezone': 'Asia/Kuala_Lumpur',
        'issuanceActive': active,
        'policy': MiniGameRewardPolicy().toJson(),
        'balance': balance,
        'earnedToday': earned,
        'remainingToday': 60 - earned,
        'claimsToday': earned == 0 ? 0 : 1
      },
      'result': {'status': status, 'attemptId': attemptId},
      'award': ['awarded', 'already-awarded'].contains(status)
          ? {
              'schemaVersion': 2,
              'organizationId': 'gainpath',
              'memberId': 'member',
              'attemptId': attemptId,
              'awardId': 'participation_${'d' * 64}',
              'gameId': 'move-catch-v1',
              'points': 20,
              'verification': 'participation',
              'redeemable': true,
              'physicalVerified': false,
              'premiumBonus': false,
              'policyVersion': 'mini-game-rewards-draft-v1',
              'policySnapshot': MiniGameRewardPolicy().toJson(),
              'completedAtMillis':
                  DateTime.parse('2026-10-27T08:00:00Z').millisecondsSinceEpoch,
              'awardedAtMillis':
                  DateTime.parse('2026-10-27T08:00:01Z').millisecondsSinceEpoch,
              'date': '2026-10-27'
            }
          : null
    };
