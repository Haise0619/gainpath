import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/browse_coaches_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/widgets/coach_card.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/coach_profile_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/published_coach_presentation.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/member_coach_presentation.dart';

PublishedCoachProfile coachProfile(
        {String id = 'jackson',
        String name = 'Jackson',
        int? fee = 10000,
        String bio = 'Strength coaching with clear, practical guidance.',
        double? rating = 4.0,
        int reviews = 1,
        int? experience = 2}) =>
    PublishedCoachProfile(
        id: id,
        fields: CoachProfessionalFields(
            displayName: name,
            specialty: 'Strength',
            bio: bio,
            specializationTags: ['Strength', 'Sports performance'],
            yearsExperience: experience,
            consultationFeeMinor: fee),
        revision: 1,
        sourceRevision: 1,
        status: 'published',
        branchIds: ['branch_internal_42'],
        createdAtMillis: 1,
        updatedAtMillis: 1,
        publishedAtMillis: 1,
        certificationVerified: true,
        approvedCertificationCount: 1,
        averageRating: rating,
        reviewCount: reviews);

class MemberDirectoryFake implements CoachDirectoryRepository {
  MemberDirectoryFake({String userId = 'member'})
      : scope = SessionScope(userId: userId, organizationId: 'o');
  @override
  final SessionScope scope;
  List<PublishedCoachProfile> items = [coachProfile()];
  Completer<CoachDirectoryPage<PublishedCoachProfile>>? pending;
  String? failure;
  String? cursor;
  int reads = 0;
  @override
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPage(
      {String? afterId}) async {
    reads++;
    if (failure != null) throw CoachRepositoryException(failure!);
    if (pending != null) return pending!.future;
    return CoachDirectoryPage(items,
        nextCursor: afterId == null ? cursor : null);
  }

  @override
  Future<PublishedCoachProfile?> loadPublished(String id) async => items.first;
}

