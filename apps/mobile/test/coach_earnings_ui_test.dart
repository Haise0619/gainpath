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
          bookings: [completedSession],
          rating: 4.9,
          reviews: 8,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('TOTAL EARNED'), findsOneWidget);
    // 50.0 fee * 70% commission = 35 or 50 fee
    expect(find.text('RM 50'), findsWidgets);
    expect(find.text('1 sessions completed'), findsOneWidget);
    expect(find.text('4.9'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);

    final exportIcon = find.byIcon(Icons.ios_share_rounded);
    expect(exportIcon, findsOneWidget);

    await tester.tap(exportIcon);
    await tester.pumpAndSettle();

    expect(find.text('Performance Statement'), findsOneWidget);
    expect(find.text('Statement period'), findsOneWidget);
    expect(find.text('Export Statement PDF'), findsOneWidget);

    await tester.tap(find.text('Export Statement PDF'));
    await tester.pumpAndSettle();

    expect(find.text('Statement PDF exported successfully.'), findsOneWidget);
  });
}
