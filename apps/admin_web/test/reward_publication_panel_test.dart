import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_admin_web/features/gamification/presentation/admin/reward_publication_panel.dart';

class _Publishing implements RewardPublishingRepository {
  @override
  bool current = true;
  int configurations = 0, publications = 0;
  bool fail = false;
  RewardShopPolicy? policy;
  List<PublishedReward> items = [];
  int? configuredMinor, publishedMinor;
  final ids = <String>[];
  @override
  Future<RewardShopAdministration> shopOverview() async =>
      RewardShopAdministration(policy: policy, items: items);
  @override
  Future<void> configureShop(
      {required String requestId,
      required int pointsPerUnit,
      required int unitValueMinor,
      required bool enabled}) async {
    ids.add(requestId);
    if (fail) throw StateError('uncertain');
    configurations++;
    configuredMinor = unitValueMinor;
  }

  @override
  Future<void> publishReward(
      {required RewardCatalogDraft draft,
      required String requestId,
      required int pointCost,
      required int valueMinor,
      required int stockToAdd,
      required int validityDays,
      required String conditions,
      required String collectionInstructions,
      int baseItemRevision = 0}) async {
    ids.add(requestId);
    if (fail) throw StateError('uncertain');
    publications++;
    publishedMinor = valueMinor;
  }

  @override
  Future<void> retireReward(
      {required String itemId,
      required String requestId,
      required int baseItemRevision}) async {}
}

void main() {
  testWidgets(
      'configured shop is concise and separates published updates from new drafts',
      (tester) async {
    final repo = _Publishing()
      ..policy = const RewardShopPolicy(
          version: 'v1', pointsPerUnit: 500, unitValueMinor: 50, enabled: true)
      ..items = const [
        PublishedReward(
            itemId: 'bottle',
            title: 'Bottle',
            pointCost: 500,
            valueMinor: 50,
            stock: 10,
            revision: 1,
            active: true,
            validityDays: 10,
            conditions: 'Collect in person',
            collectionInstructions: 'Reception')
      ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: RewardPublicationPanel(repository: repo, drafts: const [
      RewardCatalogDraft(id: 'bottle', title: 'Bottle', revision: 1),
      RewardCatalogDraft(id: 'towel', title: 'Towel', revision: 1)
    ])))));
    await tester.pumpAndSettle();
    expect(find.text('500 points = RM 0.50'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Published rewards'), findsOneWidget);
    expect(find.text('Update reward'), findsOneWidget);
    expect(find.text('Publish Bottle'), findsNothing);
    expect(find.text('Publish Towel'), findsOneWidget);
    expect(find.text('Collect in person'), findsNothing);
    expect(repo.configurations, 0);
    expect(repo.publications, 0);
  });
  testWidgets('retrying an uncertain stock addition reuses its request',
      (tester) async {
    final repo = _Publishing()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RewardPublicationDialog(
                repository: repo,
                draft: const RewardCatalogDraft(
                    id: 'saved', title: 'Real reward', revision: 1)))));
    final fields = find.byType(TextFormField);
    final values = [
      '50',
      '1.00',
      '2',
      '30',
      'Collect in person',
      'Show reception'
    ];
    for (var i = 0; i < values.length; i++) {
      await tester.ensureVisible(fields.at(i));
      await tester.enterText(fields.at(i), values[i]);
    }
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Publish reward'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publish reward'));
    await tester.pumpAndSettle();
    expect(repo.publications, 0);
    repo.fail = false;
    await tester.ensureVisible(find.text('Publish reward'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publish reward'));
    await tester.pumpAndSettle();
    expect(repo.publications, 1);
    expect(repo.publishedMinor, 100);
    expect(repo.ids.length, 2);
    expect(repo.ids.first, repo.ids.last);
  });
  testWidgets('publication form scrolls with large text at small width',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Publishing();
    await tester.pumpWidget(MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: RewardPublicationDialog(
                repository: repo,
                draft: const RewardCatalogDraft(
                    id: 'saved', title: 'Real saved reward', revision: 1)))));
    await tester.ensureVisible(find.text('Publish reward'));
    expect(tester.takeException(), null);
  });
  testWidgets(
      'policy requires explicit numeric values and keeps request ID on retry',
      (tester) async {
    final repo = _Publishing();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: RewardPublicationPanel(
                    repository: repo, drafts: const [])))));
    await tester.pumpAndSettle();
    expect(find.text('Set up your reward shop'), findsOneWidget);
    final fields = find.byType(TextFormField);
    expect(tester.widget<TextFormField>(fields.at(0)).controller!.text, '');
    expect(tester.widget<TextFormField>(fields.at(1)).controller!.text, '');
    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();
    expect(repo.configurations, 0);
    await tester.enterText(fields.at(0), '50');
    await tester.enterText(fields.at(1), '1.00');
    repo.fail = true;
    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();
    repo.fail = false;
    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();
    expect(repo.ids.length, 2);
    expect(repo.ids.first, repo.ids.last);
    expect(repo.configurations, 1);
    expect(repo.configuredMinor, 100);
  });
  testWidgets('RM amounts convert exactly to sen and reject excess decimals',
      (tester) async {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Publishing();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: RewardPublicationPanel(
                    repository: repo, drafts: const [])))));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '500');
    await tester.enterText(fields.at(1), '0.005');
    await tester.ensureVisible(find.text('Save settings'));
    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();
    expect(repo.configurations, 0);
    await tester.enterText(fields.at(1), '0.50');
    await tester.ensureVisible(find.text('Save settings'));
    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();
    expect(repo.configuredMinor, 50);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'publication form starts empty and rejects missing stock delta and validity',
      (tester) async {
    final repo = _Publishing()
      ..policy = const RewardShopPolicy(
          version: 'test',
          pointsPerUnit: 50,
          unitValueMinor: 100,
          enabled: true);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: RewardPublicationPanel(repository: repo, drafts: const [
      RewardCatalogDraft(id: 'draft', title: 'Real reward', revision: 1)
    ])))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Publish Real reward'));
    await tester.tap(find.text('Publish Real reward'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
        of: find.byType(Dialog), matching: find.byType(TextFormField));
    expect(fields, findsNWidgets(6));
    for (var i = 0; i < 4; i++) {
      expect(tester.widget<TextFormField>(fields.at(i)).controller!.text, '');
    }
    await tester.ensureVisible(find.text('Publish reward'));
    await tester.tap(find.text('Publish reward'));
    await tester.pumpAndSettle();
    expect(repo.publications, 0);
    expect(find.textContaining('Enter a whole number'), findsWidgets);
  });
}
