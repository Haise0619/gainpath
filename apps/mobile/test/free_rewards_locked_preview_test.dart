import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/locked_rewards_preview.dart';

void main() {
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
