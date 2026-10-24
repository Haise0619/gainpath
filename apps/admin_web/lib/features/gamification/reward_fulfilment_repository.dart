import 'package:gainpath_domain/gamification.dart';

class AdminRewardVoucher {
  const AdminRewardVoucher({required this.memberId, required this.redemption});
  final String memberId;
  final VerifiedRewardRedemption redemption;
}

abstract interface class RewardFulfilmentRepository {
  bool get current;
  Future<AdminRewardVoucher> inspect(String redemptionId);
  Future<AdminRewardVoucher> fulfil(String redemptionId);
}
