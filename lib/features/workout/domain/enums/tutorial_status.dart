enum TutorialStatus {
  active('Active'),
  draft('Draft');

  const TutorialStatus(this.label);
  final String label;

  static TutorialStatus fromLabel(String label) =>
      values.firstWhere((v) => v.label == label);
}
