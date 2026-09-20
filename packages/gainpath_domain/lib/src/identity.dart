enum AppRole { member, coach, admin }

class AuthSession {
  const AuthSession({
    this.userId = 'demo-user',
    this.organizationId = 'demo-org',
    this.branchIds = const [],
    required this.email,
    required this.role,
    this.needsVerification = false,
  });

  final String userId;
  final String organizationId;
  final List<String> branchIds;
  SessionScope get scope =>
      SessionScope(userId: userId, organizationId: organizationId);
  final String email;
  final AppRole role;
  final bool needsVerification;

  @override
  bool operator ==(Object other) =>
      other is AuthSession &&
      other.userId == userId &&
      other.organizationId == organizationId &&
      _sameStrings(other.branchIds, branchIds) &&
      other.email == email &&
      other.role == role &&
      other.needsVerification == needsVerification;

  @override
  int get hashCode => Object.hash(userId, organizationId,
      Object.hashAll(branchIds), email, role, needsVerification);
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
  SessionScope({required this.userId, required this.organizationId}) {
    if (userId.trim().isEmpty || organizationId.trim().isEmpty) {
      throw ArgumentError('A user and organization are required.');
    }
  }
  final String userId;
  final String organizationId;
  @override
  bool operator ==(Object other) =>
      other is SessionScope &&
      other.userId == userId &&
      other.organizationId == organizationId;
  @override
  int get hashCode => Object.hash(userId, organizationId);
}
