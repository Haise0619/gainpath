import 'package:gainpath/features/identity/data/in_memory/identity_seed.dart';
import 'package:gainpath/features/identity/domain/repositories/member_profile_repository.dart';

/// Session-scoped in-memory [MemberProfileRepository] backed by [IdentitySeed].
class InMemoryMemberProfileRepository implements MemberProfileRepository {
  @override
  String get memberName => IdentitySeed.memberName;

  @override
  String get memberEmail => IdentitySeed.memberEmail;

  @override
  String get memberTier => IdentitySeed.memberTier;

  @override
  String get memberGender => IdentitySeed.memberGender;

  @override
  int get memberAge => IdentitySeed.memberAge;

  @override
  String get memberExperience => IdentitySeed.memberExperience;

  @override
  String get memberActivityLevel => IdentitySeed.memberActivityLevel;

  @override
  int get memberHeight => IdentitySeed.memberHeight;

  @override
  int get memberWeight => IdentitySeed.memberWeight;

  @override
  List<String> get memberTrainingFocus => IdentitySeed.memberTrainingFocus;
}
