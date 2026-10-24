import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/coaching_updates_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class FakeModule9 implements Module9Repository {
  @override
  Stream<void> watchInbox() => const Stream.empty();
  CoachSharing sharing = const CoachSharing(false, 0);
  bool failSave = false;
  int? expectedRevision;
  @override
  Future<CoachSharing> loadSharing() async => sharing;
  @override
  Future<CoachSharing> saveSharing(bool enabled, int revision) async {
    expectedRevision = revision;
    if (failSave) throw StateError('offline');
    return sharing = CoachSharing(enabled, revision + 1);
  }

  @override
  Future<NoticePage> loadInbox({String? afterId}) async => NoticePage([
        MemberNotice(
            id: 'n1',
            title: 'Session cancelled',
            message: 'Please view your booking.',
            read: false,
            createdAt: DateTime(2026, 10, 20))
      ], null);
  String? readId;
  @override
  Future<void> markRead(String id) async {
    readId = id;
  }

  @override
  Future<CoachReport> loadPerformance() => throw UnimplementedError();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'Member explicitly grants sharing, save failure retains verified state, notification opens bookings',
      (tester) async {
    final repo = FakeModule9();
    var opened = false;
    await tester.pumpWidget(MaterialApp(
        home: CoachingUpdatesScreen(
            repository: repo,
            isCurrent: () => true,
            onOpenBookings: () => opened = true)));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(repo.expectedRevision, 0);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
    repo.failSave = true;
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
    await tester.tap(find.text('Session cancelled'));
    await tester.pumpAndSettle();
    expect(repo.readId, 'n1');
    expect(opened, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
