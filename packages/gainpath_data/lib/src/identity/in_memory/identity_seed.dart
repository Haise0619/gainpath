import 'package:gainpath_domain/identity.dart';

/// In-memory seed data for the identity feature (frontend prototype).
class IdentitySeed {
  final memberName = 'ZhengYang';

  final memberEmail = 'zhengyang@example.com';

  final memberTier = 'Premium';

  final memberGender = 'Male';

  final memberAge = 21;

  final memberExperience = 'Intermediate';

  final memberActivityLevel = 'Moderately active';

  final memberHeight = 170;

  final memberWeight = 58;

  final memberTrainingFocus = <String>['Build muscle', 'Improve endurance'];

  final coachName = 'Jason Lim';

  final coachEmail = 'jason.lim@furyfitness.my';

  final coachPhone = '+60 12-345 6789';

  /// The signed-in coach's own directory record — the same [Coach] object
  /// members browse. Editing the professional profile coach-side mutates
  /// this instance, so the public directory reflects the change.
  Coach get currentCoach => coaches.firstWhere((c) => c.name == coachName);

  /// AD-M8.3 — the signed-in coach's uploaded credentials. Mutable so an
  /// upload adds a Pending entry that then shows in the list.
  final coachCertifications = <CoachCertification>[
    CoachCertification(
        'NASM Certified Personal Trainer',
        CertificationStatus.verified,
        DateTime.now().subtract(const Duration(days: 210))),
    CoachCertification(
        'First Aid & CPR (Red Crescent)',
        CertificationStatus.verified,
        DateTime.now().subtract(const Duration(days: 120))),
    CoachCertification(
        'Strength Specialist Level 2',
        CertificationStatus.pendingReview,
        DateTime.now().subtract(const Duration(days: 3))),
  ];

  final adminName = 'Muhammad Mustafah';

  final adminEmail = 'admin@gainpath.com';

  final coaches = <Coach>[
    Coach(
      id: 'c1',
      name: 'Jason Lim',
      specialty: 'Strength and Conditioning',
      specializationTags: const [
        'Strength Training',
        'Powerlifting',
        'Beginner Friendly'
      ],
      rating: 4.8,
      reviews: 47,
      bio:
          'Six years coaching compound lifts, with a focus on safe progression for beginners. '
          'I care most about you leaving every session moving better than you arrived.',
      verified: true,
      imageUrl:
          'https://images.unsplash.com/photo-1633332755192-727a05c4013d?auto=format&fit=crop&w=400&q=80',
      branch: 'GainPath Kulim',
      fee: 120,
      yearsExperience: 6,
      sessionsCompleted: 312,
      responseTime: 'Usually responds within 2 hours',
      topReviews: [
        CoachReview(
            'Daniel Wong',
            5,
            'Jason completely fixed my deadlift form in two sessions.',
            DateTime.now().subtract(const Duration(days: 14))),
        CoachReview(
            'Farid Zainal',
            5,
            'Patient and clear with cues. Highly recommend for beginners.',
            DateTime.now().subtract(const Duration(days: 30))),
      ],
    ),
    Coach(
      id: 'c2',
      name: 'Priya Menon',
      specialty: 'Rehabilitation and Mobility',
      specializationTags: const [
        'Injury Recovery',
        'Mobility',
        'Physiotherapy'
      ],
      rating: 4.9,
      reviews: 33,
      bio:
          'Physiotherapy background, specialising in returning to training after injury. '
          'Programming is built around what your body can safely handle this week, not last year.',
      verified: true,
      imageUrl:
          'https://images.unsplash.com/photo-1594381898411-846e7d193883?auto=format&fit=crop&w=400&q=80',
      branch: 'GainPath Sungai Petani',
      fee: 140,
      yearsExperience: 8,
      sessionsCompleted: 260,
      responseTime: 'Usually responds within 1 hour',
      topReviews: [
        CoachReview(
            'Wei Ling Tan',
            5,
            'Helped me return to squatting pain-free after a knee injury.',
            DateTime.now().subtract(const Duration(days: 8))),
        CoachReview(
            'Nurul Huda',
            5,
            'Extremely knowledgeable, explains the why behind every drill.',
            DateTime.now().subtract(const Duration(days: 22))),
      ],
    ),
    Coach(
      id: 'c3',
      name: 'Hafiz Aziz',
      specialty: 'Hypertrophy',
      specializationTags: const [
        'Bodybuilding',
        'Hypertrophy',
        'Nutrition Coaching'
      ],
      rating: 4.6,
      reviews: 58,
      bio: 'Bodybuilding-oriented programming and technique refinement. '
          'I track your numbers every session so progression is never a guess.',
      verified: true,
      imageUrl:
          'https://images.unsplash.com/photo-1567013127542-490d757e51fc?auto=format&fit=crop&w=400&q=80',
      branch: 'GainPath Kulim',
      fee: 110,
      yearsExperience: 4,
      sessionsCompleted: 401,
      responseTime: 'Usually responds within 3 hours',
      topReviews: [
        CoachReview(
            'Daniel Wong',
            4,
            'Great programming, gym can get noisy during peak hours though.',
            DateTime.now().subtract(const Duration(days: 5))),
        CoachReview(
            'Farid Zainal',
            5,
            'Put on visible size in 8 weeks following his plan.',
            DateTime.now().subtract(const Duration(days: 40))),
      ],
    ),
    Coach(
      id: 'c4',
      name: 'Michelle Chan',
      specialty: 'Calisthenics',
      specializationTags: const [
        'Calisthenics',
        'Mobility',
        'Skill Progressions'
      ],
      rating: 4.7,
      reviews: 21,
      bio: 'Bodyweight progressions from first pull-up to advanced skills. '
          'Every plan is broken into small, testable milestones so you always know what to work on next.',
      verified: true,
      imageUrl:
          'https://images.unsplash.com/photo-1548690312-e3b507d8c110?auto=format&fit=crop&w=400&q=80',
      branch: 'GainPath Sungai Petani',
      fee: 130,
      yearsExperience: 5,
      sessionsCompleted: 148,
      responseTime: 'Usually responds within 4 hours',
      topReviews: [
        CoachReview(
            'Wei Ling Tan',
            5,
            'Got my first strict pull-up under her programme.',
            DateTime.now().subtract(const Duration(days: 10))),
        CoachReview(
            'Nurul Huda',
            4,
            'Sessions are tough but she scales everything well.',
            DateTime.now().subtract(const Duration(days: 26))),
      ],
    ),
  ];

