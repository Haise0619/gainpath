import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/locked_rewards_preview.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/mini_game_details_screen.dart';

class PreviewContentReader implements MiniGameContentReader {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  @override
  bool current = true;
  int reads = 0;
  Completer<List<MiniGameContent>>? waiting;
  @override
  Future<List<MiniGameContent>> load() async {
    reads++;
    return waiting?.future ??
        Future.value([
          for (final id in [
            MiniGameContent.supportedId,
            MiniGameContent.reachTapId
          ])
            MiniGameContent(
                organizationId: 'gainpath',
                gameId: id,
                title: MiniGameContent.defaults('gainpath', gameId: id).title,
                introduction: 'Published game',
                instructions: const ['Move safely'],
                coverUrl: 'https://example.invalid/$id.png',
                revision: 1),
        ]);
  }
}

void main() {
  testWidgets('Free preview uses configured cover URLs from the content reader',
      (t) async {
    final reader = PreviewContentReader();
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: FreeMiniGamesPreview(
                    reader: reader, onViewPlans: () async {})))));
    await t.pumpAndSettle();
    expect(reader.reads, 1);
    final covers = t.widgetList<MiniGameCover>(find.byType(MiniGameCover));
    expect(covers.map((cover) => cover.content.coverUrl), [
      'https://example.invalid/move-catch-v1.png',
      'https://example.invalid/reach-tap-v1.png'
    ]);
  });
  testWidgets('late preview covers are discarded when the session changes',
      (t) async {
    final reader = PreviewContentReader()
      ..waiting = Completer<List<MiniGameContent>>();
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: FreeMiniGamesPreview(
                    reader: reader, onViewPlans: () async {})))));
    await t.pump();
    reader.current = false;
    reader.waiting!.complete([
      MiniGameContent(
          organizationId: 'gainpath',
          title: 'Old account title',
          introduction: '',
          instructions: const [],
          coverUrl: 'https://example.invalid/old.png')
    ]);
    await t.pumpAndSettle();
    expect(find.text('Old account title'), findsNothing);
    expect(find.byType(MiniGameDetailsScreen), findsNothing);
  });
  testWidgets('reduced motion skips the preview fade', (t) async {
    await t.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: FreeMiniGamesPreview(onViewPlans: () async {})))));
    await t.pumpAndSettle();
    expect(
        t
            .widget<TweenAnimationBuilder<double>>(
                find.byType(TweenAnimationBuilder<double>))
            .duration,
        Duration.zero);
  });
  testWidgets(
      'preview blocks pointer, focus and semantics actions below overlay',
      (t) async {
    var launches = 0, plans = 0;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: LockedRewardsPreview(
        sectionTitle: 'Play Mini-Games',
        title: 'Make every move more rewarding',
        description: 'Unlock Mini-Games with Basic or Premium.',
        previewLabel: 'Move & Catch and Reach & Tap. Membership required.',
        onViewPlans: () async {
          plans++;
        },
        child: TextButton(
            onPressed: () {
              launches++;
            },
            child: const Text('Underlying play')),
      ),
    ))));
    await t.pumpAndSettle();
    await t.tap(find.text('Underlying play'), warnIfMissed: false);
    expect(launches, 0);
    expect(find.text('Play Mini-Games'), findsOneWidget);
    await t.ensureVisible(find.text('View membership plans'));
    await t.tap(find.text('View membership plans'));
    expect(plans, 1);
    final ignore = t.widget<IgnorePointer>(
        find.byKey(const ValueKey('locked-preview-content')));
    expect(ignore.ignoring, isTrue);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('locked-preview-content')),
            matching: find.byType(ExcludeFocus)),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('locked-preview-content')),
            matching: find.byType(ExcludeSemantics)),
        findsOneWidget);
  });

  testWidgets('game covers remain visible without a playable game entry',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: FreeMiniGamesPreview(onViewPlans: () async {}),
    ))));
    await t.pumpAndSettle();
    expect(find.text('Move & Catch'), findsOneWidget);
    expect(find.text('Reach & Tap'), findsOneWidget);
    expect(find.text('View membership plans'), findsOneWidget);
    expect(find.text('Paid membership required'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
