import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_admin_web/features/content/presentation/admin/mini_game_reward_policy_panel.dart';

class _Repository implements MiniGameRewardConfigurationRepository {
  @override
  final scope = SessionScope(userId: 'admin', organizationId: 'gainpath');
  @override
  bool current = true;
  int reads = 0;
  int? failReadAt;
  bool uncertain = false, conflict = false;
  bool sessionChangedOnLoad = false;
  final requests = <String>[];
  final bases = <int>[];
  final submitted = <MiniGameRewardPolicy>[];
  MiniGameRewardPolicy policy = MiniGameRewardPolicy(revision: 3);
  MiniGameRewardPolicy? readbackOverride;
  Completer<MiniGameRewardPolicy>? pendingLoad, pendingSave;

  @override
  Future<MiniGameRewardPolicy> loadPolicy() async {
    reads++;
    if (sessionChangedOnLoad) throw const MiniGameRewardSessionChanged();
    if (reads == failReadAt) throw StateError('readback unavailable');
    if (reads > 1 && readbackOverride != null) return readbackOverride!;
    return pendingLoad == null ? policy : pendingLoad!.future;
  }

  @override
  Future<MiniGameRewardPolicy> savePolicy(
      {required String requestId,
      required int baseRevision,
      required MiniGameRewardPolicy policy}) async {
    requests.add(requestId);
    bases.add(baseRevision);
    submitted.add(policy);
    if (conflict) throw const MiniGameRewardConflict();
    if (uncertain) throw StateError('unconfirmed transport');
    if (pendingSave != null) return pendingSave!.future;
    this.policy = MiniGameRewardPolicy(
        revision: baseRevision + 1,
        dailyPointsCap: policy.dailyPointsCap,
        games: policy.games);
    return this.policy;
  }
}

