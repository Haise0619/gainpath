import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_admin_web/features/gamification/presentation/admin/reward_management_screen.dart';
import 'package:gainpath_admin_web/features/gamification/presentation/admin/reward_catalog_screen.dart';

class _Repo implements RewardManagementRepository, RewardMediaRepository {
  @override
  bool current = true;
  int allocations = 0;
  final saves = <Map<String, Object>>[];
  bool fail = true;
  bool readFails = false;
  Future<RewardShopAdministration> Function()? read;
  List<PublishedReward> items = [];
  int removals = 0;
  int uploads = 0;
  bool uploadFails = false;
  @override
  Future<String> uploadRewardCover(EquipmentImage image) async {
    uploads++;
    if (uploadFails) throw const RewardMediaUploadFailed();
    return 'https://example.test/upload.png';
  }

  @override
  String newItemId() {
    allocations++;
    return 'stable-item';
  }

  @override
  Future<RewardShopAdministration> shopOverview() async {
    if (read != null) return read!();
    if (readFails) throw StateError('Read failed');
    return RewardShopAdministration(items: items);
  }

  @override
  Future<void> saveReward(
      {required String requestId,
      required String itemId,
      required int baseItemRevision,
      required String title,
      required String description,
      required String category,
      required String imageUrl,
      required int pointCost,
      required int stockToAdd,
      required int validityDays,
      required String conditions,
      required String collectionInstructions}) async {
    saves.add({
      'requestId': requestId,
      'itemId': itemId,
      'stockToAdd': stockToAdd,
      'baseItemRevision': baseItemRevision,
      'imageUrl': imageUrl
    });
    if (fail) throw StateError('uncertain');
  }

  @override
  Future<void> configureShop(
      {required String requestId,
      required int pointsPerUnit,
      required int unitValueMinor,
      required bool enabled}) async {}
  @override
  Future<void> retireReward(
      {required String itemId,
      required String requestId,
      required int baseItemRevision}) async {
    removals++;
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
          int baseItemRevision = 0}) async =>
      throw StateError('Must not publish');
}

