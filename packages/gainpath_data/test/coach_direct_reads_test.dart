import 'dart:async';
import 'package:gainpath_data/coach_direct_reads.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';
import 'package:test/test.dart';

final scope = SessionScope(userId: 'coach', organizationId: 'org');
String id(int n) => n.toRadixString(16).padLeft(32, '0');
const base = 'orgs/org/coachProfiles/coach';
Matcher code(String value) =>
    isA<CoachRepositoryException>().having((e) => e.code, 'code', value);

class MemorySnapshot implements CoachDirectReadGateway, CoachReadSnapshot {
  final documents = <String, Map<String, dynamic>>{
    'users/coach': {'organizationId': 'org'},
    'orgs/org/members/coach': {
      'organizationId': 'org',
      'status': 'active',
      'role': 'coach',
      'branchIds': <String>[],
    },
    'orgs/org': {'status': 'active'},
    'orgs/org/coachReadScopes/coach': {
      'schemaVersion': 1,
      'organizationId': 'org',
      'userId': 'coach',
      'role': 'coach',
      'validatedBranchIds': <String>[],
    },
  };
  final reads = <String>[];
  int transactions = 0;
  Future<void> Function()? beforeRead;
  @override
  Future<T> transact<T>(Future<T> Function(CoachReadSnapshot) action) async {
    transactions++;
    return action(this);
  }

  @override
  Future<Map<String, dynamic>?> get(String path) async {
    reads.add(path);
    await beforeRead?.call();
    return documents[path];
  }
}

