import 'package:gainpath/features/identity/data/in_memory/identity_seed.dart';
import 'package:gainpath/features/identity/domain/entities/branch.dart';
import 'package:gainpath/features/identity/domain/entities/user_account.dart';
import 'package:gainpath/features/identity/domain/repositories/user_account_repository.dart';

/// Session-scoped in-memory [UserAccountRepository] backed by [IdentitySeed].
class InMemoryUserAccountRepository implements UserAccountRepository {
  @override
  String get adminName => IdentitySeed.adminName;

  @override
  String get adminEmail => IdentitySeed.adminEmail;

  @override
  List<UserAccount> get users => IdentitySeed.users;

  @override
  List<Branch> get branches => IdentitySeed.branches;
}
