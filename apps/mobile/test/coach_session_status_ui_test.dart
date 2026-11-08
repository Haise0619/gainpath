import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/coaching/presentation/coach/roster_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/coach/coach_session_details_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/persisted_booking_presentation.dart';
import 'coach_session_status_test.dart' show statusRecord;
import 'member_coach_ux_test.dart' show shell;

void main() {
  testWidgets(
      'History shows Awaiting notes instead of raw confirmed and offers its own filter',
      (t) async {
    addTearDown(() => t.pumpWidget(const SizedBox()));
    final r = statusRecord('confirmed');
    await t.pumpWidget(shell(CoachRosterScreen(
        historyRange: true,
        persistedBookings: [persistedBookingPresentation(r)],
        recordFor: (_) => r,
        statusLabels: {r.bookingId: 'confirmed'},
        todayLocalDate: '2026-11-08',
        serverNowMillis: r.endAtMillis,
        onNotes: (_) {})));
    await t.pumpAndSettle();
    expect(find.text('Awaiting notes'), findsWidgets);
    expect(find.text('confirmed'), findsNothing);
    await t.ensureVisible(find.widgetWithText(FilterChip, 'Awaiting notes'));
    await t.tap(find.widgetWithText(FilterChip, 'Awaiting notes'));
    await t.pumpAndSettle();
    expect(find.text('Member confirmed'), findsOneWidget);
  });
  testWidgets('Cancelled history does not include Expired or Refunded records',
      (t) async {
    addTearDown(() => t.pumpWidget(const SizedBox()));
    final rows =
        ['cancelled', 'expired', 'refunded'].map(statusRecord).toList();
    await t.pumpWidget(shell(CoachRosterScreen(
        historyRange: true,
        persistedBookings: rows.map(persistedBookingPresentation).toList(),
        recordFor: (id) => rows.firstWhere((r) => r.bookingId == id),
        todayLocalDate: '2026-11-08',
        serverNowMillis: rows.first.endAtMillis)));
    await t.pumpAndSettle();
    final chip = find.widgetWithText(FilterChip, 'Cancelled');
    await t.ensureVisible(chip);
    await t.tap(chip);
    await t.pumpAndSettle();
    expect(find.text('Member cancelled'), findsOneWidget);
    expect(find.text('Member expired'), findsNothing);
    expect(find.text('Member refunded'), findsNothing);
  });
  testWidgets(
      'details use the same stage, disallow in-progress cancellation and do not infer settlement',
      (t) async {
    addTearDown(() => t.pumpWidget(const SizedBox()));
    final r = statusRecord('confirmed');
    await t.pumpWidget(shell(CoachSessionDetailsScreen(
        booking: persistedBookingPresentation(r),
        record: r,
        live: true,
        statusLabel: 'confirmed',
        serverNowMillis: r.startAtMillis,
        onNotes: () {},
        onCancel: () {},
        onMessage: () {})));
    await t.pumpAndSettle();
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('confirmed'), findsNothing);
    await t.scrollUntilVisible(find.text('PAYMENT INFORMATION'), 250);
    await t.pumpAndSettle();
    expect(find.text('Confirmed & Settled'), findsNothing);
    await t.scrollUntilVisible(find.text('BOOKING REFERENCE'), 250);
    await t.pumpAndSettle();
    expect(find.text('Cancel Session'), findsNothing);
  });
  testWidgets(
      'completed details offer read-only notes rather than a write/edit action',
      (t) async {
    addTearDown(() => t.pumpWidget(const SizedBox()));
    final r = statusRecord('completed');
    await t.pumpWidget(shell(CoachSessionDetailsScreen(
        booking: persistedBookingPresentation(r),
        record: r,
        live: true,
        serverNowMillis: r.endAtMillis,
        onNotes: () {})));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('CONSULTATION NOTES'), 250);
    await t.pumpAndSettle();
    expect(find.text('View Consultation Notes'), findsOneWidget);
    expect(find.text('Write Consultation Notes'), findsNothing);
    expect(find.text('Edit Consultation Notes'), findsNothing);
  });
  for (final raw in ['confirmed', 'pending_hold']) {
    for (final width in [320.0, 360.0]) {
      testWidgets('long detail phase fits at $width and 200%: $raw', (t) async {
        t.view.physicalSize = Size(width, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        addTearDown(() => t.pumpWidget(const SizedBox()));
        final r = statusRecord(raw);
        await t.pumpWidget(MaterialApp(
            home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: CoachSessionDetailsScreen(
                  booking: persistedBookingPresentation(r),
                  record: r,
                  live: true,
                  serverNowMillis: r.endAtMillis,
                ))));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    }
  }
}
