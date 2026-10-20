class AdminMemberRecord {
  const AdminMemberRecord(
      {required this.id,
      required this.name,
      required this.email,
      required this.status});
  final String id, name, email, status;
  String get statusLabel => status.isEmpty
      ? 'Not recorded'
      : '${status[0].toUpperCase()}${status.substring(1)}';
}

class AdminMemberPage {
  AdminMemberPage(List<AdminMemberRecord> items, {this.nextCursor})
      : items = List.unmodifiable(items);
  final List<AdminMemberRecord> items;
  final String? nextCursor;
}

class AdminMemberDetails {
  AdminMemberDetails(
      {required this.member,
      required this.organizationId,
      required List<String> branchIds,
      this.createdAtMillis,
      this.updatedAtMillis})
      : branchIds = List.unmodifiable(branchIds);
  final AdminMemberRecord member;
  final String organizationId;
  final List<String> branchIds;
  final int? createdAtMillis, updatedAtMillis;
}

/// Read-only organization membership directory. No account lifecycle authority.
abstract interface class AdminMemberDirectoryRepository {
  Future<AdminMemberDetails> loadDetails(String memberId);
  Future<AdminMemberPage> loadPage(
      {String query = '', String status = 'All', String? afterId});
}
