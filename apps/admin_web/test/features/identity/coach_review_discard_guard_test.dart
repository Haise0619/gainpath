import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/identity/presentation/admin/coach_review_discard_guard.dart';

void main() {
  testWidgets(
      'review navigation requires explicit discard while keep editing retains the form',
      (tester) async {
    var left = false;
    final guard = CoachReviewDiscardGuard();
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      guard.confirm = () => confirmCoachReviewDiscard(context);
      return TextButton(
          onPressed: () async {
            if (await guard.canLeave()) left = true;
          },
          child: const Text('Leave'));
    })));
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved review reasons?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(left, isFalse);
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(left, isTrue);
  });
}
