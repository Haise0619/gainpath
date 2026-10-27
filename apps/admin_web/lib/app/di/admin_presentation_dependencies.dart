import 'dart:typed_data';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, AuthSession;
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_domain/recommendation.dart';
import '../../features/analytics/application/admin_reporting_gateway.dart';
import '../../infrastructure/firebase/firebase_admin_reporting_gateway.dart';

typedef ReportingGatewayFactory = AdminReportingGateway Function(
    SessionScope scope, bool Function() isCurrent);

/// Composes reporting and neutral capability services for the admin console presentation.
class AdminPresentationDependencies {
  final AdminReportingGateway reportingGateway;
  final AnalyticsRepository analytics;
  final RecommendationRepository recommendation;
  final MembershipRepository membership;
  final BookingRepository booking;
  final AvailabilityRepository availability;
  final CoachRepository coach;
  final UserAccountRepository userAccount;
  final AdminAccountContactRepository accountContact;

  const AdminPresentationDependencies({
    required this.reportingGateway,
    required this.analytics,
    required this.recommendation,
    required this.membership,
    required this.booking,
    required this.availability,
    required this.coach,
    required this.userAccount,
    required this.accountContact,
  });

  factory AdminPresentationDependencies.fromScope({
    required SessionScope scope,
    required bool Function() isCurrent,
    AuthSession? session,
    ReportingGatewayFactory? reportingFactory,
  }) {
    final gateway = reportingFactory?.call(scope, isCurrent) ??
        FirebaseAdminReportingGateway(scope: scope, isCurrent: isCurrent);

    return AdminPresentationDependencies(
      reportingGateway: gateway,
      analytics: const NeutralAnalyticsRepository(),
      recommendation: NeutralRecommendationRepository(),
      membership: NeutralMembershipRepository(),
      booking: const NeutralBookingRepository(),
      availability: NeutralAvailabilityRepository(),
      coach: const NeutralCoachRepository(),
      userAccount: NeutralUserAccountRepository(session: session),
      accountContact: NeutralAdminAccountContactRepository(scope: scope),
    );
  }
}

class NeutralAnalyticsRepository implements AnalyticsRepository {
  const NeutralAnalyticsRepository();

  @override
  List<List<String>> get adminStats => const [
        ['Total revenue', '—', '—'],
        ['Active members', '—', '—'],
        ['Total bookings', '—', '—'],
        ['Avg. posture accuracy', '—', '—'],
      ];

  @override
  List<MuscleGroupShare> get muscleGroupSplit => const [];

  @override
  List<int> get pointsHistory => const [];

  @override
  List<String> get pointsWeekLabels => const [];

  @override
  List<int> get postureTrend => const [];

  @override
  List<int> get postureWeeklyTrend => const [];

  @override
  List<ChartSlice> get retentionRiskMix => const [];

  @override
  List<ChartSlice> get rewardRedemptionMix => const [];

  @override
  List<int> get rewardWeeklyRedemptions => const [];

  @override
  List<String> get sessionWeekLabels => const [];

  @override
  List<int> get sessionsPerWeek => const [];

  @override
  List<ChartSlice> get streakDistribution => const [];

  @override
  List<int> get usageByHour => List.filled(24, 0);

  @override
  List<int> get volumeTrend => const [];

  @override
  List<WeightEntry> get weightHistory => const [];
}

class NeutralRecommendationRepository implements RecommendationRepository {
  @override
  int postureRiskThreshold = 60;

  @override
  List<RiskLead> get atRiskLeads => const [];

  @override
  List<List<String>> get contentGaps => const [];

  @override
  List<RiskLead> get contentLeads => const [];

  @override
  List<RiskLead> get contentLeadsPool => const [];

  @override
  List<List<String>> get riskExercises => const [];

  @override
  List<RiskLead> get trainerLeadsPool => const [];
}

class NeutralMembershipRepository implements MembershipRepository {
  @override
  bool autoRenew = false;

  @override
  String currentPlanId = '';

  @override
  List<MembershipPlan> get membershipPlans => const [];

  @override
  List<RefundClaim> get refundClaims => const [];

  @override
  List<Transaction> get transactions => const [];

  @override
  void addRefundClaim(RefundClaim c) {}

  @override
  void addTransaction(Transaction t) {}
}

class NeutralBookingRepository implements BookingRepository {
  const NeutralBookingRepository();

  @override
  List<Booking> get allBookings => const [];

  @override
  List<Booking> get memberBookings => const [];

  @override
  List<Booking> get coachRoster => const [];
}

class NeutralAvailabilityRepository implements AvailabilityRepository {
  @override
  int dailyBookingCap = 0;

  @override
  int advanceBookingDays = 0;

  @override
  List<BlockedSlot> get blockedSlots => const [];

  @override
  List<WorkingDay> get workingDays => const [];
}

class NeutralCoachRepository implements CoachRepository {
  const NeutralCoachRepository();

  @override
  String get coachName => '—';

  @override
  String get coachEmail => '—';

  @override
  String get coachPhone => '—';

  @override
  Coach get currentCoach => Coach(
        id: 'none',
        name: '—',
        specialty: '—',
        specializationTags: const [],
        rating: 0,
        reviews: 0,
        bio: '—',
        verified: false,
        imageUrl: '',
        branch: '—',
        fee: 0,
        yearsExperience: 0,
        sessionsCompleted: 0,
        responseTime: '—',
        topReviews: const [],
      );

  @override
  List<CoachCertification> get coachCertifications => const [];

  @override
  List<Coach> get coaches => const [];
}

class NeutralUserAccountRepository implements UserAccountRepository {
  final AuthSession? session;

  const NeutralUserAccountRepository({this.session});

  @override
  String get adminName => session?.displayName ?? 'Admin';

  @override
  String get adminEmail => session?.email ?? 'admin@example.com';

  @override
  List<UserAccount> get users => const [];

  @override
  List<Branch> get branches => const [];
}

class _NeutralContactBaseline extends AdminAccountContactBaseline {}

class NeutralAdminAccountContactRepository
    implements AdminAccountContactRepository {
  final SessionScope scope;

  const NeutralAdminAccountContactRepository({required this.scope});

  @override
  Future<AdminAccountContact> load() async => AdminAccountContact(
        displayName: 'Admin',
        email: 'admin@example.com',
        avatarPath: '',
        notificationPreferences: null,
        editBaseline: _NeutralContactBaseline(),
      );

  @override
  Future<AdminAccountContact> save(AdminAccountContact original,
          {required String displayName,
          AccountPhoto? photo,
          bool removePhoto = false}) async =>
      AdminAccountContact(
        displayName: displayName,
        email: original.email,
        avatarPath: original.avatarPath,
        notificationPreferences: original.notificationPreferences,
        editBaseline: _NeutralContactBaseline(),
      );

  @override
  Future<Uint8List?> readPhoto(AdminAccountContact account) async => null;

  @override
  Future<Uint8List?> loadCurrentPhoto() async => null;

  @override
  Future<AdminAccountContact> saveNotificationPreferences(
          AdminAccountContact original,
          {required bool pushAlerts,
          required bool emailAlerts,
          required bool weeklyDigest}) async =>
      AdminAccountContact(
        displayName: original.displayName,
        email: original.email,
        avatarPath: original.avatarPath,
        notificationPreferences: {
          'push': pushAlerts,
          'email': emailAlerts,
          'digest': weeklyDigest,
        },
        editBaseline: _NeutralContactBaseline(),
      );
}
