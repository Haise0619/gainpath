import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/coach_profile_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/published_coach_presentation.dart';
import 'member_coach_ux_test.dart' show coachProfile, shell;

Map<String, dynamic> statistics({int sessions = 23, int count = 1}) => {
      'coachId': 'jackson',
      'completedSessions': sessions,
      'reviewCount': count,
      'averageRating': count == 0 ? null : 4.0,
      'branchNames': {'branch_internal_42': 'GainPath Main'},
      'recentReviews': count == 0
          ? []
          : [
              {
                'stars': 4,
                'reviewText': 'Actual saved review.',
                'reviewedAtMillis': 1000,
                'authorLabel': 'Verified member'
              }
            ]
    };
void main() {
  test('public summary validates identity/counts and preserves real zero', () {
    final p = coachProfile().withStatistics(
        CoachPublicStatistics.fromJson(statistics(sessions: 0, count: 0)));
    expect(p.statistics!.completedSessions, 0);
    expect(p.reviewCount, 0);
    expect(p.averageRating, isNull);
    expect(
        () => coachProfile(id: 'other')
            .withStatistics(CoachPublicStatistics.fromJson(statistics())),
        throwsFormatException);
    for (final change in [
      {'completedSessions': -1},
      {'averageRating': 0},
      {
        'recentReviews': [
          {'stars': 9}
        ]
      }
    ]) {
      expect(() => CoachPublicStatistics.fromJson({...statistics(), ...change}),
          throwsFormatException);
    }
  });
  testWidgets(
      'existing profile tiles and review cards use real server data without sample fallback',
      (t) async {
    final p = coachProfile()
        .withStatistics(CoachPublicStatistics.fromJson(statistics()));
    await t.pumpWidget(shell(CoachProfileScreen(
        coach: publishedCoachPresentation(p),
        published: p,
        photo: const SizedBox(),
        onOpenBooking: () {})));
    expect(find.text('23'), findsOneWidget);
    expect(find.text('4.0 · 1 review'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Actual saved review.'), 250);
    expect(find.text('Actual saved review.'), findsOneWidget);
    expect(find.text('Daniel Wong'), findsNothing);
    expect(find.text('60 minutes · 1-on-1 private coaching'), findsNothing);
    expect(find.text('branch_internal_42'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'unknown summaries never generate people or comments and known zero shows zero',
      (t) async {
    final p = coachProfile();
    await t.pumpWidget(shell(CoachProfileScreen(
        coach: publishedCoachPresentation(p),
        published: p,
        photo: const SizedBox())));
    await t.scrollUntilVisible(find.text('Reviews & feedback'), 220);
    expect(find.text('Daniel Wong'), findsNothing);
    expect(find.text('Farid Zainal'), findsNothing);
    await t.pumpWidget(const SizedBox());
    final zero = p.withStatistics(
        CoachPublicStatistics.fromJson(statistics(sessions: 0, count: 0)));
    await t.pumpWidget(shell(CoachProfileScreen(
        coach: publishedCoachPresentation(zero),
        published: zero,
        photo: const SizedBox())));
    expect(find.text('0'), findsNWidgets(2));
    await t.pumpWidget(const SizedBox());
  });
}
