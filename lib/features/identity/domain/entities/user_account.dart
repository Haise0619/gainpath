import 'package:gainpath/features/identity/domain/enums/account_status.dart';

/// [status] is mutable — suspending a member, deactivating a coach, and
/// verifying/rejecting a coach's credentials all mutate the account in
/// place, the same pattern used for `GymEquipment.isActive` elsewhere.
/// [branch] and [specialty] are only meaningful for a `Coach` account —
/// a member's is always null. They're the account-shell counterpart to
/// `Coach.branch`/`Coach.specialty` in `MockData.coaches`: set the moment
/// a coach is provisioned, before their full public profile exists.
class UserAccount {
  final String name;
  final String email;
  final String role;
  AccountStatus status;
  final String? branch;
  final String? specialty;
  UserAccount(this.name, this.email, this.role, this.status, {this.branch, this.specialty});
}