Widget shell(Widget child,
        {double scale = 1, Brightness brightness = Brightness.light}) =>
    MaterialApp(
        theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xff6d28d9), brightness: brightness)),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: child);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('new account clears the previous directory query and coaches',
      (tester) async {
    final old = MemberDirectoryFake();
    await tester.pumpWidget(shell(BrowseCoachesScreen(
        live: true, liveRepository: old, isCurrent: () => true)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Jack');
    final next = MemberDirectoryFake(userId: 'other')..items = [];
    await tester.pumpWidget(shell(BrowseCoachesScreen(
        live: true, liveRepository: next, isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.text('Jackson'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    expect(next.reads, 1);
  });
  testWidgets(
      'permission revocation shows session state rather than a network error',
      (tester) async {
    final repo = MemberDirectoryFake()..failure = 'permission-denied';
    await tester.pumpWidget(shell(BrowseCoachesScreen(
        live: true, liveRepository: repo, isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.text('Coaches unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.byType(CoachCard), findsNothing);
  });
  testWidgets(
      'same-account composition rebuild preserves query and loaded page',
      (tester) async {
    await tester.pumpWidget(shell(BrowseCoachesScreen(
        live: true,
        liveRepository: MemberDirectoryFake(),
        isCurrent: () => true)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Jack');
    await tester.pumpAndSettle();
    final replacement = MemberDirectoryFake();
    await tester.pumpWidget(shell(BrowseCoachesScreen(
        live: true, liveRepository: replacement, isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Jack');
    expect(replacement.reads, 0);
  });
  testWidgets('profile removes unsupported metrics and keeps booking visible',
      (tester) async {
    final p = coachProfile();
    var booked = 0;
    await tester.pumpWidget(shell(CoachProfileScreen(
        coach: publishedCoachPresentation(p),
        published: p,
        photo: const SizedBox(),
        onOpenBooking: () => booked++,
        onOpenSchedule: () {})));
    expect(find.text('Sessions run'), findsNothing);
    expect(find.text('What members say'), findsNothing);
    expect(find.text('Duration'), findsNothing);
    expect(find.text('4.0 · 1 review'), findsOneWidget);
    expect(find.text('branch_internal_42'), findsNothing);
    expect(find.byKey(const ValueKey('coach-booking-bar')), findsOneWidget);
    await tester.tap(find.text('Book a session'));
    expect(booked, 1);
    await tester.scrollUntilVisible(find.text('About Jackson'), 200);
    expect(find.text(p.fields.bio), findsOneWidget);
  });
  testWidgets(
      'missing price and biography are truthful and booking stays disabled',
      (tester) async {
    final p = coachProfile(fee: null, bio: '', rating: null, reviews: 0);
    await tester.pumpWidget(shell(CoachProfileScreen(
        coach: publishedCoachPresentation(p),
        published: p,
        photo: const SizedBox(),
        onOpenBooking: () {})));
    expect(find.text('Not yet rated'), findsOneWidget);
    expect(find.text('Price unavailable'), findsWidgets);
    expect(find.text('RM 0.00'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Book a session'))
            .onPressed,
        isNull);
    await tester.scrollUntilVisible(
        find.text('Biography not provided yet.'), 200);
    expect(find.text('Biography not provided yet.'), findsOneWidget);
  });
  for (final count in [0, 1, 12]) {
    testWidgets('card formats $count reviews with location and real price',
        (tester) async {
      final p = coachProfile(rating: count == 0 ? null : 4.0, reviews: count);
      await tester.pumpWidget(shell(Scaffold(
          body: CoachCard(
              coach: publishedCoachPresentation(p),
              published: p,
              photo: const SizedBox(),
              onTap: () {}))));
      expect(
          find.text(count == 0
              ? 'Not yet rated'
              : '4.0 · $count ${count == 1 ? 'review' : 'reviews'}'),
          findsOneWidget);
      expect(find.text('Location confirmed when booking'), findsOneWidget);
      expect(find.text('branch_internal_42'), findsNothing);
    });
  }
  testWidgets(
      'directory distinguishes loading, failure, empty and search matches',
      (tester) async {
    final repo = MemberDirectoryFake()..pending = Completer();
    await tester.pumpWidget(shell(BrowseCoachesScreen(
        live: true, liveRepository: repo, isCurrent: () => true)));
    await tester.pump();
    expect(find.text('Finding your coaches…'), findsOneWidget);
    expect(find.text('No coaches available yet.'), findsNothing);
    repo.pending!.complete(CoachDirectoryPage(repo.items));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'unmatched');
    await tester.pumpAndSettle();
    expect(find.text('No matching coaches'), findsOneWidget);
    await tester.tap(find.text('Clear filters').first);
    await tester.pumpAndSettle();
    expect(find.text('Jackson'), findsOneWidget);
  });
  testWidgets('price sorting puts real fees before unavailable prices',
      (tester) async {
    final repo = MemberDirectoryFake()
      ..items = [
        coachProfile(id: 'missing', name: 'Missing', fee: null),
        coachProfile(id: 'high', name: 'Higher', fee: 15000),
        coachProfile(id: 'low', name: 'Lower', fee: 5000)
      ];
    await tester.pumpWidget(shell(BrowseCoachesScreen(
        live: true, liveRepository: repo, isCurrent: () => true)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sort coaches'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Price: low to high').last);
    await tester.pumpAndSettle();
    final cards = tester.widgetList<CoachCard>(find.byType(CoachCard)).toList();
    expect(cards.take(2).map((c) => c.coach.id), ['low', 'high']);
    await tester.scrollUntilVisible(find.text('Missing'), 150,
        scrollable: find
            .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('Missing'), findsOneWidget);
  });
  for (final width in [320.0, 360.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('profile and card fit ${width}px at 200% in $brightness',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final p = coachProfile(name: 'Jackson Alexander Long Coach Name');
        await tester.pumpWidget(shell(
            CoachProfileScreen(
                coach: publishedCoachPresentation(p),
                published: p,
                photo: const SizedBox(),
                onOpenBooking: () {},
                onOpenSchedule: () {}),
            scale: 2,
            brightness: brightness));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getBottomLeft(find.text('Book a session')).dy,
            lessThanOrEqualTo(800));
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(shell(
            Scaffold(
                body: SingleChildScrollView(
                    child: CoachCard(
                        coach: publishedCoachPresentation(p),
                        published: p,
                        photo: const SizedBox(),
                        onTap: () {}))),
            scale: 2,
            brightness: brightness));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  test('location labels use authorized mappings and never expose internal IDs',
      () {
    expect(
        memberCoachLocation(['internal'],
            branchNames: {'internal': 'Bukit Jalil Studio'}),
        'Bukit Jalil Studio');
    expect(
        memberCoachLocation(['internal']), 'Location confirmed when booking');
    expect(memberCoachLocation([]), 'Location confirmed when booking');
    expect(
        memberCoachLocation(['a', 'b'],
            branchNames: {'a': 'Studio', 'b': 'Studio'}),
        'Studio');
  });
  test(
      'zero and missing published fees are unavailable under paid booking rules',
      () {
    for (final fee in [null, 0]) {
      final p = coachProfile(fee: fee);
      expect(memberCoachFeeMinor(publishedCoachPresentation(p), p), isNull);
    }
  });
  testWidgets('network error has retry and is distinct from an empty directory',
      (tester) async {
    final repo = MemberDirectoryFake()..failure = 'unavailable';
    await tester.pumpWidget(shell(BrowseCoachesScreen(
        live: true, liveRepository: repo, isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.text('Could not load coaches'), findsOneWidget);
    expect(find.text('No coaches available yet.'), findsNothing);
    repo.failure = null;
    repo.items = [];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('No coaches available yet.'), findsOneWidget);
    expect(find.text('Not yet rated'), findsNothing);
  });
  testWidgets('filter and query remain when returning from a profile',
      (tester) async {
    final repo = MemberDirectoryFake();
    final navigator = GlobalKey<NavigatorState>();
    var bookings = 0;
    await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        home: BrowseCoachesScreen(
            live: true,
            liveRepository: repo,
            isCurrent: () => true,
            onOpenBookings: () => bookings++,
            onOpenPublished: (id) => navigator.currentState!.push(
                MaterialPageRoute(
                    builder: (_) => Scaffold(
                        appBar: AppBar(title: Text('Profile $id')),
                        body: const Text('Profile body')))))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('My bookings'));
    expect(bookings, 1);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Strength'));
    await tester.enterText(find.byType(TextField), 'Jack');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jackson'));
    await tester.pumpAndSettle();
    expect(find.text('Profile jackson'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Jack');
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Strength'))
            .selected,
        isTrue);
    expect(find.text('Jackson'), findsOneWidget);
  });
  testWidgets(
      'pagination is after results and retries without losing existing coaches',
      (tester) async {
    final repo = MemberDirectoryFake()..cursor = 'next';
    await tester.pumpWidget(shell(BrowseCoachesScreen(
        live: true, liveRepository: repo, isCurrent: () => true)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Load more coaches'), 150,
        scrollable: find
            .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable))
            .first);
    expect(tester.getTopLeft(find.text('Load more coaches')).dy,
        greaterThan(tester.getTopLeft(find.text('Jackson')).dy));
    repo.failure = 'unavailable';
    await tester.tap(find.text('Load more coaches'));
    await tester.pumpAndSettle();
    expect(find.text('Retry loading more'), findsOneWidget);
    expect(find.byType(CoachCard), findsOneWidget);
    repo.failure = null;
    await tester.tap(find.text('Retry loading more'));
    await tester.pumpAndSettle();
    expect(find.text('Load more coaches'), findsNothing);
    expect(repo.reads, 3);
  });
  testWidgets('late former-account response never renders coach identities',
      (tester) async {
    var current = true;
    final repo = MemberDirectoryFake()..pending = Completer();
    await tester.pumpWidget(shell(BrowseCoachesScreen(
        live: true, liveRepository: repo, isCurrent: () => current)));
    current = false;
    repo.pending!.complete(CoachDirectoryPage(repo.items));
    await tester.pumpAndSettle();
    expect(find.text('Jackson'), findsNothing);
    expect(find.text('Coaches unavailable'), findsOneWidget);
  });
  testWidgets(
      'missing booking callback disables action; schedule uses supplied callback',
      (tester) async {
    var schedules = 0;
    final p = coachProfile();
    await tester.pumpWidget(shell(CoachProfileScreen(
        coach: publishedCoachPresentation(p),
        published: p,
        photo: const SizedBox(),
        onOpenSchedule: () => schedules++)));
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Book a session'))
            .onPressed,
        isNull);
    await tester.scrollUntilVisible(find.text('View schedule'), 200);
    await tester.ensureVisible(find.text('View schedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View schedule'));
    expect(schedules, 1);
  });
}