void main() {
  final points = find.byKey(const Key('mini-game-points'));
  final limit = find.byKey(const Key('mini-game-limit'));
  final cap = find.byKey(const Key('mini-game-cap'));
  final save = find.text('Save settings');

  Future<void> show(WidgetTester tester, _Repository repository,
      {double scale = 1}) async {
    await tester.pumpWidget(MaterialApp(
        builder: (_, child) => MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: MiniGameRewardPolicyPanel(repository: repository)))));
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Mini-game reward policy'));
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  String field(WidgetTester tester, Finder finder) =>
      tester.widget<TextFormField>(finder).controller!.text;

  testWidgets(
      'loads lazily and saves only loaded disabled values with readback',
      (tester) async {
    final repository = _Repository();
    await show(tester, repository);
    expect(repository.reads, 0);
    expect(find.byType(TextFormField), findsNothing);
    await open(tester);
    expect(repository.reads, 1);
    expect(field(tester, points), '20');
    expect(field(tester, cap), '60');
    expect(field(tester, limit), '1');
    expect(find.text('Points and daily limits'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Activate'), findsNothing);
    await tester.enterText(points, '25');
    await tester.enterText(cap, '55');
    await tapSave(tester);
    expect(repository.bases, [3]);
    expect(repository.submitted.single.enabled, isFalse);
    expect(repository.submitted.single.dailyPointsCap, 55);
    expect(repository.submitted.single.games.single.points, 25);
    expect(repository.submitted.single.games.single.dailyClaimLimit, 1);
    expect(repository.reads, 2);
    expect(find.text('Settings saved.'), findsOneWidget);
  });

  testWidgets('validates numbers and cannot raise game claims above once daily',
      (tester) async {
    final repository = _Repository();
    await show(tester, repository);
    await open(tester);
    for (final values in [
      ['-1', '2', '10001'],
      ['1001', '-1', '-1'],
      ['1.5', 'one', 'many']
    ]) {
      await tester.enterText(points, values[0]);
      await tester.enterText(limit, values[1]);
      await tester.enterText(cap, values[2]);
      await tapSave(tester);
      expect(repository.requests, isEmpty);
      expect(find.text('Enter a whole number from 0 to 1000.'), findsOneWidget);
      expect(find.text('Enter 0 or 1. Each game type can reward once per day.'),
          findsOneWidget);
      expect(
          find.text('Enter a whole number from 0 to 10000.'), findsOneWidget);
    }
    await tester.enterText(points, '0');
    await tester.enterText(limit, '0');
    await tester.enterText(cap, '0');
    await tapSave(tester);
    expect(repository.submitted.single.dailyPointsCap, 0);
    expect(repository.submitted.single.games.single.dailyClaimLimit, 0);
  });

  testWidgets('uncertain saves reuse request only for the unchanged payload',
      (tester) async {
    final repository = _Repository()..uncertain = true;
    await show(tester, repository);
    await open(tester);
    await tapSave(tester);
    await tapSave(tester);
    expect(repository.requests.first, matches(RegExp(r'^[a-f0-9]{32}$')));
    expect(repository.requests[0], repository.requests[1]);
    await tester.enterText(points, '21');
    await tapSave(tester);
    expect(repository.requests[2], isNot(repository.requests[1]));
    expect(repository.bases, [3, 3, 3]);
  });

  testWidgets(
      'failed readback cannot confirm a save and keeps its retry identity',
      (tester) async {
    final repository = _Repository()..failReadAt = 2;
    await show(tester, repository);
    await open(tester);
    await tester.enterText(points, '23');
    await tapSave(tester);
    expect(find.text('Settings saved.'), findsNothing);
    expect(field(tester, points), '23');
    repository.failReadAt = null;
    await tapSave(tester);
    expect(repository.requests.length, 2);
    expect(repository.requests.first, repository.requests.last);
    expect(repository.bases, [3, 3]);
    expect(find.text('Settings saved.'), findsOneWidget);
  });

  testWidgets(
      'changed authoritative readback requires reload before another save',
      (tester) async {
    final repository = _Repository()
      ..readbackOverride = MiniGameRewardPolicy(
          revision: 9, games: const [MiniGameRewardGame(points: 7)]);
    await show(tester, repository);
    await open(tester);
    await tester.enterText(points, '26');
    await tapSave(tester);
    expect(find.text('Settings saved.'), findsNothing);
    expect(field(tester, points), '26');
    await tapSave(tester);
    expect(repository.requests.length, 1);
  });

  testWidgets(
      'conflict blocks overwrite until explicit reload establishes baseline',
      (tester) async {
    final repository = _Repository()..conflict = true;
    await show(tester, repository);
    await open(tester);
    await tester.enterText(points, '30');
    await tapSave(tester);
    expect(field(tester, points), '30');
    await tapSave(tester);
    expect(repository.requests.length, 1);
    repository
      ..conflict = false
      ..policy = MiniGameRewardPolicy(
          revision: 8,
          dailyPointsCap: 45,
          games: [MiniGameRewardGame(points: 15)]);
    await tester.ensureVisible(find.text('Reload policy'));
    await tester.tap(find.text('Reload policy'));
    await tester.pumpAndSettle();
    expect(field(tester, points), '15');
    expect(field(tester, cap), '45');
    await tapSave(tester);
    expect(repository.bases, [3, 8]);
    expect(repository.requests[0], isNot(repository.requests[1]));
  });

  testWidgets('late load and save responses cannot expose a stale session',
      (tester) async {
    final repository = _Repository()
      ..pendingLoad = Completer<MiniGameRewardPolicy>();
    await show(tester, repository);
    await tester.tap(find.text('Mini-game reward policy'));
    await tester.pump();
    repository.current = false;
    repository.pendingLoad!.complete(MiniGameRewardPolicy(revision: 99));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    expect(save, findsNothing);
    final fresh = _Repository();
    await show(tester, fresh);
    await open(tester);
    fresh.pendingSave = Completer<MiniGameRewardPolicy>();
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    fresh.current = false;
    fresh.pendingSave!.complete(MiniGameRewardPolicy(revision: 100));
    await tester.pumpAndSettle();
    expect(find.text('Settings saved.'), findsNothing);
    expect(save, findsNothing);
    expect(fresh.reads, 1);
  });

  testWidgets(
      'repository session-change rejection permanently closes this panel',
      (tester) async {
    final repository = _Repository()..sessionChangedOnLoad = true;
    await show(tester, repository);
    await open(tester);
    expect(
        find.textContaining('This Admin session has ended.'), findsOneWidget);
    expect(find.text('Reload policy'), findsNothing);
    expect(save, findsNothing);
    repository.sessionChangedOnLoad = false;
    await show(tester, repository);
    expect(find.byType(TextFormField), findsNothing);
    expect(
        find.textContaining('This Admin session has ended.'), findsOneWidget);
  });

  testWidgets('360px and twice text size keeps fields and actions reachable',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _Repository();
    await show(tester, repository, scale: 2);
    await open(tester);
    for (final finder in [points, limit, cap, save]) {
      await tester.ensureVisible(finder);
      expect(tester.takeException(), isNull);
    }
    repository.current = false;
    await show(tester, repository, scale: 2);
    expect(save, findsNothing);
  });
}
