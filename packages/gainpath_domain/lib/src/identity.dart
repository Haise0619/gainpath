enum AppRole { member, coach, admin }

class AuthSession {
  const AuthSession({
    this.userId = 'demo-user',
    this.organizationId = 'demo-org',
    this.branchIds = const [],
    this.datasetScope,
    required this.email,
    this.displayName,
    required this.role,
    this.needsVerification = false,
    this.accountLifecycleState = 'active',
  });

  final String userId;
  final String organizationId;
  final List<String> branchIds;
  final VerifiedDatasetScope? datasetScope;
  SessionScope get scope => SessionScope(
      userId: userId,
      organizationId: organizationId,
      datasetScope: datasetScope);
  final String email;
  final String? displayName;
  final AppRole role;
  final bool needsVerification;

  /// Pending deletion retains a narrow authenticated recovery session only.
  final String accountLifecycleState;

  @override
  bool operator ==(Object other) =>
      other is AuthSession &&
      other.userId == userId &&
      other.organizationId == organizationId &&
      other.datasetScope == datasetScope &&
      _sameStrings(other.branchIds, branchIds) &&
      other.email == email &&
      other.displayName == displayName &&
      other.role == role &&
      other.needsVerification == needsVerification &&
      other.accountLifecycleState == accountLifecycleState;

  @override
  int get hashCode => Object.hash(
      userId,
      organizationId,
      Object.hashAll(branchIds),
      datasetScope,
      email,
      displayName,
      role,
      needsVerification,
      accountLifecycleState);
}

bool _sameStrings(List<String> left, List<String> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

/// Immutable account ownership. Original IDs are never sanitized.
class SessionScope {
  SessionScope(
      {required this.userId, required this.organizationId, this.datasetScope}) {
    if (userId.trim().isEmpty || organizationId.trim().isEmpty) {
      throw ArgumentError('A user and organization are required.');
    }
  }
  final String userId;
  final String organizationId;
  final VerifiedDatasetScope? datasetScope;

  /// Routing metadata only; authorization is enforced for every server read.
  String get dataRootPath => datasetScope?.rootPath ?? 'orgs/$organizationId';
  String get userDocumentPath =>
      datasetScope == null ? 'users/$userId' : '$dataRootPath/users/$userId';
  @override
  bool operator ==(Object other) =>
      other is SessionScope &&
      other.userId == userId &&
      other.organizationId == organizationId &&
      other.datasetScope == datasetScope;
  @override
  int get hashCode => Object.hash(userId, organizationId, datasetScope);
}

/// Server-authorized routing metadata. Never grants authorization by itself.
class VerifiedDatasetScope {
  const VerifiedDatasetScope(
      {required this.datasetId,
      required this.seedId,
      required this.revision,
      required this.rootPath});
  final String datasetId, seedId, rootPath;
  final int revision;
  @override
  bool operator ==(Object other) =>
      other is VerifiedDatasetScope &&
      other.datasetId == datasetId &&
      other.seedId == seedId &&
      other.revision == revision &&
      other.rootPath == rootPath;
  @override
  int get hashCode => Object.hash(datasetId, seedId, revision, rootPath);
}
