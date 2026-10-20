/// Administrative metadata only. These records are never redeemable inventory.
class RewardCatalogDraft {
  const RewardCatalogDraft(
      {required this.id,
      this.title = '',
      this.description = '',
      this.category = 'Merchandise',
      this.imageUrl = '',
      this.isArchived = false,
      this.revision = 0,
      this.editBaseline});
  final String id, title, description, category, imageUrl;
  final bool isArchived;
  final int revision;
  final Object? editBaseline;
  static const categories = [
    'Merchandise',
    'Food & Drink',
    'Apparel',
    'Access Pass'
  ];
  RewardCatalogDraft copyWith(
          {String? title,
          String? description,
          String? category,
          String? imageUrl,
          bool? isArchived}) =>
      RewardCatalogDraft(
          id: id,
          title: title ?? this.title,
          description: description ?? this.description,
          category: category ?? this.category,
          imageUrl: imageUrl ?? this.imageUrl,
          isArchived: isArchived ?? this.isArchived,
          revision: revision,
          editBaseline: editBaseline);
  void validate() {
    final uri = Uri.tryParse(imageUrl.trim());
    if (title.trim().isEmpty ||
        title.trim().length > 120 ||
        description.trim().length > 2000 ||
        !categories.contains(category) ||
        imageUrl.trim().length > 2048 ||
        (imageUrl.trim().isNotEmpty &&
            (uri == null ||
                uri.scheme != 'https' ||
                uri.host.isEmpty ||
                uri.userInfo.isNotEmpty ||
                !RegExp(r'^[A-Za-z0-9.-]+$').hasMatch(uri.host) ||
                RegExp(r'\s').hasMatch(imageUrl)))) {
      throw const FormatException(
          'Use a title up to 120 characters, description up to 2000, and an optional HTTPS image URL.');
    }
  }
}

class RewardCatalogPage {
  RewardCatalogPage(List<RewardCatalogDraft> items, {this.nextCursor})
      : items = List.unmodifiable(items);
  final List<RewardCatalogDraft> items;
  final String? nextCursor;
}

class RewardCatalogConflict implements Exception {
  const RewardCatalogConflict();
}

class RewardCatalogSessionChanged implements Exception {
  const RewardCatalogSessionChanged();
}

abstract interface class RewardCatalogRepository {
  RewardCatalogDraft beginCreate();
  Future<RewardCatalogPage> loadPage({String? afterId});
  Future<RewardCatalogDraft> save(RewardCatalogDraft draft);
}
