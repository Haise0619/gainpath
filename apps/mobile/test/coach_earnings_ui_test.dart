import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_mobile/features/analytics/presentation/coach/earnings_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
      'Coach Earnings screen calculates commission and allows statement export',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    List<String>? exportedLines;
    final completedSession = Booking(
      id: 'bk-comp-1',
      coachId: 'coach-1',
      coachName: 'Coach Jack',
      memberName: 'Alice Tan',
      start: DateTime.now().subtract(const Duration(days: 2)),
      durationMin: 60,
      branch: 'branch-1',
      status: BookingStatus.completed,
      fee: 50.0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EarningsScreen(
          connected: true,
          exportPdf: (lines) async {
            exportedLines = lines;
            return true;
          },
          bookings: List.generate(
              25,
              (i) => Booking(
                  id: 'bk-comp-${i + 1}',
                  coachId: completedSession.coachId,
                  coachName: completedSession.coachName,
                  memberName: completedSession.memberName,
                  start: completedSession.start,
                  branch: completedSession.branch,
                  status: BookingStatus.completed,
                  fee: 50)),
          rating: 4.9,
          reviews: 8,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('TOTAL EARNED'), findsOneWidget);
    // 50.0 fee * 70% commission = 35 or 50 fee
    expect(find.text('RM 1250.00'), findsWidgets);
    expect(find.text('25 sessions completed'), findsOneWidget);
    expect(find.text('4.9'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);

    final exportIcon = find.byIcon(Icons.ios_share_rounded);
    expect(exportIcon, findsOneWidget);

    await tester.tap(exportIcon);
    await tester.pumpAndSettle();

    await tester.pumpAndSettle();

    expect(find.text('Statement PDF saved.'), findsOneWidget);
    expect(exportedLines, isNotNull);
    expect(
        exportedLines!.where((line) => line.contains('bk-comp-')).length, 25);
    expect(exportedLines!.any((line) => line.contains('bk-comp-1')), isTrue);
    expect(exportedLines!.any((line) => line.contains('Verified for Payout')),
        isFalse);
  });
}