  /// Every coach account here has a matching public profile in
  /// [coaches] (matched by name) except newly `Invited` ones, which
  /// haven't completed onboarding yet and so have no profile there —
  /// the Coaches admin page shows those with a "not yet onboarded" state.
  final users = <UserAccount>[
    UserAccount(
        'ZhengYang', 'zhengyang@example.com', 'Member', AccountStatus.active),
    UserAccount(
        'Daniel Wong', 'daniel.w@example.com', 'Member', AccountStatus.active),
    UserAccount('Farid Zainal', 'farid.z@example.com', 'Member',
        AccountStatus.suspended),
    UserAccount('Jason Lim', 'jason.lim@furyfitness.my', 'Coach',
        AccountStatus.verified,
        branch: 'GainPath Kulim', specialty: 'Strength and Conditioning'),
    UserAccount('Priya Menon', 'priya.m@furyfitness.my', 'Coach',
        AccountStatus.verified,
        branch: 'GainPath Sungai Petani',
        specialty: 'Rehabilitation and Mobility'),
    UserAccount(
        'Hafiz Aziz', 'hafiz.a@furyfitness.my', 'Coach', AccountStatus.pending,
        branch: 'GainPath Kulim', specialty: 'Hypertrophy'),
    UserAccount('Michelle Chan', 'michelle.c@furyfitness.my', 'Coach',
        AccountStatus.verified,
        branch: 'GainPath Sungai Petani', specialty: 'Calisthenics'),
    ..._generatedMembers(),
  ];

  /// A realistically-sized member roster (~55 accounts) so the Members
  /// admin page has enough rows to actually demonstrate search and
  /// pagination — the 3 hand-authored members above aren't enough on
  /// their own. Deterministic, not random, so the list is stable and
  /// reviewable.
  static List<UserAccount> _generatedMembers() {
    const firstNames = [
      'Aisyah',
      'Kumar',
      'Siti',
      'Arif',
      'Ravi',
      'Azlan',
      'Fatimah',
      'Choon Hui',
      'Suresh',
      'Amirah',
      'Zulkifli',
      'Mei Ling',
      'Chong',
      'Ismail',
      'Kavitha',
      'Yusof',
      'Chandra',
      'Aiman',
      'Balqis',
      'Haziq',
      'Sofea',
      'Danish',
      'Iman',
      'Naveen',
      'Aina',
      'Firdaus',
      'Poh Ling',
      'Shamsul',
    ];
    const lastNames = [
      'Rahman',
      'Subramaniam',
      'Yusoff',
      'Lee',
      'Krishnan',
      'Ibrahim',
      'Tan',
      'Osman',
      'Pillai',
      'Ong',
      'Hassan',
      'Chew',
      'Nair',
      'Abdullah',
      'Lim',
      'Ganesan',
      'Wan',
      'Sivakumar',
      'Bakar',
      'Loh',
    ];
    final members = <UserAccount>[];
    var idx = 0;
    for (var i = 0; i < firstNames.length; i++) {
      for (var j = 0; j < 2; j++) {
        final last = lastNames[(i * 2 + j) % lastNames.length];
        final name = '${firstNames[i]} $last';
        final email =
            '${firstNames[i].toLowerCase().replaceAll(' ', '')}.${last.toLowerCase()}$idx@example.com';
        final status =
            idx % 8 == 0 ? AccountStatus.suspended : AccountStatus.active;
        members.add(UserAccount(name, email, 'Member', status));
        idx++;
      }
    }
    return members;
  }

  /// AD-M11.1-adjacent — formalises the `Branch` entity from the data
  /// dictionary, which previously only existed as bare strings scattered
  /// across `Coach.branch` / `Booking.branch`. Member and coach counts
  /// are computed live from those same records rather than duplicated
  /// here, so they can never drift out of sync with the roster.
  final branches = <Branch>[
    Branch(
      id: 'br1',
      name: 'GainPath Kulim',
      address: '12 Jalan Kulim Perdana, 09000 Kulim, Kedah',
      contactPhone: '+60 4-490 1122',
      isActive: true,
    ),
    Branch(
      id: 'br2',
      name: 'GainPath Sungai Petani',
      address: '88 Jalan Ibrahim, 08000 Sungai Petani, Kedah',
      contactPhone: '+60 4-421 5580',
      isActive: true,
    ),
  ];
}
