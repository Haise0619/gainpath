import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart' show CoachRepositoryException;

/// Scoped direct reads; existing SDK/repository injection remains available.
/// The production Rules and server-owned scope attestations enforce authority.
const directCoachReadsEnabled =
    bool.fromEnvironment('DIRECT_COACH_READS', defaultValue: true);

abstract interface class CoachReadSnapshot {
  Future<Map<String, dynamic>?> get(String path);
}

abstract interface class CoachDirectReadGateway {
  /// Every get in [action] must use the same server transaction snapshot.
  Future<T> transact<T>(Future<T> Function(CoachReadSnapshot) action);
}

class CoachDirectReads {
  CoachDirectReads(
      {required this.scope,
      required this.gateway,
      required this.checkSession}) {
    _identifier(scope.userId);
    _identifier(scope.organizationId);
  }
  final SessionScope scope;
  final CoachDirectReadGateway gateway;
  final void Function() checkSession;
  static final _id = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static final _certificationId = RegExp(r'^[a-f0-9]{32}$');
  static void _identifier(String value) {
    if (!_id.hasMatch(value)) {
      throw const CoachRepositoryException('invalid-argument');
    }
  }

  Future<T> _read<T>(Future<T> Function(CoachReadSnapshot) action) async {
    checkSession();
    final value = await gateway.transact((snapshot) async {
      checkSession();
      final result = await action(snapshot);
      checkSession();
      return result;
    });
    checkSession();
    return value;
  }

  // Rules validate live organization status and the server-owned scope against
  // the current identity/membership. No private organization read is needed.
  Future<Map<String, dynamic>> _authority(
      CoachReadSnapshot snapshot, List<String> roles) async {
    final org = scope.organizationId, uid = scope.userId;
    final facts = await Future.wait([
      snapshot.get('users/$uid'),
      snapshot.get('orgs/$org/members/$uid'),
      snapshot.get('orgs/$org/coachReadScopes/$uid'),
    ]);
    checkSession();
    final user = facts[0], member = facts[1], proof = facts[2];
    final branches = member?['branchIds'];
    final validated = proof?['validatedBranchIds'];
    if (user?['organizationId'] != org ||
        member?['organizationId'] != org ||
        member?['status'] != 'active' ||
        !roles.contains(member?['role']) ||
        branches is! List ||
        branches.any((id) => id is! String) ||
        proof?['schemaVersion'] != 1 ||
        proof?['organizationId'] != org ||
        proof?['userId'] != uid ||
        proof?['role'] != member?['role'] ||
        validated is! List ||
        validated.length != branches.length ||
        List.generate(branches.length, (i) => i)
            .any((i) => validated[i] != branches[i])) {
      throw const CoachRepositoryException('permission-denied');
    }
    return user!;
  }

  Future<Map<String, dynamic>> loadSettings() => _read((snapshot) async {
        final user = await _authority(snapshot, ['coach']);
        return {
          'schemaVersion': 1,
          'revision': user['coachAccountRevision'] ?? 0,
          'updatedAtMillis': user['coachAccountUpdatedAtMillis'],
          'contactPhone': user['contactPhone'] ?? '',
          'coachNotificationPreferences':
              user['coachNotificationPreferences'] ??
                  {
                    'newBookings': true,
                    'cancellations': true,
                    'reminders': false,
                  },
        };
      });

  Future<Map<String, dynamic>> loadCertifications(
      {String? coachId, String? afterId, String? certificationId}) async {
    final target = coachId ?? scope.userId;
    _identifier(target);
    // Callable boundedText trims cursor/selected ids before validating.
    final after = afterId?.trim(), selected = certificationId?.trim();
    if ((after != null && !_certificationId.hasMatch(after)) ||
        (selected != null && !_certificationId.hasMatch(selected)) ||
        (after != null && selected != null)) {
      throw const CoachRepositoryException('invalid-argument');
    }
    return _read((snapshot) async {
      await _authority(
          snapshot, target == scope.userId ? ['coach', 'admin'] : ['admin']);
      final base = 'orgs/${scope.organizationId}/coachProfiles/$target';
      final state = await snapshot.get('$base/certificationState/current');
      final rawIds = state?['certificationIds'];
      final ids = rawIds is List ? rawIds.toList() : <dynamic>[];
      if (ids.length > 100 ||
          ids.any((id) => id is! String || !_certificationId.hasMatch(id))) {
        throw const CoachRepositoryException('failed-precondition');
      }
      ids.sort((a, b) => (a as String).compareTo(b as String));
      if (selected != null && !ids.contains(selected)) {
        throw const CoachRepositoryException('not-found');
      }
      final remaining = selected != null
          ? [selected]
          : ids
              .cast<String>()
              .where((id) => after == null || id.compareTo(after) > 0)
              .toList();
      final page = remaining.take(20).toList();
      final items = await Future.wait(
          page.map((id) => snapshot.get('$base/certifications/$id')));
      final certifications = <Map<String, dynamic>>[];
      for (var i = 0; i < page.length; i++) {
        final item = items[i];
        if (item == null) continue;
        final rawRevision = item['revision'];
        final revision =
            rawRevision is num ? rawRevision : num.tryParse('$rawRevision');
        if (revision == null ||
            !revision.isFinite ||
            revision != revision.round() ||
            revision < 1 ||
            revision > 100) {
          throw const CoachRepositoryException('failed-precondition');
        }
        final history = <Map<String, dynamic>>[];
        if (selected != null) {
          final count = revision.toInt() > 20 ? 20 : revision.toInt();
          final entries = await Future.wait(List.generate(
              count,
              (n) => snapshot.get(
                  '$base/certifications/${page[i]}/history/${revision.toInt() - n}')));
          history.addAll(entries.whereType<Map<String, dynamic>>());
        }
        certifications.add({...item, 'history': history});
      }
      return {
        'schemaVersion': 1,
        'certifications': certifications,
        'nextCursor': remaining.length > 20 ? page.last : null,
        'approvedCount': state?['approvedCount'] ?? 0,
        'certificationVerified': state?['certificationVerified'] == true,
      };
    });
  }
}
