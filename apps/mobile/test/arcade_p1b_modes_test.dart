import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/mini_game_details_screen.dart';
import 'fitness_arcade_games_test.dart' show Reader, Participation;
import 'package:gainpath_mobile/features/gamification/domain/mini_game_launch.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'support/mini_game_participation_fixture.dart';

void main() {
  testWidgets(
      'Details defaults to fun and explicit Earn travels only after selection',
      (tester) async {
    final reader = Reader();
    final participation = Participation();
    Object? args;
    await tester.pumpWidget(MaterialApp(
        home: MiniGameDetailsScreen(
            content: MiniGameContent.defaults('gainpath'),
            reader: reader,
            participation: participation),
        onGenerateRoute: (settings) {
          args = settings.arguments;
          return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Camera consent')));
        }));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Play for fun'))
            .selected,
        true);
    await tester.ensureVisible(find.text('Play & Earn'));
    await tester.tap(find.text('Play & Earn'));
    await tester.pump();
    await tester.ensureVisible(find.text('Start playing'));
    await tester.tap(find.text('Start playing'));
    await tester.pumpAndSettle();
    expect(args, isA<MiniGameLaunchArguments>());
    expect((args as MiniGameLaunchArguments).playAndEarn, true);
  });
  testWidgets('unknown eligibility offers fun and retry with no Earn promise',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MiniGameDetailsScreen(
            content: MiniGameContent.defaults('gainpath'),
            reader: Reader(),
            participation: Participation()..fail = true)));
    await tester.pumpAndSettle();
    expect(find.text('Play & Earn'), findsNothing);
    expect(find.text('Play for fun'), findsOneWidget);
    expect(find.text('Earning status unavailable · Retry'), findsOneWidget);
  });

  test(
      'earning eligibility uses active matching game claim and shared allowance',
      () {
    final ready = MiniGameParticipation.fromJson(
        participationFixture(active: true),
        SessionScope(userId: 'member', organizationId: 'gainpath'));
    expect(MiniGameLaunchArguments.canEarn(ready, MiniGameContent.supportedId),
        true);
    expect(MiniGameLaunchArguments.canEarn(ready, MiniGameContent.reachTapId),
        false);
    expect(MiniGameLaunchArguments.canEarn(null, MiniGameContent.supportedId),
        false);
    final claimed = MiniGameParticipation.fromJson(
        participationFixture(active: true, earned: 20),
        SessionScope(userId: 'member', organizationId: 'gainpath'));
    expect(
        MiniGameLaunchArguments.canEarn(claimed, MiniGameContent.supportedId),
        false);
    final inactive = MiniGameParticipation.fromJson(
        participationFixture(active: false),
        SessionScope(userId: 'member', organizationId: 'gainpath'));
    expect(
        MiniGameLaunchArguments.canEarn(inactive, MiniGameContent.supportedId),
        false);
  });
}
