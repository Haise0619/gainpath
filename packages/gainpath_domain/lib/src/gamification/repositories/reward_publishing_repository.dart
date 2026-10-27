import 'reward_catalog_repository.dart';

class RewardShopPolicy {
  const RewardShopPolicy(
      {required this.version,
      required this.pointsPerUnit,
      required this.unitValueMinor,
      required this.enabled});
  final String version;
  final int pointsPerUnit, unitValueMinor;
  final bool enabled;
}

class PublishedReward {
  const PublishedReward(
      {required this.itemId,
      required this.title,
      required this.pointCost,
      this.valueMinor = 0,
      required this.stock,
      required this.revision,
      required this.active,
      required this.validityDays,
      required this.conditions,
      required this.collectionInstructions,
      this.category = 'Merchandise',
      this.description = '',
      this.imageUrl = ''});
  final String itemId,
      title,
      conditions,
      collectionInstructions,
      description,
      imageUrl;
  final String category;
  final int pointCost, valueMinor, stock, revision, validityDays;
  final bool active;
}

class RewardShopAdministration {
  RewardShopAdministration({this.policy, required List<PublishedReward> items})
      : items = List.unmodifiable(items);
  final RewardShopPolicy? policy;
  final List<PublishedReward> items;
}

abstract interface class RewardPublishingRepository {
  bool get current;
  Future<RewardShopAdministration> shopOverview();
  Future<void> configureShop(
      {required String requestId,
      required int pointsPerUnit,
      required int unitValueMinor,
      required bool enabled});
  Future<void> publishReward(
      {required RewardCatalogDraft draft,
      required String requestId,
      required int pointCost,
      required int valueMinor,
      required int stockToAdd,
      required int validityDays,
      required String conditions,
      required String collectionInstructions,
      int baseItemRevision = 0});
  Future<void> retireReward(
      {required String itemId,
      required String requestId,
      required int baseItemRevision});
}

/// Atomic reward information + inventory management; no saved draft prerequisite.
abstract interface class RewardManagementRepository implements RewardPublishingRepository {
  String newItemId();
  Future<void> saveReward({required String requestId, required String itemId, required int baseItemRevision,
    required String title, required String description, required String category, required String imageUrl,
    required int pointCost, required int stockToAdd, required int validityDays,
    required String conditions, required String collectionInstructions});
}
