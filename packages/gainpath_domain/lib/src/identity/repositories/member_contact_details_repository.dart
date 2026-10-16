/// FR-1.5 / C4 users.contactDetails: optional free-text contact information.
class MemberContactDetails {
  const MemberContactDetails({required this.value, required this.editBaseline});
  final String value;
  final Object editBaseline;
}

abstract interface class MemberContactDetailsRepository {
  Future<MemberContactDetails> load();
  Future<MemberContactDetails> save(
      MemberContactDetails original, String value);
}

class MemberContactDetailsException implements Exception {
  const MemberContactDetailsException(this.message,
      {this.reloadRequired = false});
  final String message;
  final bool reloadRequired;
}
