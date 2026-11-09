import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders reward_point.svg cleanly', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SvgPicture.asset(
          'assets/icons/reward_point.svg',
          width: 32,
          height: 32,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
