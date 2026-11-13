import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/browse_coaches_screen.dart';

PublishedCoachProfile _coach({
  String id = 'coach-1',
  String name = 'Jackson Alexander',
  String specialty = 'Strength',
  int fee = 12000,
  int experience = 5,
  double rating = 4.8,
  int reviews = 15,
}) =>
    PublishedCoachProfile(
      id: id,
      fields: CoachProfessionalFields(
        displayName: name,
        specialty: specialty,
        bio: 'Certified strength and conditioning coach with 5 years experience.',
        specializationTags: [specialty, 'Powerlifting'],
        yearsExperience: experience,
        consultationFeeMinor: fee,
      ),
      revision: 1,
      sourceRevision: 1,
      status: 'published',
      branchIds: ['branch_1'],
      createdAtMillis: 1000,
      updatedAtMillis: 1000,
      publishedAtMillis: 1000,
      certificationVerified: true,
      approvedCertificationCount: 1,
      averageRating: rating,
      reviewCount: reviews,
    );

class _TestDirectoryRepository implements CoachDirectoryRepository {
  _TestDirectoryRepository({required this.coaches})
      : scope = SessionScope(userId: 'test-user', organizationId: 'test-org');

  @override
  final SessionScope scope;
  final List<PublishedCoachProfile> coaches;

  @override
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPage({String? afterId}) async {
    return CoachDirectoryPage(coaches);
  }

  @override
  Future<PublishedCoachProfile?> loadPublished(String id) async =>
      coaches.firstWhere((c) => c.id == id, orElse: () => coaches.first);
}

Widget _wrap(Widget child, {double width = 360.0, double scale = 1.0}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff6d28d9)),
    ),
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: TextScaler.linear(scale),
      ),
      child: SizedBox(
        width: width,
        height: 800,
        child: child,
      ),
    ),
  );
}

void main() {
  group('BrowseCoachesScreen Search UX & Filter Window', () {
    late _TestDirectoryRepository repo;

    setUp(() {
      repo = _TestDirectoryRepository(coaches: [
        _coach(id: 'c1', name: 'Jackson', specialty: 'Strength'),
        _coach(id: 'c2', name: 'Elena', specialty: 'Mobility'),
        _coach(id: 'c3', name: 'Marcus', specialty: 'Conditioning'),
      ]);
    });

    testWidgets('clicking a category shows removable tag inside the search bar',
        (tester) async {
      await tester.pumpWidget(_wrap(BrowseCoachesScreen(
        live: true,
        liveRepository: repo,
        isCurrent: () => true,
      )));
      await tester.pumpAndSettle();

      // Initially, no removable tag in the search bar
      expect(find.byTooltip('Remove Strength filter'), findsNothing);

      // Tap "Strength" in the category row
      await tester.tap(find.widgetWithText(ChoiceChip, 'Strength'));
      await tester.pumpAndSettle();

      // Now the removable tag appears inside the search bar
      expect(find.byTooltip('Remove Strength filter'), findsOneWidget);
      expect(find.text('Strength'), findsWidgets); // One in tag, one in chip

      // Tap the remove icon on the tag
      await tester.tap(find.byTooltip('Remove Strength filter'));
      await tester.pumpAndSettle();

      // Removable tag is removed
      expect(find.byTooltip('Remove Strength filter'), findsNothing);
    });

    testWidgets('clear filters action appears on the right side of the search bar',
        (tester) async {
      await tester.pumpWidget(_wrap(BrowseCoachesScreen(
        live: true,
        liveRepository: repo,
        isCurrent: () => true,
      )));
      await tester.pumpAndSettle();

      // Before filtering, no "Clear filters" on the right side of the search bar
      expect(find.text('Clear filters'), findsNothing);

      // Select category "Mobility"
      await tester.tap(find.widgetWithText(ChoiceChip, 'Mobility'));
      await tester.pumpAndSettle();

      // "Clear filters" is now visible in the search bar
      expect(find.text('Clear filters'), findsOneWidget);
      expect(find.text('Elena'), findsOneWidget);
      expect(find.text('Jackson'), findsNothing);

      // Tap "Clear filters"
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      // Filters are reset and all coaches are displayed again
      expect(find.text('Clear filters'), findsNothing);
      expect(find.text('Jackson'), findsOneWidget);
      expect(find.text('Elena'), findsOneWidget);
      expect(find.text('Marcus'), findsOneWidget);
    });

    testWidgets('typing a search query shows clear filters on right side',
        (tester) async {
      await tester.pumpWidget(_wrap(BrowseCoachesScreen(
        live: true,
        liveRepository: repo,
        isCurrent: () => true,
      )));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Marcus');
      await tester.pumpAndSettle();

      expect(find.text('Clear filters'), findsOneWidget);
      expect(find.text('Marcus'), findsWidgets); // Typed in textfield and in coach card
      expect(find.text('Jackson'), findsNothing);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      expect(find.text('Clear filters'), findsNothing);
      expect(find.text('Jackson'), findsOneWidget);
    });

    testWidgets('filter window displays optimized modal with sort options and actions',
        (tester) async {
      await tester.pumpWidget(_wrap(BrowseCoachesScreen(
        live: true,
        liveRepository: repo,
        isCurrent: () => true,
      )));
      await tester.pumpAndSettle();

      // Open filter modal
      await tester.tap(find.byTooltip('Filter and sort coaches'));
      await tester.pumpAndSettle();

      // Verify title, close button, section headings, and sort option labels
      expect(find.text('Filter and sort'), findsOneWidget);
      expect(find.byTooltip('Close filters'), findsOneWidget);
      expect(find.text('Specialty'), findsOneWidget);
      expect(find.text('Sort by'), findsOneWidget);
      expect(find.text('Highest rated'), findsOneWidget);
      expect(find.text('Price: low to high'), findsOneWidget);
      expect(find.text('Most experienced'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);

      // Select "Price: low to high" and apply
      await tester.tap(find.text('Price: low to high'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Modal closed
      expect(find.text('Filter and sort'), findsNothing);
      // "Clear filters" is visible because custom sorting is active
      expect(find.text('Clear filters'), findsOneWidget);
    });

    testWidgets('filter modal selecting specialty reflects removable tag in search bar',
        (tester) async {
      await tester.pumpWidget(_wrap(BrowseCoachesScreen(
        live: true,
        liveRepository: repo,
        isCurrent: () => true,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Filter and sort coaches'));
      await tester.pumpAndSettle();

      // Tap Conditioning in the modal (using last to pick from modal chips)
      await tester.tap(find.widgetWithText(ChoiceChip, 'Conditioning').last);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Removable tag appears in the search bar
      expect(find.byTooltip('Remove Conditioning filter'), findsOneWidget);
      expect(find.text('Marcus'), findsOneWidget);
      expect(find.text('Jackson'), findsNothing);
    });

    testWidgets('responsive layout on 320px width at 200% text scale without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(
        BrowseCoachesScreen(
          live: true,
          liveRepository: repo,
          isCurrent: () => true,
        ),
        width: 320.0,
        scale: 2.0,
      ));
      await tester.pumpAndSettle();

      // Tap Strength category
      await tester.tap(find.widgetWithText(ChoiceChip, 'Strength'));
      await tester.pumpAndSettle();

      // Enter query
      await tester.enterText(find.byType(TextField), 'Jack');
      await tester.pumpAndSettle();

      // Ensure zero RenderFlex overflow exceptions occurred
      expect(tester.takeException(), isNull);
    });
  });
}
