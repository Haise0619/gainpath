import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/game_leaderboard_screen.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'mini_game_competition_coordinator_test.dart' show CompetitionRepo, scope;

class RenderRankingsRepo extends CompetitionRepo {
  RenderRankingsRepo({
    required this.entries,
    required this.you,
    required this.totalParticipants,
  });

  final List<MiniGameScoreRank> entries;
  final MiniGameScoreRank you;
  final int totalParticipants;

  @override
  Future<MiniGameScoreLeaderboard> leaderboard({
    required String gameId,
    required String period,
  }) async {
    return MiniGameScoreLeaderboard(
      scope: scope,
      gameId: gameId,
      period: period,
      periodKey: period == 'week' ? '2026-11-23' : 'all-time',
      entries: entries,
      you: you,
      totalParticipants: totalParticipants,
      resolvedAtMillis: 1732500000000,
    );
  }
}

void main() {
  setUpAll(() async {
    await loadDemoRenderFonts();
    for (final family in ['Barlow', 'BarlowCondensed']) {
      final loader = FontLoader(family);
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        final path = File('assets/fonts/$family-$weight.ttf').existsSync()
            ? 'assets/fonts/$family-$weight.ttf'
            : 'apps/mobile/assets/fonts/$family-$weight.ttf';
        if (File(path).existsSync()) {
          loader.addFont(Future.value(
              ByteData.sublistView(await File(path).readAsBytes())));
        }
      }
      await loader.load();
    }
  });

  Future<void> saveScreenshot(
      WidgetTester tester, GlobalKey key, String filename) async {
    await tester.pumpAndSettle();
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(key));

    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();

      // Save to build renders directory
      final outDir =
          Directory('../../build/game-leaderboard-redesign-20261125');
      await outDir.create(recursive: true);
      await File('${outDir.path}/$filename').writeAsBytes(bytes);

      // Also copy to conversation artifact directory
      final artifactDir = Directory(
          'C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314');
      if (await artifactDir.exists()) {
        await File('${artifactDir.path}/$filename').writeAsBytes(bytes);
      }
      image.dispose();
    });
  }

  Widget buildApp({
    required GlobalKey key,
    required Widget child,
    double width = 393,
    double height = 980,
    double scale = 1.0,
  }) {
    return RepaintBoundary(
      key: key,
      child: MaterialApp(
        theme: buildMemberTypographyTheme(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: Size(width, height),
            textScaler: memberTextScaler(TextScaler.linear(scale)),
          ),
          child: child!,
        ),
        home: child,
      ),
    );
  }

  testWidgets('capture game leaderboard podium 393', (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);
    tester.view.physicalSize = const Size(393, 980);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = RenderRankingsRepo(
      entries: const [
        MiniGameScoreRank(
            rank: 1, displayName: 'Marcus Vance', score: 620, isYou: false),
        MiniGameScoreRank(
            rank: 2, displayName: 'Alex Rivera', score: 580, isYou: true),
        MiniGameScoreRank(
            rank: 3, displayName: 'Sarah Jenkins', score: 510, isYou: false),
        MiniGameScoreRank(
            rank: 4, displayName: 'David Kim', score: 460, isYou: false),
        MiniGameScoreRank(
            rank: 5, displayName: 'Elena Rostova', score: 420, isYou: false),
      ],
      you: const MiniGameScoreRank(
          rank: 2, displayName: 'Alex Rivera', score: 580, isYou: true),
      totalParticipants: 28,
    );

    final key = GlobalKey();
    await tester.pumpWidget(buildApp(
      key: key,
      width: 393,
      height: 980,
      child: GameLeaderboardScreen(
        repository: repo,
        gameId: 'move-catch-v1',
      ),
    ));
    await tester.pumpAndSettle();

    await saveScreenshot(tester, key, 'game_leaderboard_podium_393.png');
  });

  testWidgets('capture game leaderboard empty 393', (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);
    tester.view.physicalSize = const Size(393, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = RenderRankingsRepo(
      entries: const [],
      you: const MiniGameScoreRank(
          rank: null, displayName: 'You', score: null, isYou: true),
      totalParticipants: 0,
    );

    final key = GlobalKey();
    await tester.pumpWidget(buildApp(
      key: key,
      width: 393,
      height: 800,
      child: GameLeaderboardScreen(
        repository: repo,
        gameId: 'move-catch-v1',
      ),
    ));
    await tester.pumpAndSettle();

    await saveScreenshot(tester, key, 'game_leaderboard_empty_393.png');
  });

  testWidgets('capture game leaderboard single 393', (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);
    tester.view.physicalSize = const Size(393, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = RenderRankingsRepo(
      entries: const [
        MiniGameScoreRank(
            rank: 1, displayName: 'Sarah Jenkins', score: 490, isYou: false),
        MiniGameScoreRank(
            rank: 2, displayName: 'Alex Rivera', score: 440, isYou: true),
      ],
      you: const MiniGameScoreRank(
          rank: 2, displayName: 'Alex Rivera', score: 440, isYou: true),
      totalParticipants: 2,
    );

    final key = GlobalKey();
    await tester.pumpWidget(buildApp(
      key: key,
      width: 393,
      height: 850,
      child: GameLeaderboardScreen(
        repository: repo,
        gameId: 'move-catch-v1',
      ),
    ));
    await tester.pumpAndSettle();

    await saveScreenshot(tester, key, 'game_leaderboard_single_393.png');
  });

  testWidgets('capture game leaderboard reachtap 393', (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);
    tester.view.physicalSize = const Size(393, 980);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = RenderRankingsRepo(
      entries: const [
        MiniGameScoreRank(
            rank: 1, displayName: 'Elena Rostova', score: 710, isYou: false),
        MiniGameScoreRank(
            rank: 2, displayName: 'Marcus Vance', score: 680, isYou: false),
        MiniGameScoreRank(
            rank: 3, displayName: 'Alex Rivera', score: 620, isYou: true),
        MiniGameScoreRank(
            rank: 4, displayName: 'Kenji Sato', score: 550, isYou: false),
      ],
      you: const MiniGameScoreRank(
          rank: 3, displayName: 'Alex Rivera', score: 620, isYou: true),
      totalParticipants: 42,
    );

    final key = GlobalKey();
    await tester.pumpWidget(buildApp(
      key: key,
      width: 393,
      height: 980,
      child: GameLeaderboardScreen(
        repository: repo,
        gameId: 'reach-tap-v1',
      ),
    ));
    await tester.pumpAndSettle();

    await saveScreenshot(tester, key, 'game_leaderboard_reachtap_393.png');
  });

  testWidgets('capture game leaderboard 320 2x', (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);
    tester.view.physicalSize = const Size(320, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = RenderRankingsRepo(
      entries: const [
        MiniGameScoreRank(
            rank: 1, displayName: 'Marcus Vance', score: 620, isYou: false),
        MiniGameScoreRank(
            rank: 2, displayName: 'Alex Rivera', score: 580, isYou: true),
        MiniGameScoreRank(
            rank: 3, displayName: 'Sarah Jenkins', score: 510, isYou: false),
        MiniGameScoreRank(
            rank: 4, displayName: 'David Kim', score: 460, isYou: false),
      ],
      you: const MiniGameScoreRank(
          rank: 2, displayName: 'Alex Rivera', score: 580, isYou: true),
      totalParticipants: 28,
    );

    final key = GlobalKey();
    await tester.pumpWidget(buildApp(
      key: key,
      width: 320,
      height: 1100,
      scale: 2.0,
      child: GameLeaderboardScreen(
        repository: repo,
        gameId: 'move-catch-v1',
      ),
    ));
    await tester.pumpAndSettle();

    await saveScreenshot(tester, key, 'game_leaderboard_320_2x.png');
  });
}
