import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/mini_games_screen.dart';
import 'package:gainpath_mobile/navigation/feature_navigation.dart';

void main() {
  testWidgets(
      'connected mini-games launches the real motion destination without mock rewards',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(routes: {
      FeatureNavigation.moveAndCatch: (_) =>
          const Scaffold(body: Text('Real motion route'))
    }, home: const MiniGamesScreen(connected: true)));
    expect(find.text('Move & Catch'), findsNWidgets(2));
    expect(find.textContaining('Challenges unavailable'), findsNothing);
    await tester.ensureVisible(find.byTooltip('View Move & Catch details'));
    await tester.tap(find.byTooltip('View Move & Catch details'));
    await tester.pumpAndSettle();
    expect(find.text('How to play'), findsOneWidget);
    expect(find.text('Real motion route'), findsNothing);
    await tester.ensureVisible(find.text('Start playing'));
    await tester.tap(find.text('Start playing'));
    await tester.pumpAndSettle();
    expect(find.text('Real motion route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
