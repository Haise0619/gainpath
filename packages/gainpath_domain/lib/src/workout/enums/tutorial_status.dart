enum TutorialStatus {
  active('Active'),
  draft('Draft');

  const TutorialStatus(this.label);
  final String label;

  static TutorialStatus fromLabel(String label) =>
      values.firstWhere((v) => v.label == label);
}

/// Authoring lifecycle for a catalog entry; draft tutorials display Inactive.
enum ExerciseCatalogStatus {
  active('Active'),
  inactive('Inactive'),
  archived('Archived');

  const ExerciseCatalogStatus(this.label);
  final String label;
}
