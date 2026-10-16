class FacilityNameSnapshot {
  const FacilityNameSnapshot(
      {required this.organizationId,
      required this.displayName,
      required this.editBaseline});
  final String organizationId, displayName;
  final Object editBaseline;
}

class FacilitySettingsConflict implements Exception {
  const FacilitySettingsConflict();
}

class FacilitySettingsSessionChanged implements Exception {
  const FacilitySettingsSessionChanged();
}

abstract interface class FacilitySettingsRepository {
  Future<FacilityNameSnapshot> load();
  Future<FacilityNameSnapshot> save(FacilityNameSnapshot original,
      {required String displayName});
}
