import 'package:gainpath_domain/gainpath_domain.dart';
import 'member_document_snapshot.dart';

/// SDK-free boundary; the mobile adapter adds a server timestamp on writes.
abstract interface class FitnessProfileGateway {
  Future<Map<String, Object?>?> read(SessionScope scope);

  /// [data] is the intended patch (full editable fields for a creation).
  /// Null [expectedSnapshot] means a server-confirmed missing document.
  Future<void> write(SessionScope scope, Map<String, Object?> data,
      {required Map<String, Object?>? expectedSnapshot});
}

class FirebaseFitnessProfileRepository implements FitnessProfileRepository {
  FirebaseFitnessProfileRepository(
      {required this.scope, required this.gateway}) {
    for (final id in [scope.userId, scope.organizationId]) {
      if (id.contains('/') || id == '.' || id == '..') {
        throw ArgumentError('Profile ownership requires document IDs.');
      }
    }
  }

  @override
  final SessionScope scope;
  final FitnessProfileGateway gateway;
  final Object _lifetime = Object();
  bool _knownMissing = false;

  @override
  Future<FitnessProfile?> load() async {
    final data = await gateway.read(scope);
    _knownMissing = data == null;
    if (data == null) return null;
    try {
      if (data['schemaVersion'] != 1) throw const FormatException();
      final rawGoals = (data['goals'] as List).cast<String>();
      if (rawGoals.toSet().length != rawGoals.length) {
        throw const FormatException();
      }
      return FitnessProfile(
        gender: ProfileGender.values.byName(data['gender'] as String),
        age: data['age'] as int,
        heightCm: data['heightCm'] as int,
        weightKg: data['weightKg'] as int,
        experience:
            TrainingExperience.values.byName(data['experience'] as String),
        activity: ActivityLevel.values.byName(data['activity'] as String),
        goals: rawGoals.map(FitnessGoal.values.byName).toSet(),
        editBaseline: _ProfileBaseline(_lifetime, freezeMemberDocument(data)!),
      );
    } catch (_) {
      throw const FitnessProfileException(
          'Your saved profile could not be read. Please contact support.');
    }
  }

  @override
  Future<void> save(FitnessProfile profile) async {
    final baseline = profile.editBaseline;
    final Map<String, Object?>? original;
    if (baseline is _ProfileBaseline &&
        identical(baseline.lifetime, _lifetime)) {
      original = baseline.snapshot;
    } else if (baseline == null && _knownMissing) {
      original = null;
    } else {
      throw const FitnessProfileException(
          'Reload your profile before saving this form.',
          reloadRequired: true);
    }
    final fields = <String, Object?>{
      'schemaVersion': 1,
      'gender': profile.gender.name,
      'age': profile.age,
      'heightCm': profile.heightCm,
      'weightKg': profile.weightKg,
      'experience': profile.experience.name,
      'activity': profile.activity.name,
      'goals': profile.goals.map((goal) => goal.name).toList()..sort(),
    };
    final patch = freezeMemberDocument({
      for (final field in fields.entries)
        if (original == null ||
            (field.key != 'schemaVersion' &&
                !sameMemberDocumentValue(field.value, original[field.key])))
          field.key: field.value,
    })!;
    await gateway.write(scope, patch, expectedSnapshot: original);
    _knownMissing = false;
  }
}

class _ProfileBaseline {
  const _ProfileBaseline(this.lifetime, this.snapshot);
  final Object lifetime;
  final Map<String, Object?> snapshot;
}
