import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/coach_direct_reads.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_admin_web/features/identity/presentation/admin/coach_certification_admin_adapter.dart';

class _Repository extends Fake implements CoachProfileAdminRepository {
  @override
  final scope = SessionScope(userId: 'admin', organizationId: 'org');
  bool current = true;
  @override
  Future<bool> canManageDirectory() async => current;
}

class _Reads extends Fake implements CoachDirectReads {
  _Reads(this.scope);
  @override
  final SessionScope scope;
  String? error;
  void Function()? onRead;
  @override
  Future<Map<String, dynamic>> loadCertifications(
      {String? coachId, String? afterId, String? certificationId}) async {
    onRead?.call();
    if (error != null) throw CoachRepositoryException(error!);
    return {
      'coachId': coachId,
      'afterId': afterId,
      'certificationId': certificationId
    };
  }
}

void main() {
  late _Repository repository;
  late _Reads reads;
  late CoachCertificationAdminAdapter adapter;
  setUp(() {
    repository = _Repository();
    reads = _Reads(repository.scope);
    adapter = CoachCertificationAdminAdapter(repository, directReads: reads);
  });
  test('explicit direct injection preserves selected coach and page arguments',
      () async {
    expect(await adapter.load('coach', afterId: 'cursor'), {
      'coachId': 'coach',
      'afterId': 'cursor',
      'certificationId': null,
    });
  });
  test('direct rejection has no callable fallback', () async {
    reads.error = 'permission-denied';
    await expectLater(
        adapter.load('coach'), throwsA(isA<CoachRepositoryException>()));
  });
  test('admin session replacement discards a completed direct response',
      () async {
    reads.onRead = () => repository.current = false;
    await expectLater(
        adapter.load('coach'), throwsA(isA<CoachRepositoryException>()));
  });
  test('direct injection cannot carry another organization scope', () {
    expect(
        () => CoachCertificationAdminAdapter(repository,
            directReads:
                _Reads(SessionScope(userId: 'admin', organizationId: 'other'))),
        throwsA(isA<CoachRepositoryException>()));
  });
}
