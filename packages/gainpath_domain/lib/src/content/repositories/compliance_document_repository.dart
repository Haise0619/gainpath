// Organization-scoped compliance drafts only. No publication or consent changes.

abstract class ComplianceDocumentRepository {
  Future<ComplianceDocumentSnapshot> load();
  Future<ComplianceDocumentSnapshot> save(ComplianceDocumentSnapshot original,
      {required String text, required bool isArchived});
}

class ComplianceDocument {
  const ComplianceDocument(
      {required this.text,
      required this.isArchived,
      required this.revision,
      required this.updatedAt});
  final String text;
  final bool isArchived;
  final int revision;
  final DateTime updatedAt;
}

abstract class ComplianceDocumentEditBaseline {}

class ComplianceDocumentSnapshot {
  const ComplianceDocumentSnapshot(
      {required this.current,
      required this.history,
      required this.editBaseline});
  final ComplianceDocument? current;

  /// Most recent 20 immutable snapshots, including the current revision.
  final List<ComplianceDocument> history;
  final ComplianceDocumentEditBaseline editBaseline;
}

class ComplianceDocumentConflict implements Exception {
  const ComplianceDocumentConflict();
}

class ComplianceDocumentSessionChanged implements Exception {
  const ComplianceDocumentSessionChanged();
}
