import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart'
    show CoachBookingCancellationRepository, CancelAssignedBookingResult;
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/live_booking_list_view.dart';
import 'package:google_fonts/google_fonts.dart';

class FakeBookingListRepository implements BookingListRepository {
  FakeBookingListRepository(this.records, this.pageDate);
  final List<PersistedBookingRecord> records;
  final String pageDate;
  int loadCalls = 0;

  @override
  SessionScope get scope =>
      SessionScope(userId: 'coach-1', organizationId: 'org-1');

  @override
  Future<BookingPage> load({
    String? coachId,
    String? firstLocalDate,
    int? dayCount,
    BookingCursor? cursor,
  }) async {
    loadCalls++;
    return BookingPage(
      records: records,
      firstLocalDate: pageDate,
      throughLocalDate: pageDate,
      serverNowMillis:
          DateTime.parse('${pageDate}T08:00:00Z').millisecondsSinceEpoch,
      timeZone: 'Asia/Kuala_Lumpur',
    );
  }
}

class FakeCoachBookingCancellationRepository
    implements CoachBookingCancellationRepository {
  String? lastBookingId;
  String? lastRequestId;
  String? lastReason;
  int cancelCalls = 0;

  @override
  Future<CancelAssignedBookingResult> cancel({
    required String bookingId,
    required String requestId,
    required String reason,
  }) async {
    cancelCalls++;
    lastBookingId = bookingId;
    lastRequestId = requestId;
    lastReason = reason;
    return CancelAssignedBookingResult(
      bookingId: bookingId,
      requestId: requestId,
      status: 'cancelled',
      outcome: 'cancelled',
      cancelledAtMillis: DateTime.now().millisecondsSinceEpoch,
      refundReviewRequired: true,
    );
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
      'Coach can cancel confirmed upcoming session with mandatory reason',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final todayStr = '$y-$m-$d';

    final baseSlot = (now.millisecondsSinceEpoch ~/ 1800000) * 1800000;
    final futureStart = baseSlot + 1800000 * 4;
    final futureEnd = futureStart + 3600000;
    final holdExpiry = futureStart - 1800000;
    final createdAt = holdExpiry - 60000;

    final startDate = DateTime.fromMillisecondsSinceEpoch(futureStart);
    final endDate = DateTime.fromMillisecondsSinceEpoch(futureEnd);
    final startLabel =
        '${startDate.hour.toString().padLeft(2, '0')}:${startDate.minute.toString().padLeft(2, '0')}';
    final endLabel =
        '${endDate.hour.toString().padLeft(2, '0')}:${endDate.minute.toString().padLeft(2, '0')}';

    final futureRecord = PersistedBookingRecord(
      bookingId: 'bk-confirmed-1',
      organizationId: 'org-1',
      memberId: 'member-1',
      coachId: 'coach-1',
      branchId: 'branch-1',
      requestId: 'req-1',
      startAtMillis: futureStart,
      endAtMillis: futureEnd,
      durationMinutes: 60,
      status: BookingStatus.confirmed,
      holdExpiresAtMillis: holdExpiry,
      localDate: todayStr,
      timeZone: 'Asia/Kuala_Lumpur',
      policyVersion: '1',
      createdAtMillis: createdAt,
      startLabel: startLabel,
      endLabel: endLabel,
      expiryLabel: '14:00',
      memberDisplayName: 'Alice Tan',
    );

    final listRepo = FakeBookingListRepository([futureRecord], todayStr);
    final cancelRepo = FakeCoachBookingCancellationRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveBookingListView(
            repository: listRepo,
            isCurrent: () => true,
            coachId: 'coach-1',
            coachCancellation: cancelRepo,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Alice Tan'), findsOneWidget);
    final cancelIcon = find.byTooltip('Cancel session');
    expect(cancelIcon, findsOneWidget);

    // Tap the cancel button
    await tester.tap(cancelIcon);
    await tester.pumpAndSettle();

    // Dialog should appear
    expect(find.text('Cancel confirmed session?'), findsOneWidget);
    expect(find.text('Cancellation reason *'), findsOneWidget);

    // Try submitting without reason
    await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel session'));
    await tester.pumpAndSettle();
    expect(find.text('Reason is required'), findsOneWidget);
    expect(cancelRepo.cancelCalls, 0);

    // Enter a valid reason
    final dialogField = find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(
        dialogField, 'Emergency doctor appointment');
    await tester.pumpAndSettle();

    // Submit dialog
    await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel session'));
    await tester.pumpAndSettle();

    // Verify repository call
    expect(cancelRepo.cancelCalls, 1);
    expect(cancelRepo.lastBookingId, 'bk-confirmed-1');
    expect(cancelRepo.lastReason, 'Emergency doctor appointment');
    expect(cancelRepo.lastRequestId, isNotEmpty);

    // Snack bar confirmation
    expect(find.text('Session cancelled. Slot released.'), findsOneWidget);
  });
}
