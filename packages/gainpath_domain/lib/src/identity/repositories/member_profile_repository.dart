/// Data access contract for the identity feature. Implemented in-memory for the
/// prototype; a Firebase implementation will sit behind the same interface.
abstract class MemberProfileRepository {
  String get memberName;
  String get memberEmail;
  String get memberTier;
  String get memberGender;
  int get memberAge;
  String get memberExperience;
  String get memberActivityLevel;
  int get memberHeight;
  int get memberWeight;
  List<String> get memberTrainingFocus;
}
