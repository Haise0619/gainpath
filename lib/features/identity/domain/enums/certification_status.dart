enum CertificationStatus {
  verified('Verified'),
  pendingReview('Pending review'),
  rejected('Rejected');

  const CertificationStatus(this.label);
  final String label;

  static CertificationStatus fromLabel(String label) =>
      values.firstWhere((v) => v.label == label);
}
