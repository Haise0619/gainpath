import 'package:gainpath_domain/membership.dart';

/// In-memory seed data for the membership feature (frontend prototype).
class MembershipSeed {
  final transactions = <Transaction>[
    Transaction(
        'TXN-2087',
        'Coaching session',
        140.00,
        DateTime.now().subtract(const Duration(days: 2)),
        TransactionStatus.cleared),
    Transaction(
        'TXN-2041',
        'Membership renewal',
        89.00,
        DateTime.now().subtract(const Duration(days: 12)),
        TransactionStatus.cleared),
    Transaction(
        'TXN-1988',
        'Coaching session',
        120.00,
        DateTime.now().subtract(const Duration(days: 26)),
        TransactionStatus.cleared),
    Transaction(
        'TXN-1902',
        'Membership renewal',
        89.00,
        DateTime.now().subtract(const Duration(days: 42)),
        TransactionStatus.cleared),
  ];

  String currentPlanId = 'premium';
  bool autoRenew = true;

  final membershipPlans = <MembershipPlan>[
    MembershipPlan(
      'basic',
      'Basic',
      49,
      'Everything you need to train smart.',
      [
        'AI form tracking and rep counting',
        'Full gym floor access',
        'Weekly progress reports',
        'Community leaderboard',
      ],
    ),
    MembershipPlan(
      'premium',
      'Premium',
      89,
      "Most members' favourite.",
      [
        'Everything in Basic',
        'Book certified coaches',
        'Deep-dive posture and volume analytics',
        'Priority reward-shop drops',
      ],
      popular: true,
    ),
    MembershipPlan(
      'elite',
      'Elite',
      149,
      'Train with a coach in your corner.',
      [
        'Everything in Premium',
        '2 free coaching sessions every month',
        'Priority booking slots',
        '2x gamification points',
      ],
    ),
  ];

  final refundClaims = <RefundClaim>[
    RefundClaim(
        'CLM-3092',
        'Farid Zainal',
        'TXN-1902',
        'Membership renewal',
        89.00,
        'Charged after cancelling',
        'I cancelled my auto-renewal on the app before the charge date but was billed anyway.',
        DateTime.now().subtract(const Duration(days: 3)),
        RefundStatus.pendingReview),
    RefundClaim(
        'CLM-3088',
        'Daniel Wong',
        'TXN-1988',
        'Coaching session',
        120.00,
        'Coach cancelled the session',
        'Jason had to cancel last minute due to an emergency and the session was never rescheduled.',
        DateTime.now().subtract(const Duration(days: 5)),
        RefundStatus.pendingReview),
  ];
}
