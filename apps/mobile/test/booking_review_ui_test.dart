import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart' show BookingReviewRepository, BookingReviewResult;
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/live_booking_list_view.dart';
import 'package:google_fonts/google_fonts.dart';

class FakeBookingListRepository implements BookingListRepository {
  FakeBookingListRepository(this.records);
  final List<PersistedBookingRecord> records;

  @override
  SessionScope get scope =>
      SessionScope(userId: 'member-1', organizationId: 'org-1');

  @override
  Future<BookingPage> load({
    String? coachId,
    String? firstLocalDate,
    int? dayCount,
    BookingCursor? cursor,
  }) async {
    return BookingPage(
      records: records,
      firstLocalDate: '2026-10-20',
      throughLocalDate: '2026-10-20',
      serverNowMillis:
          DateTime.parse('2026-10-20T08:00:00Z').millisecondsSinceEpoch,
      timeZone: 'Asia/Kuala_Lumpur',
    );
  }
}

class FakeBookingReviewRepository implements BookingReviewRepository {
  String? lastBookingId;
  int? lastStars;
  String? lastReviewText;
  int calls = 0;

  @override
  Future<BookingReviewResult> submitReview({
    required String bookingId,
    required String requestId,
    required int stars,
    String? reviewText,
  }) async {
    calls++;
    lastBookingId = bookingId;
    lastStars = stars;
    lastReviewText = reviewText;
    return BookingReviewResult(
      bookingId: bookingId,
      requestId: requestId,
      stars: stars,
      reviewedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Member can rate a completed session with stars and review text',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final completedRecord = PersistedBookingRecord(
      bookingId: 'bk-completed-1',
      organizationId: 'org-1',
      memberId: 'member-1',
      coachId: 'coach-1',
      branchId: 'branch-1',
      requestId: 'req-1',
      startAtMillis: 1699999200000,
      endAtMillis: 1699999200000 + 3600000,
      durationMinutes: 60,
      status: BookingStatus.completed,
      holdExpiresAtMillis: 1699999200000 - 1800000,
      localDate: '2026-10-20',
      timeZone: 'Asia/Kuala_Lumpur',
      policyVersion: '1',
      createdAtMillis: 1699999200000 - 3600000,
      startLabel: '10:00',
      endLabel: '11:00',
      expiryLabel: '10:00',
      memberDisplayName: 'Alice Tan',
    );

    final listRepo = FakeBookingListRepository([completedRecord]);
    final reviewRepo = FakeBookingReviewRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveBookingListView(
            repository: listRepo,
            isCurrent: () => true,
            review: reviewRepo,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final rateButton = find.text('Leave a review');
    expect(find.text('Rate session'), findsNothing);
    expect(rateButton, findsOneWidget);

    await tester.tap(rateButton);
    await tester.pumpAndSettle();

    expect(find.text('Rate session'), findsWidgets);
    expect(find.text('How was your coaching consultation?'), findsOneWidget);

    await tester.enterText(
        find.byType(TextField), 'Fantastic session with thorough form cues!');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();

    expect(find.text('Leave a review'), findsNothing);
    expect(find.text('You reviewed this session'), findsOneWidget);
    expect(find.text(' · 5/5'), findsOneWidget);
    expect(reviewRepo.calls, 1);
    expect(reviewRepo.lastBookingId, 'bk-completed-1');
    expect(reviewRepo.lastStars, 5);
    expect(reviewRepo.lastReviewText,
        'Fantastic session with thorough form cues!');
    expect(
        find.text('Review submitted. Thank you for your feedback!'), findsOneWidget);
  });
}
