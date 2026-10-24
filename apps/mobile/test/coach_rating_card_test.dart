import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/widgets/coach_card.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/published_coach_presentation.dart';
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('published Coach card shows real aggregate stars and review count', (tester) async {
    final profile = PublishedCoachProfile(id: 'coach-1', fields: CoachProfessionalFields(displayName: 'Coach', specialty: 'Strength', bio: '', specializationTags: ['Strength'], yearsExperience: null), revision: 1, sourceRevision: 1, status: 'published', branchIds: ['main'], createdAtMillis: 1, updatedAtMillis: 1, publishedAtMillis: 1).withRatings(4.5, 2);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CoachCard(coach: publishedCoachPresentation(profile), published: profile, photo: const SizedBox(), onTap: () {}))));
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('  (2)'), findsOneWidget);
  });
}
