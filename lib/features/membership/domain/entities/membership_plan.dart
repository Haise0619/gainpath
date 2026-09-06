class MembershipPlan {
  final String id;
  final String name;
  final double price;
  final String tagline;
  final List<String> perks;
  final bool popular;
  const MembershipPlan(this.id, this.name, this.price, this.tagline, this.perks,
      {this.popular = false});
}
