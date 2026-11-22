import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_mobile/features/content/presentation/member/member_announcements.dart';
import '../../../test_support/announcement_render_fonts.dart';

Announcement entry(String id,
        {AnnouncementStatus status = AnnouncementStatus.published,
        int start = -1,
        int end = 7}) =>
    Announcement(
        id: id,
        title: id,
        body: 'Real content fixture',
        status: status,
        validFrom: DateTime.now().add(Duration(days: start)),
        validTo: DateTime.now().add(Duration(days: end)));

class _Reader implements AnnouncementReader {
  List<Announcement> items = [];
  Completer<AnnouncementPage>? pending;
  bool fail = false;
  @override
  Future<AnnouncementPage> loadAnnouncements({String? afterId}) async {
    if (fail) throw StateError('Private transport detail');
    if (pending != null) return pending!.future;
    return afterId == null
        ? AnnouncementPage(items.take(2),
            nextCursor: items.length > 2 ? items[1].id : null)
        : AnnouncementPage(items.skip(2));
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['GAINPATH_ANNOUNCEMENT_SCREENSHOTS'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('announcement-fixture-mobile')));
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      await File('$directory/fixture-$name.png').writeAsBytes(bytes);
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('display window includes the Malaysian start and excludes the end', () {
    final start = DateTime.parse('2026-11-20T00:00:00+08:00');
    final end = DateTime.parse('2026-11-21T00:00:00+08:00');
    final announcement =
        entry('Boundary').copyWith(validFrom: start, validTo: end);
    const tick = Duration(microseconds: 1);
    expect(announcement.displayStatusAt(start.subtract(tick)),
        AnnouncementDisplayStatus.scheduled);
    expect(
        announcement.displayStatusAt(start), AnnouncementDisplayStatus.active);
    expect(announcement.displayStatusAt(end.subtract(tick)),
        AnnouncementDisplayStatus.active);
    expect(
        announcement.displayStatusAt(end), AnnouncementDisplayStatus.expired);
  });

  testWidgets('compact cards prioritize important content and open details',
      (tester) async {
    final theme = await announcementFixtureTheme();
    tester.view.physicalSize = const Size(412, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final reader = _Reader()
      ..items = [
        entry('Weekend recovery workshop'),
        Announcement(
          id: 'cable-servicing',
          title: 'Cable stations reopen at noon',
          validFrom: DateTime.now().subtract(const Duration(days: 2)),
          validTo: DateTime.now().add(const Duration(days: 2)),
          priority: AnnouncementPriority.important,
          category: AnnouncementCategory.maintenance,
          audience: AnnouncementAudience.branches,
          targetBranchIds: const ['central'],
          targetBranchNames: const ['Central Gym'],
          body:
              'Routine servicing is in progress. The cable stations reopen at noon. Please use the free weights area until then.',
        ),
        entry('Training floor reminders', start: -3),
      ];
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      builder: (_, child) => RepaintBoundary(
        key: const Key('announcement-fixture-mobile'),
        child: child!,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Member Home')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: MemberAnnouncements(reader: reader, compact: true),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Cable stations reopen at noon')).dy,
        lessThan(tester.getTopLeft(find.text('Weekend recovery workshop')).dy));
    expect(find.text('Training floor reminders'), findsNothing);
    await _capture(tester, 'member-home');
    await tester.tap(find.text('Read more').first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Central Gym'), findsOneWidget);
    await _capture(tester, 'member-detail');
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Load more announcements'));
    await tester.tap(find.text('Load more announcements'));
    await tester.pumpAndSettle();
    expect(find.text('Training floor reminders'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'Member announcements component renders and refreshes real announcements instead of unavailable',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final reader = _Reader()..items = [entry('Original publication')];
    final key = GlobalKey<MemberAnnouncementsState>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: MemberAnnouncements(key: key, reader: reader),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Original publication'), findsOneWidget);
    reader.items = [entry('Refreshed publication')];
    await key.currentState!.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Refreshed publication'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Refreshed publication')).dy,
        greaterThanOrEqualTo(0));
    expect(
        find.textContaining('feature is currently unavailable'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'only active publications show; refresh and pagination observe edits and deactivation',
      (tester) async {
    final reader = _Reader()
      ..items = [
        entry('Draft', status: AnnouncementStatus.draft),
        entry('Expired', start: -7, end: -1),
        entry('Visible')
      ];
    final key = GlobalKey<MemberAnnouncementsState>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MemberAnnouncements(key: key, reader: reader))));
    await tester.pumpAndSettle();
    expect(find.text('Draft'), findsNothing);
    expect(find.text('Expired'), findsNothing);
    await tester.tap(find.text('Load more announcements'));
    await tester.pumpAndSettle();
    expect(find.text('Visible'), findsOneWidget);
    reader.items = [entry('Edited')];
    await key.currentState!.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Edited'), findsOneWidget);
    expect(find.text('Visible'), findsNothing);
    reader.items = [
      entry('Inactive', status: AnnouncementStatus.inactive),
      entry('Future', start: 2)
    ];
    await key.currentState!.refresh();
    await tester.pumpAndSettle();
    expect(find.text('No active announcements.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'account replacement discards a delayed previous-account response',
      (tester) async {
    final old = _Reader()..pending = Completer<AnnouncementPage>();
    final next = _Reader()..items = [entry('New account')];
    Widget screen(_Reader reader) =>
        MaterialApp(home: Scaffold(body: MemberAnnouncements(reader: reader)));
    await tester.pumpWidget(screen(old));
    await tester.pump();
    await tester.pumpWidget(screen(next));
    await tester.pumpAndSettle();
    old.pending!.complete(AnnouncementPage([entry('Old account')]));
    await tester.pumpAndSettle();
    expect(find.text('New account'), findsOneWidget);
    expect(find.text('Old account'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('error is honest and sanitized; retry recovers to empty',
      (tester) async {
    final reader = _Reader()..fail = true;
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MemberAnnouncements(reader: reader))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load announcements'), findsOneWidget);
    expect(find.textContaining('Private transport detail'), findsNothing);
    reader.fail = false;
    await tester.tap(find.text('Retry announcements'));
    await tester.pumpAndSettle();
    expect(find.text('No active announcements.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
