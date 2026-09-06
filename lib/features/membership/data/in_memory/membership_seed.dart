import 'package:gainpath/features/membership/domain/entities/membership_plan.dart';
import 'package:gainpath/features/membership/domain/entities/refund_claim.dart';
import 'package:gainpath/features/membership/domain/entities/transaction.dart';
import 'package:gainpath/features/membership/domain/enums/refund_status.dart';
import 'package:gainpath/features/membership/domain/enums/transaction_status.dart';

/// In-memory seed data for the membership feature (frontend prototype).
class MembershipSeed {
  static final transactions = <Transaction>[
    Transaction('TXN-2087', 'Coaching session', 140.00,
        DateTime.now().subtract(const Duration(days: 2)), TransactionStatus.cleared),
    Transaction('TXN-2041', 'Membership renewal', 89.00,
        DateTime.now().subtract(const Duration(days: 12)), TransactionStatus.cleared),
    Transaction('TXN-1988', 'Coaching session', 120.00,
        DateTime.now().subtract(const Duration(days: 26)), TransactionStatus.cleared),
    Transaction('TXN-1902', 'Membership renewal', 89.00,
        DateTime.now().subtract(const Duration(days: 42)), TransactionStatus.cleared),
  ];

  static const currentPlanId = 'premium';

  static const membershipPlans = <MembershipPlan>[
    MembershipPlan(
      'basic',
      'Basic',
      49,
      'Everything you need to train smart.',
      [
        'AI form tracking and rep counting',
        'Full gym floor access',
        'Weekly progress reports',
        'Community GamificationSeed.leaderboard',
      ],
    ),
    MembershipPlan(
      'premium',
      'Premium',
      89,
      "Most members' favourite.",
      [
        'Everything in Basic',
        'Book certified IdentitySeed.coaches',
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
        '2x gamification GamificationSeed.points',
      ],
    ),
  ];

  static final refundClaims = <RefundClaim>[
    RefundClaim('CLM-3092', 'Farid Zainal', 'TXN-1902', 'Membership renewal', 89.00,
        'Charged after cancelling',
        'I cancelled my auto-renewal on the app before the charge date but was billed anyway.',
        DateTime.now().subtract(const Duration(days: 3)), RefundStatus.pendingReview),
    RefundClaim('CLM-3088', 'Daniel Wong', 'TXN-1988', 'Coaching session', 120.00,
        'Coach cancelled the session',
        'Jason had to cancel last minute due to an emergency and the session was never rescheduled.',
        DateTime.now().subtract(const Duration(days: 5)), RefundStatus.pendingReview),
  ];
}
