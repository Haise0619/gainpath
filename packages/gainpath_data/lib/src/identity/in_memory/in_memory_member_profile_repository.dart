import '../../fakes/mock_data_session.dart';
import 'identity_seed.dart';
import 'package:gainpath_domain/identity.dart';

/// Session-scoped in-memory [MemberProfileRepository] backed by [IdentitySeed].
class InMemoryMemberProfileRepository implements MemberProfileRepository {
  InMemoryMemberProfileRepository({MockDataSession? session})
      : _seed = (session ?? MockDataSession()).identity;

  final IdentitySeed _seed;

  @override
  String get memberName => _seed.memberName;

  @override
  String get memberEmail => _seed.memberEmail;

  @override
  String get memberTier => _seed.memberTier;

  @override
  String get memberGender => _seed.memberGender;

  @override
  int get memberAge => _seed.memberAge;

  @override
  String get memberExperience => _seed.memberExperience;

  @override
  String get memberActivityLevel => _seed.memberActivityLevel;

  @override
  int get memberHeight => _seed.memberHeight;

  @override
  int get memberWeight => _seed.memberWeight;

  @override
  List<String> get memberTrainingFocus => _seed.memberTrainingFocus;
}
