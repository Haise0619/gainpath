/// The signed-in Admin's own display name and authoritative sign-in email.
/// An empty name clears the optional name and uses the email as the label.
abstract class AdminAccountContactRepository {
  Future<AdminAccountContact> load();
  Future<AdminAccountContact> save(AdminAccountContact original,
      {required String displayName});
}

abstract class AdminAccountContactBaseline {}

class AdminAccountContact {
  const AdminAccountContact(
      {required this.displayName,
      required this.email,
      required this.editBaseline});
  final String displayName, email;
  final AdminAccountContactBaseline editBaseline;
}

class AdminAccountContactConflict implements Exception {
  const AdminAccountContactConflict();
}

class AdminAccountContactSessionChanged implements Exception {
  const AdminAccountContactSessionChanged();
}