class _Picker implements EquipmentImagePicker {
  @override
  Future<EquipmentImage?> pick() async => EquipmentImage(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aDs8AAAAASUVORK5CYII='));
}

class _FullRepo extends _Repo implements RewardCatalogRepository {
  @override
  RewardCatalogDraft beginCreate() =>
      throw StateError('Direct flow must not create a draft');
  @override
  Future<RewardCatalogPage> loadPage({String? afterId}) async =>
      throw StateError('Direct flow must not read drafts');
  @override
  Future<RewardCatalogDraft> save(RewardCatalogDraft draft) async =>
      throw StateError('Direct flow must not save drafts');
}

class _UnavailableWorkoutRepo extends _FullRepo
    implements WorkoutRewardConfigurationRepository {
  int draftReads = 0;
  @override
  Future<WorkoutRewardDraft> loadWorkoutRewardDraft() async {
    draftReads++;
    throw StateError('Endpoint unavailable');
  }

  @override
  Future<void> saveWorkoutRewardDraft(
      {required String requestId,
      required int baseRevision,
      required WorkoutRewardDraft draft}) async {}
}

void main() {
  testWidgets('unavailable lazy workout draft does not block reward catalog',
      (tester) async {
    final repo = _UnavailableWorkoutRepo();
    await tester.pumpWidget(
        MaterialApp(home: RewardManagementScreen(repository: repo)));
    await tester.pumpAndSettle();
    expect(repo.draftReads, 0);
    await tester.tap(find.text('Workout reward draft'));
    await tester.pumpAndSettle();
    expect(repo.draftReads, 1);
    expect(find.text('Retry workout draft'), findsOneWidget);
    await tester.ensureVisible(find.text('Add reward'));
    await tester.tap(find.text('Add reward'));
    await tester.pumpAndSettle();
    expect(find.text('Create reward'), findsOneWidget);
  });
  testWidgets(
      'saved covers use browser-native rendering in cards and the editor',
      (tester) async {
    const url = 'https://media.example.test/reward.jpg';
    final repo = _Repo()
      ..items = [
        const PublishedReward(
            itemId: 'cover',
            title: 'Reward with cover',
            pointCost: 500,
            stock: 9,
            revision: 2,
            active: true,
            validityDays: 10,
            conditions: 'Terms',
            collectionInstructions: 'Reception',
            imageUrl: url)
      ];
    await tester.pumpWidget(
        MaterialApp(home: RewardManagementScreen(repository: repo)));
    await tester.pumpAndSettle();
    void checkCover() {
      final image = tester.widget<Image>(find.byType(Image).first);
      final provider = image.image as NetworkImage;
      expect(provider.url, url);
      expect(provider.webHtmlElementStrategy, WebHtmlElementStrategy.prefer);
      expect(image.fit, BoxFit.contain);
    }

    checkCover();
    await tester.ensureVisible(find.text('Edit reward'));
    await tester.tap(find.text('Edit reward'));
    await tester.pumpAndSettle();
    checkCover();
  });
  testWidgets('old catalog read cannot replace a new session catalog',
      (tester) async {
    final pending = Completer<RewardShopAdministration>();
    final old = _Repo()..read = () => pending.future;
    final next = _Repo();
    await tester
        .pumpWidget(MaterialApp(home: RewardManagementScreen(repository: old)));
    await tester.pump();
    await tester.pumpWidget(
        MaterialApp(home: RewardManagementScreen(repository: next)));
    await tester.pumpAndSettle();
    pending.complete(RewardShopAdministration(items: [
      const PublishedReward(
          itemId: 'old',
          title: 'Private old session item',
          pointCost: 50,
          stock: 1,
          revision: 1,
          active: true,
          validityDays: 30,
          conditions: 'Terms',
          collectionInstructions: 'Reception')
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Private old session item'), findsNothing);
    expect(find.text('No rewards yet'), findsOneWidget);
  });
  testWidgets('failed points catalog read disables Add until retry succeeds',
      (tester) async {
    final repo = _Repo()..readFails = true;
    await tester.pumpWidget(
        MaterialApp(home: RewardManagementScreen(repository: repo)));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.byWidgetPredicate((widget) => widget is FilledButton))
            .onPressed,
        null);
    expect(find.text('Retry rewards'), findsOneWidget);
    repo.readFails = false;
    await tester.tap(find.text('Retry rewards'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.byWidgetPredicate((widget) => widget is FilledButton))
            .onPressed,
        isNotNull);
    expect(find.text('Shop policy'), findsNothing);
  });
  testWidgets(
      'points catalog needs no policy and shows centered reward empty state',
      (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(
        MaterialApp(home: RewardManagementScreen(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Save settings'), findsNothing);
    expect(find.text('Shop policy'), findsNothing);
    expect(find.textContaining('RM'), findsNothing);
    expect(find.text('Rewards'), findsOneWidget);
    expect(find.text('Manage items in your Member shop.'), findsOneWidget);
    expect(find.text('No rewards yet'), findsOneWidget);
    expect(find.byIcon(Icons.redeem_outlined), findsOneWidget);
  });
  testWidgets('reward grid and header actions adapt to large desktop text',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Repo()
      ..items = [
        const PublishedReward(
            itemId: 'existing',
            title: 'Existing Member reward with longer title',
            pointCost: 50,
            valueMinor: 100,
            stock: 7,
            revision: 4,
            active: true,
            validityDays: 30,
            conditions: 'Conditions',
            collectionInstructions: 'Reception')
      ];
    await tester.pumpWidget(MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: child!),
        home: RewardManagementScreen(repository: repo, onVerify: () {})));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit reward'));
    expect(find.textContaining('RM'), findsNothing);
    expect(find.text('Shop policy'), findsNothing);
    expect(tester.takeException(), null);
  });
  testWidgets(
      'normal catalog capability opens direct editor without metadata draft reads',
      (tester) async {
    final repo = _FullRepo();
    await tester.pumpWidget(RepositoryProvider<RewardCatalogRepository>.value(
        value: repo,
        child: const MaterialApp(home: RewardCatalogScreen(live: true))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add reward'));
    await tester.pumpAndSettle();
    expect(find.text('Create reward'), findsOneWidget);
    expect(find.text('Save draft'), findsNothing);
    expect(tester.takeException(), null);
  });
  testWidgets('failed cover upload never saves reward fields', (tester) async {
    final repo = _Repo()
      ..fail = false
      ..uploadFails = true;
    const item = PublishedReward(
        itemId: 'existing',
        title: 'Towel',
        pointCost: 50,
        valueMinor: 100,
        stock: 7,
        revision: 4,
        active: true,
        validityDays: 30,
        conditions: 'Conditions',
        collectionInstructions: 'Reception');
    await tester.pumpWidget(RepositoryProvider<EquipmentImagePicker>.value(
        value: _Picker(),
        child: MaterialApp(
            home: RewardEditorPage(
                repository: repo,
                itemId: item.itemId,
                existing: item,
                onDone: () {}))));
    await tester.ensureVisible(find.text('Choose cover image'));
    await tester.tap(find.text('Choose cover image'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(repo.uploads, 1);
    expect(repo.saves, isEmpty);
    expect(find.textContaining('Could not upload the reward image'),
        findsOneWidget);
    expect(find.textContaining('Save not confirmed'), findsNothing);
  });
  testWidgets('removed reward edits directly with zero additional stock',
      (tester) async {
    final repo = _Repo()
      ..fail = false
      ..items = [
        const PublishedReward(
            itemId: 'removed',
            title: 'Existing towel',
            pointCost: 50,
            valueMinor: 100,
            stock: 7,
            revision: 4,
            active: false,
            validityDays: 30,
            conditions: 'Conditions',
            collectionInstructions: 'Reception')
      ];
    await tester.pumpWidget(RepositoryProvider<EquipmentImagePicker>.value(
        value: _Picker(),
        child: MaterialApp(home: RewardManagementScreen(repository: repo))));
    await tester.pumpAndSettle();
    expect(find.text('Removed'), findsOneWidget);
    expect(find.text('Remove from shop'), findsNothing);
    await tester.ensureVisible(find.text('Edit reward'));
    await tester.tap(find.text('Edit reward'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'Additional stock'))
            .controller!
            .text,
        '0');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(repo.saves.single['stockToAdd'], 0);
    expect(repo.saves.single['baseItemRevision'], 4);
    expect(repo.allocations, 0);
  });
  testWidgets(
      'all information is created in one action with stable retry identity',
      (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(RepositoryProvider<EquipmentImagePicker>.value(
        value: _Picker(),
        child: MaterialApp(home: RewardManagementScreen(repository: repo))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Published rewards'), findsNothing);
    await tester.tap(find.text('Add reward'));
    await tester.pumpAndSettle();
    expect(find.text('Save draft'), findsNothing);
    expect(find.text('Publish reward'), findsNothing);
    Future<void> enter(String label, String value) async {
      final f = find.widgetWithText(TextFormField, label);
      await tester.ensureVisible(f);
      await tester.enterText(f, value);
    }

    await enter('Title', 'Real towel');
    await enter('Description', 'Cotton');
    expect(find.textContaining('URL'), findsNothing);
    await tester.ensureVisible(find.text('Choose cover image'));
    await tester.tap(find.text('Choose cover image'));
    await tester.pumpAndSettle();
    expect(find.text('Change cover'), findsOneWidget);
    await enter('Points cost', '50');
    expect(find.textContaining('RM'), findsNothing);
    await enter('Initial stock', '2');
    await enter('Validity after redemption (days)', '30');
    await enter('Conditions', 'Collect in person');
    await enter('Collection instructions', 'Reception');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create reward'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create reward'));
    await tester.pumpAndSettle();
    expect(repo.saves.length, 1);
    repo.fail = false;
    await tester.ensureVisible(find.text('Create reward'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create reward'));
    await tester.pumpAndSettle();
    expect(repo.allocations, 1);
    expect(repo.saves.length, 2);
    expect(repo.saves[0], repo.saves[1]);
    expect(repo.saves[0].containsKey('valueMinor'), false);
    expect(repo.uploads, 1);
    expect(repo.saves[0]['imageUrl'], 'https://example.test/upload.png');
  });
  testWidgets('small screen large text editor scrolls and session hides fields',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Repo();
    Widget app() => MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: child!),
        home: RewardManagementScreen(repository: repo));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add reward'));
    await tester.tap(find.text('Add reward'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create reward'));
    expect(tester.takeException(), null);
    repo.current = false;
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.text('Create reward'), findsNothing);
  });
}
