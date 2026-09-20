/// Fields are mutable so the admin Reward Catalog's Edit form can update
/// a listing in place instead of only ever creating new ones.
class RewardItem {
  String title;
  int points;
  int stock;
  String imageUrl;
  String category;
  String description;
  int? redemptionLimitPerMember;
  DateTime? expiresAt;
  RewardItem(this.title, this.points, this.stock, this.imageUrl,
      {this.category = 'Merchandise', this.description = '', this.redemptionLimitPerMember, this.expiresAt});
}
