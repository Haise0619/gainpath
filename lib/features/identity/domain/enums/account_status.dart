enum AccountStatus {
  active('Active'),
  suspended('Suspended'),
  deactivated('Deactivated'),
  invited('Invited'),
  pending('Pending'),
  verified('Verified'),
  rejected('Rejected');

  const AccountStatus(this.label);
  final String label;

  static AccountStatus fromLabel(String label) =>
      values.firstWhere((v) => v.label == label);
}
