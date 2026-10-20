import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_mobile/features/coaching/presentation/coach/consultation_notes_screen.dart';

class NotesFake implements ConsultationNotesRepository {
  ConsultationNotesResult result = const ConsultationNotesResult(
      bookingId: 'booking-1', status: 'confirmed', canPublish: true);
  final calls = <(String, String)>[];
  Completer<ConsultationNotesResult>? pending;
  @override
  Future<ConsultationNotesResult> load(String id) async => result;
  @override
  Future<ConsultationNotesResult> publish(
      String id, String requestId, String text) {
    calls.add((requestId, text));
    return pending!.future;
  }
}

final booking = Booking(
    id: 'booking-1',
    coachId: 'coach',
    coachName: 'Coach',
    memberName: 'Member',
    start: DateTime(2026, 10, 1),
    durationMin: 60,
    branch: 'main',
    status: BookingStatus.confirmed,
    fee: 0);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'publish waits for server, preserves failed draft and retries same intent',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = NotesFake()..pending = Completer();
    await tester.pumpWidget(MaterialApp(
        home: ConsultationNotesScreen(
            booking: booking, repository: repo, isCurrent: () => true)));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField), 'Controlled movement improved.');
    await tester.ensureVisible(find.text('Publish notes'));
    await tester.tap(find.text('Publish notes'));
    await tester.pump();
    expect(find.text('Published notes'), findsNothing);
    repo.pending!.completeError(Exception('network'));
    await tester.pumpAndSettle();
    expect(find.text('Controlled movement improved.'), findsOneWidget);
    repo.pending = Completer();
    await tester.ensureVisible(find.text('Retry publish'));
    await tester.tap(find.text('Retry publish'));
    await tester.pump();
    expect(repo.calls[0], repo.calls[1]);
    repo.result = const ConsultationNotesResult(
        bookingId: 'booking-1',
        status: 'completed',
        canPublish: false,
        text: 'Controlled movement improved.',
        publishedAtMillis: 1791000000000);
    repo.pending!.complete(repo.result);
    await tester.pumpAndSettle();
    expect(find.text('Published notes'), findsOneWidget);
    expect(find.text('Publish notes'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
  });
  testWidgets(
      'reopens published notes read-only and hides them after session drift',
      (tester) async {
    final repo = NotesFake()
      ..result = const ConsultationNotesResult(
          bookingId: 'booking-1',
          status: 'completed',
          canPublish: false,
          text: 'Saved consultation.',
          publishedAtMillis: 1791000000000);
    var current = true;
    Widget app() => MaterialApp(
        home: ConsultationNotesScreen(
            booking: booking, repository: repo, isCurrent: () => current));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Saved consultation.'), findsOneWidget);
    expect(find.text('Publish notes'), findsNothing);
    current = false;
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.text('Saved consultation.'), findsNothing);
  });
}
