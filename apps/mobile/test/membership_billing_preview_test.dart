import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/main_billing_preview.dart' as preview;

void main() {
  testWidgets('reviews a past-due bill, pays it and displays Paid',
      (tester) async {
    preview.main();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Past Due'));
    await tester.pumpAndSettle();
    expect(find.text('Past Due'), findsOneWidget);
    expect(find.textContaining('Amount due: RM'), findsOneWidget);
    await tester.tap(find.text('Pay Now'));
    await tester.pumpAndSettle();
    expect(find.text('Awaiting payment'), findsOneWidget);
    final simulate = find.text('Simulate cleared payment (mock only)');
    await tester.ensureVisible(simulate);
    await tester.tap(simulate);
    await tester.pumpAndSettle();
    expect(find.textContaining('Payment confirmed'), findsOneWidget);
    final membership = find.text('View membership');
    await tester.ensureVisible(membership);
    await tester.tap(membership);
    await tester.pumpAndSettle();
    expect(find.text('Paid'), findsOneWidget);
  });

  testWidgets('cancels future renewal without losing active access',
      (tester) async {
    preview.main();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel Renewal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel renewal'));
    await tester.pumpAndSettle();
    expect(find.text('Renewal cancelled'), findsOneWidget);
    expect(find.text('Basic Membership'), findsOneWidget);
    expect(find.text('Pay Now'), findsNothing);
  });
}
