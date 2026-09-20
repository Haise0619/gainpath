import '../entities/branch.dart';
import '../entities/user_account.dart';

/// Data access contract for the identity feature. Implemented in-memory for the
/// prototype; a Firebase implementation will sit behind the same interface.
abstract class UserAccountRepository {
  String get adminName;
  String get adminEmail;
  List<UserAccount> get users;
  List<Branch> get branches;
}
