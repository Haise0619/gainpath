import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_mobile/features/content/presentation/member/member_announcements.dart';

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

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
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