void main() {
  late MemorySnapshot db;
  late CoachDirectReads reads;
  late bool current;
  setUp(() {
    db = MemorySnapshot();
    current = true;
    reads = CoachDirectReads(
        scope: scope,
        gateway: db,
        checkSession: () {
          if (!current) throw const CoachRepositoryException('unauthenticated');
        });
  });
  test('prepared production direct reads are selected by default', () {
    expect(directCoachReadsEnabled, isTrue);
  });
  test('reads a restricted authority proof instead of the private org document',
      () async {
    db.documents.remove('orgs/org');
    await reads.loadSettings();
    expect(db.reads, contains('orgs/org/coachReadScopes/coach'));
    expect(db.reads, isNot(contains('orgs/org')));
  });
  test(
      'missing or stale trusted scope fails closed without a callable fallback',
      () async {
    db.documents.remove('orgs/org/coachReadScopes/coach');
    await expectLater(reads.loadSettings(), throwsA(code('permission-denied')));
  });
  test('settings return callable defaults without exposing identity fields',
      () async {
    expect(await reads.loadSettings(), {
      'schemaVersion': 1,
      'revision': 0,
      'updatedAtMillis': null,
      'contactPhone': '',
      'coachNotificationPreferences': {
        'newBookings': true,
        'cancellations': true,
        'reminders': false,
      },
    });
    expect(db.transactions, 1);
  });
  test('settings preserve saved revisions, timestamps and preferences',
      () async {
    db.documents['users/coach']!.addAll({
      'coachAccountRevision': 7,
      'coachAccountUpdatedAtMillis': 123,
      'contactPhone': '+60123456789',
      'unrelatedPrivateField': 'excluded',
      'coachNotificationPreferences': {'newBookings': false},
    });
    final value = await reads.loadSettings();
    expect(value['revision'], 7);
    expect(value['updatedAtMillis'], 123);
    expect(value['contactPhone'], '+60123456789');
    expect(value['coachNotificationPreferences'], {'newBookings': false});
    expect(value.containsKey('unrelatedPrivateField'), isFalse);
  });
  for (final field in [
    'user-org',
    'member-org',
    'inactive',
    'role',
    'branches'
  ]) {
    test('rejects changed authority: $field', () async {
      switch (field) {
        case 'user-org':
          db.documents['users/coach']!['organizationId'] = 'other';
        case 'member-org':
          db.documents['orgs/org/members/coach']!['organizationId'] = 'other';
        case 'inactive':
          db.documents['orgs/org/members/coach']!['status'] = 'disabled';
        case 'role':
          db.documents['orgs/org/members/coach']!['role'] = 'member';
        case 'branches':
          db.documents['orgs/org/members/coach']!['branchIds'] = [123];
      }
      await expectLater(
          reads.loadSettings(), throwsA(code('permission-denied')));
      await expectLater(
          reads.loadCertifications(), throwsA(code('permission-denied')));
    });
  }
  test(
      'Rules denial for inactive organization rejects before credential payload',
      () async {
    db.beforeRead = () async {
      throw const CoachRepositoryException('permission-denied');
    };
    await expectLater(
        reads.loadCertifications(), throwsA(code('permission-denied')));
    expect(db.reads.any((p) => p.contains('coachProfiles')), isFalse);
  });
  test('coach cannot request another account certifications', () async {
    await expectLater(reads.loadCertifications(coachId: 'other'),
        throwsA(code('permission-denied')));
  });
  test('admin can read another coach without requiring target membership',
      () async {
    db.documents['orgs/org/members/coach']!['role'] = 'admin';
    db.documents['orgs/org/coachReadScopes/coach']!['role'] = 'admin';
    final result = await reads.loadCertifications(coachId: 'other');
    expect(result['certifications'], isEmpty);
    await expectLater(reads.loadSettings(), throwsA(code('permission-denied')));
  });
  test(
      'list uses sorted summary ids, bounded 20, missing rows and cursor parity',
      () async {
    db.documents['$base/certificationState/current'] = {
      'certificationIds': List.generate(22, (i) => id(22 - i)),
      'approvedCount': 2,
      'certificationVerified': true,
    };
    for (var i = 1; i <= 22; i++) {
      if (i != 4) {
        db.documents['$base/certifications/${id(i)}'] = {
          'id': id(i),
          'revision': 1,
          'status': 'pending',
        };
      }
    }
    final result = await reads.loadCertifications();
    final entries = result['certifications'] as List;
    expect(entries.length, 19);
    expect(entries.first['id'], id(1));
    expect(entries.last['id'], id(20));
    expect(entries.every((e) => (e['history'] as List).isEmpty), isTrue);
    expect(result['nextCursor'], id(20));
    expect(result['approvedCount'], 2);
    expect(db.reads.where((p) => p.contains('/certifications/')).length, 20);
    final next = await reads.loadCertifications(afterId: id(20));
    expect(
        (next['certifications'] as List).map((e) => e['id']), [id(21), id(22)]);
    expect(next['nextCursor'], isNull);
  });
  test(
      'selected details read newest 20 history revisions, skipping missing entries',
      () async {
    db.documents['$base/certificationState/current'] = {
      'certificationIds': [id(1)]
    };
    db.documents['$base/certifications/${id(1)}'] = {
      'id': id(1),
      'revision': 25
    };
    for (var i = 1; i <= 25; i++) {
      if (i != 24) {
        db.documents['$base/certifications/${id(1)}/history/$i'] = {
          'revision': i
        };
      }
    }
    final result = await reads.loadCertifications(certificationId: id(1));
    final history =
        (result['certifications'] as List).single['history'] as List;
    expect(history.map((e) => e['revision']),
        [25, ...List.generate(18, (i) => 23 - i)]);
    expect(db.reads.where((p) => p.contains('/history/')).length, 20);
    expect(db.transactions, 1);
  });
  test('selected id outside summary is not found; missing item remains empty',
      () async {
    await expectLater(reads.loadCertifications(certificationId: id(1)),
        throwsA(code('not-found')));
    db.documents['$base/certificationState/current'] = {
      'certificationIds': [id(1)]
    };
    expect(
        (await reads.loadCertifications(
            certificationId: id(1)))['certifications'],
        isEmpty);
  });
  test(
      'invalid paths and selected/cursor combinations fail before database reads',
      () async {
    await expectLater(reads.loadCertifications(coachId: '../coach'),
        throwsA(code('invalid-argument')));
    await expectLater(reads.loadCertifications(afterId: 'bad'),
        throwsA(code('invalid-argument')));
    await expectLater(
        reads.loadCertifications(afterId: id(1), certificationId: id(2)),
        throwsA(code('invalid-argument')));
    expect(db.reads, isEmpty);
  });
  test('corrupt summary and revision fail closed', () async {
    db.documents['$base/certificationState/current'] = {
      'certificationIds': List.filled(101, id(1))
    };
    await expectLater(
        reads.loadCertifications(), throwsA(code('failed-precondition')));
    db.documents['$base/certificationState/current'] = {
      'certificationIds': [id(1)]
    };
    db.documents['$base/certifications/${id(1)}'] = {'revision': 101};
    await expectLater(
        reads.loadCertifications(), throwsA(code('failed-precondition')));
  });
  test('session drift during snapshot discards result', () async {
    db.beforeRead = () async {
      current = false;
    };
    await expectLater(reads.loadSettings(), throwsA(code('unauthenticated')));
  });
  test('security rejection propagates without retry or callable fallback',
      () async {
    db.beforeRead = () async {
      throw const CoachRepositoryException('permission-denied');
    };
    await expectLater(
        reads.loadCertifications(), throwsA(code('permission-denied')));
    expect(db.transactions, 1);
  });
}
