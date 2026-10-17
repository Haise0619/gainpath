import 'package:gainpath_domain/gainpath_domain.dart';

/// SDK-free boundary. The adapter performs one transaction, checks revision and
/// session, supplies server timestamps, and appends an immutable revision.
abstract interface class NumericFitnessGoalGateway {
  String allocateId(SessionScope scope);
  Future<Map<String, Map<String, Object?>>> readActive(SessionScope scope,
      {required int limit});
  Future<void> commit(
      SessionScope scope, String id, Map<String, Object?> fields,
      {required int? expectedRevision});
}

class FirebaseNumericFitnessGoalRepository
    implements NumericFitnessGoalRepository {
  FirebaseNumericFitnessGoalRepository(
      {required this.scope, required this.gateway}) {
    for (final id in [scope.userId, scope.organizationId]) {
      if (id.contains('/') || id == '.' || id == '..') {
        throw ArgumentError('Goal ownership requires document IDs.');
      }
    }
  }
  @override
  final SessionScope scope;
  final NumericFitnessGoalGateway gateway;
  final Object _lifetime = Object();
  final Set<String> _allocated = {};
  static const activeQueryLimit = 21;

  @override
  String allocateId() {
    final id = gateway.allocateId(scope);
    validateGoalId(id);
    _allocated.add(id);
    return id;
  }

  @override
  Future<List<NumericFitnessGoal>> loadActive() async {
    final data = await gateway.readActive(scope, limit: activeQueryLimit);
    try {
      final goals = data.entries.map((entry) {
        final d = entry.value;
        final category =
            NumericGoalCategory.values.byName(d['category'] as String);
        if (d['schemaVersion'] != 1 ||
            d['unit'] != category.unit ||
            d['evaluationPeriod'] != category.evaluationPeriod ||
            d['status'] != 'active') {
          throw const FormatException();
        }
        return NumericFitnessGoal(
            id: entry.key,
            category: category,
            targetValue: (d['targetValue'] as num).toDouble(),
            status: NumericGoalStatus.active,
            revision: d['revision'] as int,
            createdAt: d['createdAt'] as DateTime,
            updatedAt: d['updatedAt'] as DateTime,
            editBaseline: _GoalBaseline(_lifetime));
      }).toList();
      goals.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return List.unmodifiable(goals);
    } catch (_) {
      throw const NumericGoalException(
          'A saved target could not be read. Contact support.');
    }
  }

  @override
  Future<void> create(
      {required String id,
      required NumericGoalCategory category,
      required double targetValue}) async {
    validateGoalId(id);
    if (!_allocated.contains(id)) {
      throw const NumericGoalException('Open a new target form before saving.');
    }
    _validate(category, targetValue);
    await gateway.commit(
        scope,
        id,
        {
          'schemaVersion': 1,
          'category': category.name,
          'targetValue': _storedTarget(category, targetValue),
          'unit': category.unit,
          'evaluationPeriod': category.evaluationPeriod,
          'status': 'active',
        },
        expectedRevision: null);
  }

  @override
  Future<void> update(NumericFitnessGoal original,
      {required double targetValue}) async {
    _checkBaseline(original);
    _validate(original.category, targetValue);
    if (targetValue == original.targetValue) return;
    await gateway.commit(scope, original.id,
        {'targetValue': _storedTarget(original.category, targetValue)},
        expectedRevision: original.revision);
  }

  num _storedTarget(NumericGoalCategory category, double targetValue) =>
      category == NumericGoalCategory.bodyWeight
          ? targetValue
          : targetValue.toInt();

  @override
  Future<void> archive(NumericFitnessGoal original) async {
    _checkBaseline(original);
    await gateway.commit(scope, original.id, {'status': 'archived'},
        expectedRevision: original.revision);
  }

  void _validate(NumericGoalCategory category, double targetValue) {
    final error = category.validate(targetValue);
    if (error != null) throw NumericGoalException(error);
  }

  void _checkBaseline(NumericFitnessGoal goal) {
    final baseline = goal.editBaseline;
    if (baseline is! _GoalBaseline ||
        !identical(baseline.lifetime, _lifetime) ||
        goal.status != NumericGoalStatus.active) {
      throw const NumericGoalException(
          'Reload targets before changing this target.',
          reloadRequired: true);
    }
  }
}

class _GoalBaseline {
  const _GoalBaseline(this.lifetime);
  final Object lifetime;
}
