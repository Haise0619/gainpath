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
  String branchId = 'branch_1',
}) =>
    PublishedCoachProfile(
      id: id,
      fields: CoachProfessionalFields(
        displayName: name,
        specialty: specialty,
        bio:
            'Certified strength and conditioning coach with 5 years experience.',
        specializationTags: [specialty, 'Powerlifting'],
        yearsExperience: experience,
        consultationFeeMinor: fee,
      ),
      revision: 1,
      sourceRevision: 1,
      status: 'published',
      branchIds: [branchId],
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
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPage(
      {String? afterId}) async {
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
  group('BrowseCoachesScreen Filtering & Search Refinements', () {
    late _TestDirectoryRepository repo;

    setUp(() {
      repo = _TestDirectoryRepository(coaches: [
        _coach(
            id: 'c1',
            name: 'Jackson',
            specialty: 'Strength',
            branchId: 'branch_1'),
        _coach(
            id: 'c2',
            name: 'Elena',
            specialty: 'Mobility',
            branchId: 'branch_1'),
        _coach(
            id: 'c3',
            name: 'Marcus',
            specialty: 'Conditioning',
            branchId: 'branch_2'),
      ]);
    });

    testWidgets(
        'chips are removed from main page; opening filter modal allows specialty selection and shows active summary',
        (tester) async {
      await tester.pumpWidget(_wrap(BrowseCoachesScreen(
        live: true,
        liveRepository: repo,
        isCurrent: () => true,
        loadBranches: () async => {
          'branch_1': 'GainPath Main',
          'branch_2': 'GainPath Downtown',
        },
      )));
      await tester.pumpAndSettle();

      // 1. Permanently visible filter chips are removed from the main page
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Clear all'), findsNothing);

      // Search bar and adjacent filter icon button are visible
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Filter and sort coaches'), findsOneWidget);

      // Initially all coaches visible
      expect(find.text('Jackson'), findsOneWidget);
      expect(find.text('Elena'), findsOneWidget);
      expect(find.text('Marcus'), findsOneWidget);

      // Default count displayed; redundant summary hidden
      expect(find.text('3 coaches available'), findsOneWidget);
      expect(find.textContaining('All specialties'), findsNothing);

      // 2. Open Filter Modal Bottom Sheet
      await tester.tap(find.byTooltip('Filter and sort coaches'));
      await tester.pumpAndSettle();

      // Bottom sheet contains Title, Location, Specialty, Sort by, Reset All, and Apply Filters
      expect(find.text('Filter and sort'), findsOneWidget);
      expect(find.text('Training location'), findsOneWidget);
      expect(find.text('Specialty'), findsOneWidget);
      expect(find.text('Sort by'), findsOneWidget);
      expect(find.text('Reset All'), findsOneWidget);
      expect(find.text('Apply Filters'), findsOneWidget);

      // Select "Strength" ChoiceChip inside modal
      await tester.tap(find.widgetWithText(ChoiceChip, 'Strength'));
      await tester.pumpAndSettle();

      // Tap Apply Filters
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      // Bottom sheet closed
      expect(find.text('Filter and sort'), findsNothing);

      // Only Jackson matches Strength
      expect(find.text('Jackson'), findsOneWidget);
      expect(find.text('Elena'), findsNothing);
      expect(find.text('Marcus'), findsNothing);

      // Active filter indicator uses subtle dot without red alert Badge
      expect(find.byType(Badge), findsNothing);

      // Active filter summary is displayed with count under search bar
      expect(find.text('Strength'), findsWidgets);
      expect(find.byKey(const Key('coach-active-filter-indicator')),
          findsOneWidget);
      expect(find.textContaining('1 coach available'), findsOneWidget);

      // Tap the clear icon on the active filter summary
      await tester.tap(find.byTooltip('Filter and sort coaches'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      // Summary is cleared and hidden, all 3 coaches visible again
      expect(
          find.byKey(const Key('coach-active-filter-indicator')), findsNothing);
      expect(find.text('3 coaches available'), findsOneWidget);
      expect(find.text('Jackson'), findsOneWidget);
      expect(find.text('Elena'), findsOneWidget);
      expect(find.text('Marcus'), findsOneWidget);
    });

    testWidgets(
        'training location filter in modal shows compact summary "GainPath Main · All specialties"',
        (tester) async {
      await tester.pumpWidget(_wrap(BrowseCoachesScreen(
        live: true,
        liveRepository: repo,
        isCurrent: () => true,
        loadBranches: () async => {
          'branch_1': 'GainPath Main',
          'branch_2': 'GainPath Downtown',
        },
      )));
      await tester.pumpAndSettle();

      // Open filter modal
      await tester.tap(find.byTooltip('Filter and sort coaches'));
      await tester.pumpAndSettle();

      // Training location chips are visible inside modal
      expect(find.widgetWithText(ChoiceChip, 'All branches'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'GainPath Main'), findsOneWidget);
      expect(
          find.widgetWithText(ChoiceChip, 'GainPath Downtown'), findsOneWidget);

      // Select GainPath Main
      await tester.tap(find.widgetWithText(ChoiceChip, 'GainPath Main'));
      await tester.pumpAndSettle();

      // Apply
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      // Active filter summary shows "GainPath Main · All specialties"
      expect(find.text('GainPath Main'), findsWidgets);
      expect(find.byKey(const Key('coach-active-filter-indicator')),
          findsOneWidget);
      expect(find.textContaining('2 coaches available'), findsOneWidget);
      expect(find.text('Jackson'), findsOneWidget);
      expect(find.text('Elena'), findsOneWidget);
      expect(find.text('Marcus'), findsNothing);

      // Re-open filter modal and test Reset All
      await tester.tap(find.byTooltip('Filter and sort coaches'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset All'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      // All filters reset to defaults; redundant summary hidden
      expect(
          find.textContaining('GainPath Main · All specialties'), findsNothing);
      expect(find.text('3 coaches available'), findsOneWidget);
    });

    testWidgets(
        'combined location and specialty filter produces combined summary',
        (tester) async {
      await tester.pumpWidget(_wrap(BrowseCoachesScreen(
        live: true,
        liveRepository: repo,
        isCurrent: () => true,
        loadBranches: () async => {
          'branch_1': 'GainPath Main',
          'branch_2': 'GainPath Downtown',
        },
      )));
      await tester.pumpAndSettle();

      // Open filter modal
      await tester.tap(find.byTooltip('Filter and sort coaches'));
      await tester.pumpAndSettle();

      // Select GainPath Main and Mobility
      await tester.tap(find.widgetWithText(ChoiceChip, 'GainPath Main'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Mobility'));
      await tester.pumpAndSettle();

      // Active count badge in modal header shows 2 active
      expect(find.text('2 active'), findsOneWidget);

      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      // Summary shows combined "GainPath Main · Mobility"
      expect(find.text('GainPath Main'), findsWidgets);
      expect(find.text('Mobility'), findsWidgets);
      expect(find.textContaining('1 coach available'), findsOneWidget);
      expect(find.text('Elena'), findsOneWidget);
      expect(find.text('Jackson'), findsNothing);
      expect(find.text('Marcus'), findsNothing);
      expect(find.byType(Badge), findsNothing);
    });

    testWidgets(
        'typing a search query shows clear button inside the search field',
        (tester) async {
      await tester.pumpWidget(_wrap(BrowseCoachesScreen(
        live: true,
        liveRepository: repo,
        isCurrent: () => true,
      )));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Clear search query'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Marcus');
      await tester.pumpAndSettle();

      expect(find.byTooltip('Clear search query'), findsOneWidget);
      expect(find.text('Marcus'), findsWidgets);
      expect(find.text('Jackson'), findsNothing);

      // Tap clear query button
      await tester.tap(find.byTooltip('Clear search query'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Clear search query'), findsNothing);
      expect(find.text('Jackson'), findsOneWidget);
      expect(find.text('Marcus'), findsOneWidget);
      expect(find.text('Elena'), findsOneWidget);
    });

    for (final width in [320.0, 360.0, 393.0, 430.0]) {
      testWidgets(
          'responsive layout on ${width.toInt()}px width at 200% text scale without overflow',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_wrap(
          BrowseCoachesScreen(
            live: true,
            liveRepository: repo,
            isCurrent: () => true,
            loadBranches: () async => {
              'branch_1': 'GainPath Main',
              'branch_2': 'GainPath Downtown',
            },
          ),
          width: width,
          scale: 2.0,
        ));
        await tester.pumpAndSettle();

        // Enter query
        await tester.enterText(find.byType(TextField), 'Jack');
        await tester.pumpAndSettle();

        // Open filter modal
        await tester.tap(find.byTooltip('Filter and sort coaches'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Select a branch and a specialty in modal
        await tester.tap(find.widgetWithText(ChoiceChip, 'GainPath Main'));
        await tester.tap(find.widgetWithText(ChoiceChip, 'Strength'));
        await tester.pumpAndSettle();

        // Verify Apply Filters and Reset All are hit-testable without clipping
        expect(find.text('Apply Filters').hitTestable(), findsOneWidget);
        expect(find.text('Reset All').hitTestable(), findsOneWidget);

        // Apply
        await tester.tap(find.text('Apply Filters'));
        await tester.pumpAndSettle();

        // Ensure zero RenderFlex overflow exceptions occurred
        expect(tester.takeException(), isNull);
      });
    }
  });
}
