import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_mobile/features/coaching/presentation/coach/coach_specific_date_sheet.dart';
import 'package:gainpath_mobile/features/coaching/presentation/coach/live_coach_availability_view.dart';
import 'support/coach_availability_fake.dart';

class RangeAvailabilityFake extends AvailabilityFake {
  String first = '2026-10-16';
  @override
  Future<CoachAvailabilityContext> load(
      {required String coachId,
      String? firstLocalDate,
      int dayCount = 7}) async {
    first = firstLocalDate ?? '2026-10-16';
    final base = context(coachId);
    final start = DateTime.parse('${first}T00:00:00Z');
    final source = base.days.single;
    return CoachAvailabilityContext(
      coachId: coachId,
      serverNowMillis: base.serverNowMillis,
      todayLocalDate: base.todayLocalDate,
      timeZone: base.timeZone,
      policyVersion: base.policyVersion,
      writableFromLocalDate: base.writableFromLocalDate,
      writableThroughLocalDate: base.writableThroughLocalDate,
      assignedBranchIds: base.assignedBranchIds,
      days: List.generate(dayCount, (i) {
        final date = start.add(Duration(days: i));
        final local = date.toIso8601String().substring(0, 10);
        final offset =
            date.difference(DateTime.utc(2026, 10, 16)).inMilliseconds;
        return CoachAvailabilityDay(
            localDate: local,
            revision: revision,
            editable: local.compareTo('2026-10-16') >= 0 &&
                local.compareTo('2026-11-14') <= 0,
            windows: stored,
            boundaries: source.boundaries
                .map((b) => CoachTimeBoundary(
                    atMillis: b.atMillis + offset, label: b.label))
                .toList());
      }),
    );
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('drag cannot discard an open date editor', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = RangeAvailabilityFake();
    await tester.pumpWidget(MaterialApp(
        home: LiveCoachAvailabilityView(
            repository: repo, coachId: 'coach', isCurrent: () => true)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Edit specific date'), 300);
    await tester.ensureVisible(find.text('Edit specific date'));
    await tester.tap(find.text('Edit specific date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add window'));
    await tester.pumpAndSettle();
    expect(tester.widget<BottomSheet>(find.byType(BottomSheet)).enableDrag,
        isFalse,
        reason: 'Drag dismissal bypasses the dirty-editor close guard.');
    await tester.dragFrom(
        tester.getTopLeft(find.byType(BottomSheet)) + const Offset(80, 12),
        const Offset(0, 800));
    await tester.pumpAndSettle();
    expect(find.byType(CoachSpecificDateSheet), findsOneWidget);
  });

  testWidgets('specific dates navigate the writable horizon with bounded weeks',
      (tester) async {
    final repo = RangeAvailabilityFake();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CoachSpecificDateSheet(
                repository: repo, coachId: 'coach', isCurrent: () => true))));
    await tester.pumpAndSettle();
    expect(find.text('Next 7 days'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Next 7 days'));
      await tester.pumpAndSettle();
    }
    expect(repo.first, '2026-11-13');
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Next 7 days'))
            .onPressed,
        isNull);
    await tester.tap(find.text('Previous 7 days'));
    await tester.pumpAndSettle();
    expect(repo.first, '2026-11-06');
  });

  testWidgets(
      'revision conflict can discard and reload without closing the sheet',
      (tester) async {
    final repo = RangeAvailabilityFake()
      ..stored = [
        DatedCoachWindow(
            branchId: 'main',
            startAtMillis: 1792116000000,
            endAtMillis: 1792117800000)
      ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CoachSpecificDateSheet(
                repository: repo, coachId: 'coach', isCurrent: () => true))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remove-window-0')));
    await tester.pumpAndSettle();
    repo.failure = 'aborted';
    await tester.ensureVisible(find.text('Save day'));
    await tester.tap(find.text('Save day'));
    await tester.pumpAndSettle();
    expect(find.text('Discard and reload'), findsOneWidget);
    repo.failure = null;
    await tester.tap(find.text('Discard and reload'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('remove-window-0')), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('remove-window-0')))
            .onPressed,
        isNotNull);
  });

  testWidgets('close asks before discarding an open date editor',
      (tester) async {
    final repo = RangeAvailabilityFake();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => CoachSpecificDateSheet(
                            repository: repo,
                            coachId: 'coach',
                            isCurrent: () => true)),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add window'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.close));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
  });
}
