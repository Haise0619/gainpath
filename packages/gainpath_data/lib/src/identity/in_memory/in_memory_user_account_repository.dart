import '../../fakes/mock_data_session.dart';
import 'identity_seed.dart';
import 'package:gainpath_domain/identity.dart';

/// Session-scoped in-memory [UserAccountRepository] backed by [IdentitySeed].
class InMemoryUserAccountRepository implements UserAccountRepository {
  InMemoryUserAccountRepository({MockDataSession? session})
      : _seed = (session ?? MockDataSession()).identity;

  final IdentitySeed _seed;

  @override
  String get adminName => _seed.adminName;

  @override
  String get adminEmail => _seed.adminEmail;

  @override
  List<UserAccount> get users => _seed.users;

  @override
  List<Branch> get branches => _seed.branches;
}
