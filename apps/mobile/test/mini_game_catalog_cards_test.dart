import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/mini_games_screen.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/mini_game_details_screen.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
        'both catalog cards share cover play title and metadata at scale$scale',
        (t) async {
      t.view.physicalSize = const Size(375, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
          builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: const MiniGamesScreen(connected: true)));
      await t.pumpAndSettle();
      final move = find.byKey(const Key('move-catch-challenge-card')),
          reach = find.byKey(const Key('reach-tap-challenge-card'));
      expect(move, findsOneWidget);
      expect(reach, findsOneWidget);
      for (final card in [move, reach]) {
        expect(find.descendant(of: card, matching: find.byType(MiniGameCover)),
            findsOneWidget);
        expect(
            find.descendant(
                of: card,
                matching: find.byIcon(Icons.play_circle_fill_rounded)),
            findsOneWidget);
        expect(
            find.descendant(
                of: card, matching: find.text('40 seconds · Camera')),
            findsOneWidget);
        expect(find.descendant(of: card, matching: find.text('All levels')),
            findsOneWidget);
      }
      expect(t.getSize(move).width, t.getSize(reach).width);
      expect(t.takeException(), isNull);
      await t.ensureVisible(reach);
      await t.tap(reach);
      await t.pumpAndSettle();
      expect(find.text('Game details'), findsOneWidget);
      expect(find.text('Reach & Tap'), findsOneWidget);
    });
  }
}
