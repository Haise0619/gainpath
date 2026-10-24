import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/coach_direct_reads.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_coach_account_repository.dart';

class _User extends Fake implements User {
  _User({this.userId = 'coach', this.verified = true});
  final String userId;
  final bool verified;
  @override
  String get uid => userId;
  @override
  bool get emailVerified => verified;
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth([User? user]) : _user = user ?? _User();
  final User _user;
  @override
  User? get currentUser => _user;
}

class _Reads extends Fake implements CoachDirectReads {
  @override
  final scope = SessionScope(userId: 'coach', organizationId: 'org');
  String? error;
  void Function()? onRead;
  @override
  Future<Map<String, dynamic>> loadSettings() async {
    onRead?.call();
    if (error != null) throw CoachRepositoryException(error!);
    return {
      'schemaVersion': 1,
      'revision': 4,
      'contactPhone': '',
      'updatedAtMillis': null,
      'coachNotificationPreferences': {
        'newBookings': true,
        'cancellations': false,
        'reminders': false,
      }
    };
  }

  @override
  Future<Map<String, dynamic>> loadCertifications(
          {String? coachId, String? afterId, String? certificationId}) async =>
      {
        'schemaVersion': 1,
        'approvedCount': 0,
        'certificationVerified': false,
        'certifications': [],
        'nextCursor': null,
      };
}

void main() {
  late _Reads reads;
  late FirebaseCoachAccountRepository repository;
  late bool current;
  setUp(() {
    current = true;
    reads = _Reads();
    repository = FirebaseCoachAccountRepository(
        scope: reads.scope,
        isCurrent: () => current,
        auth: _Auth(),
        directReads: reads);
  });
  test('explicit direct injection reads settings and certification summary',
      () async {
    expect((await repository.loadSettings()).revision, 4);
    expect((await repository.loadCertificationSummary()).approved, 0);
  });
  test(
      'direct permission rejection propagates without invoking Firebase functions',
      () async {
    reads.error = 'permission-denied';
    await expectLater(
        repository.loadSettings(),
        throwsA(isA<CoachRepositoryException>()
            .having((e) => e.code, 'code', 'permission-denied')));
  });
  test('session replacement discards direct settings result', () async {
    reads.onRead = () => current = false;
    await expectLater(
        repository.loadSettings(),
        throwsA(isA<CoachRepositoryException>()
            .having((e) => e.code, 'code', 'unauthenticated')));
  });
  test('wrong Auth account and unverified email reject direct reads', () async {
    for (final user in [_User(userId: 'other'), _User(verified: false)]) {
      final rejected = FirebaseCoachAccountRepository(
          scope: reads.scope,
          isCurrent: () => true,
          auth: _Auth(user),
          directReads: reads);
      await expectLater(
          rejected.loadSettings(),
          throwsA(isA<CoachRepositoryException>()
              .having((e) => e.code, 'code', 'unauthenticated')));
    }
  });
  test('direct injection cannot carry another organization scope', () {
    expect(
        () => FirebaseCoachAccountRepository(
            scope: SessionScope(userId: 'coach', organizationId: 'other'),
            isCurrent: () => true,
            auth: _Auth(),
            directReads: reads),
        throwsA(isA<CoachRepositoryException>()));
  });
}
