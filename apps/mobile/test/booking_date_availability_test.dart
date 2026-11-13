import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/book_session_screen.dart';
import 'booking_selection_consumer_test.dart'
    show SelectionOptions, SelectionPayments;
import 'live_booking_cubit_test.dart' show Writer;
import 'booking_payment_screen_test.dart' show FutureOptions;

class CalendarOptions extends SelectionOptions {
  final calls = <String?>[];
  final Set<String> failed = {};
  bool allEmpty = false;
  @override
  Future<BookingOptionsContext> load(
      {required String coachId,
      String? localDate,
      required int durationMinutes}) async {
    calls.add(localDate);
    if (failed.contains(localDate)) throw const BookingException('unavailable');
    final value = await super.load(
        coachId: coachId,
        localDate: localDate,
        durationMinutes: durationMinutes);
    if (allEmpty || value.localDate.compareTo('2026-10-16') < 0) {
      return BookingOptionsContext.fromJson({
        ...value.toJson(),
        'options': [],
        'unavailableReason': 'no_open_times'
      });
    }
    return value;
  }
}

class SlowWeekOptions extends CalendarOptions {
  SlowWeekOptions({this.gatedDate = '2026-10-22'});
  final String gatedDate;
  final gate = Completer<void>();
  @override
  Future<BookingOptionsContext> load(
      {required String coachId,
      String? localDate,
      required int durationMinutes}) async {
    if (localDate == gatedDate) await gate.future;
    return super.load(
        coachId: coachId,
        localDate: localDate,
        durationMinutes: durationMinutes);
  }
}

class SuggestedCalendarOptions extends FutureOptions {
  final gate = Completer<void>();
  @override
  Future<BookingOptionsContext> load(
      {required String coachId,
      String? localDate,
      required int durationMinutes}) async {
    if (localDate == date(start + 86400000)) await gate.future;
    final value = await super.load(
        coachId: coachId,
        localDate: localDate,
        durationMinutes: durationMinutes);
    final first = value.options.first;
    return BookingOptionsContext.fromJson({
      ...value.toJson(),
      'options': [
        first.toJson(),
        {
          ...first.toJson(),
          'startAtMillis': start + 1800000,
          'endAtMillis': start + 5400000,
          'startLabel': '09:00 GMT+8',
          'endLabel': '10:00 GMT+8'
        }
      ]
    });
  }
}

Future<void> showCalendar(WidgetTester tester, CalendarOptions options) async {
  await tester.pumpWidget(MaterialApp(
      home: BookSessionScreen(
          options: options,
          writer: Writer(),
          payments: SelectionPayments(),
          coachId: 'coach',
          isCurrent: () => true,
          onOpenBookings: () {})));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'late initial date checks do not replace a manual choice with a suggestion',
      (tester) async {
    final options = SuggestedCalendarOptions();
    final writer = Writer();
    final start = options.start;
    final suggestion = BookingSuggestionAttachment.fromJson({
      'schemaVersion': 1,
      'coachId': 'coach',
      'coachName': 'Suggested Coach',
      'branchId': 'branch',
      'branchName': 'Studio',
      'localDate': options.date(start),
      'timeZone': 'Asia/Kuala_Lumpur',
      'startAtMillis': start,
      'endAtMillis': start + 3600000,
      'startLabel': '08:00 GMT+8',
      'endLabel': '09:00 GMT+8',
      'durationMinutes': 60,
      'amountMinor': 12500,
      'currency': 'MYR',
      'expiresAtMillis': DateTime.now().millisecondsSinceEpoch + 60000,
      'requiresConfirmation': true
    });
    await tester.pumpWidget(MaterialApp(
        home: BookSessionScreen(
            options: options,
            writer: writer,
            payments: SelectionPayments(),
            coachId: 'coach',
            isCurrent: () => true,
            onOpenBookings: () {},
            suggestion: suggestion)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('9:00 AM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9:00 AM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review Booking'));
    await tester.pumpAndSettle();
    expect(find.text('Review booking'), findsOneWidget);
    options.gate.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to payment'));
    await tester.pumpAndSettle();
    expect(
        writer.requests.single.startAt.millisecondsSinceEpoch, start + 1800000);
  });
  testWidgets(
      'late week results preserve a date and review chosen during loading',
      (tester) async {
    final options = SlowWeekOptions();
    await showCalendar(tester, options);
    await tester.tap(find.byTooltip('Next dates'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-date-2026-10-21')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('8:00 AM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('8:00 AM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review Booking'));
    await tester.pumpAndSettle();
    expect(find.text('Review booking'), findsOneWidget);
    options.gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Review booking'), findsOneWidget);
    expect(find.text('21 Oct 2026'), findsOneWidget);
  });
  testWidgets(
      'unavailable dates are disabled and first genuinely available date is selected',
      (tester) async {
    final options = CalendarOptions();
    await showCalendar(tester, options);
    final unavailable = find.byKey(const ValueKey('booking-date-2026-10-15'));
    final available = find.byKey(const ValueKey('booking-date-2026-10-16'));
    expect(unavailable, findsOneWidget);
    expect(tester.widget<InkWell>(unavailable).onTap, isNull);
    expect(tester.widget<InkWell>(available).onTap, isNotNull);
    expect(find.text('8:00 AM'), findsOneWidget);
    expect(options.calls.length, lessThanOrEqualTo(8));
    expect(options.calls.where((d) => d == '2026-10-16').length, 1);
  });
  testWidgets(
      'failed date read is retryable and is never presented as no slots',
      (tester) async {
    final options = CalendarOptions()..failed.add('2026-10-17');
    await showCalendar(tester, options);
    final failed = find.byKey(const ValueKey('booking-date-2026-10-17'));
    expect(tester.widget<InkWell>(failed).onTap, isNotNull);
    expect(find.descendant(of: failed, matching: find.text('Retry')),
        findsOneWidget);
  });
  testWidgets(
      'all-empty week has no selectable date and can load the next week',
      (tester) async {
    final options = CalendarOptions()..allEmpty = true;
    await showCalendar(tester, options);
    expect(find.text('No open sessions on this date'), findsOneWidget);
    expect(
        tester
            .widget<InkWell>(
                find.byKey(const ValueKey('booking-date-2026-10-16')))
            .onTap,
        isNull);
    await tester.tap(find.byTooltip('Next dates'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('booking-date-2026-10-21')), findsOneWidget);
    expect(options.calls.length, lessThanOrEqualTo(15));
  });
}
