import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

/// A device-local preference, never a price, stock reservation or wallet.
abstract class RewardGoalStore {
  Future<String?> load(SessionScope scope);
  Future<void> save(SessionScope scope, String? itemId,
      {required bool Function() isCurrent});
}
