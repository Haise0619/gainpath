import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/mini_game_score_sharing.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/move_catch_result_panel.dart';

void main() {
  const channel = MethodChannel('gainpath/achievement_share');
  final completed = DateTime.utc(2026, 11, 23, 17);
  for (final game in ShareGame.values) {
    testWidgets('${game.title} shares a portrait PNG from its result panel',
        (tester) async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final result = MiniGameShareResult(
          game: game,
          score: 125,
          hits: 12,
          completedAt: completed,
          activeMillis: 40000);
      expect(result.date, '24 Nov 2026');
      expect(result.duration, '40s');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MoveCatchResultPanel(
          score: result.score,
          caught: result.hits,
          missed: 5,
          obstacles: 2,
          bestScore: 125,
          bestScoreAvailable: true,
          bestSaved: true,
          scoreSaveFailed: false,
          completedAt: result.completedAt,
          activeMillis: result.activeMillis,
          gameTitle: game.title,
          hitsOnly: game == ShareGame.reachTap,
          onReplay: () {},
          onExit: () {},
        )),
      ));
      final share = find.text('Share Result');
      await tester.ensureVisible(share);
      await tester.runAsync(() async {
        await tester.tap(share);
        await tester.tap(share);
        for (var i = 0; i < 100 && calls.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(calls.single.method, 'shareImage');
      final fields = calls.single.arguments as Map;
      expect(fields.keys, unorderedEquals(['png', 'text']));
      expect(fields['text'], 'My ${game.title} result in GainPath!');
      final png = fields['png'] as Uint8List;
      expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(png.length, lessThan(2000000));
      final header = ByteData.sublistView(png);
      expect(header.getUint32(16), 1080);
      expect(header.getUint32(20), 1350);
      expect(find.text('Share Result'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
