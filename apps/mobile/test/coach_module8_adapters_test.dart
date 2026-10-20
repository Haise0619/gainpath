import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_coach_account_repository.dart';
import 'package:gainpath_mobile/infrastructure/local/mock_coach_module8_repository.dart';

class ScriptedFirebaseAccount extends FirebaseCoachAccountRepository {
  ScriptedFirebaseAccount()
      : super(
            scope: SessionScope(userId: 'coach', organizationId: 'o'),
            isCurrent: () => true);
  final calls = <String>[];
  Map<String, dynamic> response = {};
  @override
  Future<Map<String, dynamic>> command(String name,
      [Map<String, dynamic> values = const {}]) async {
    calls.add(name);
    return response;
  }
}

void main() {
  test(
      'Firebase maps certification RPC into neutral summary and detail without sample metrics',
      () async {
    final source = ScriptedFirebaseAccount();
    expect(source.publicAvatarUrl, isNull);
    expect(source.metrics.rating, isNull);
    expect(source.metrics.sessions, isNull);
    source.response = {
      'schemaVersion': 1,
      'approvedCount': 1,
      'certificationVerified': true,
      'certifications': [
        {'status': 'pending'}
      ],
      'nextCursor': null
    };
    final summary = await source.loadCertificationSummary();
    expect(summary.approved, 1);
    expect(summary.pending, 1);
    expect(summary.verified, true);
    source.response['nextCursor'] = 'next';
    expect((await source.loadCertificationSummary()).pending, isNull);
    final id = 'a' * 32;
    source.response = {
      'schemaVersion': 1,
      'certifications': [
        {
          'id': id,
          'title': 'Fixture',
          'issuer': 'Fixture',
          'storagePath': 'private',
          'status': 'approved',
          'revision': 2,
          'createdAtMillis': 1,
          'updatedAtMillis': 2,
          'history': [
            {'status': 'pending', 'revision': 1},
            {'status': 'approved', 'revision': 2}
          ]
        }
      ]
    };
    final detail = await source.loadCertificationDetail(id);
    expect(detail.certification.status, 'approved');
    expect(detail.history, hasLength(2));
    expect(
        source.calls.every((c) => c == 'getCoachCertificationsCommand'), true);
    await expectLater(
        source.loadCertificationDetail('b' * 32), throwsFormatException);
  });
  test(
      'Mock retains the same settings/profile save and readback contracts across screen navigation',
      () async {
    var active = true;
    final source = MockCoachModule8Repository(
        legacy: InMemoryCoachRepository(),
        scope: SessionScope(userId: 'coach', organizationId: 'mock'),
        isCurrent: () => active);
    final old = await source.loadSettings();
    final saved = await source.saveSettings(
        old, '+60123456789', false, true, true, 'settings');
    expect((await source.loadSettings()).contactPhone, saved.contactPhone);
    expect((await source.loadSettings()).newBookings, false);
    final profile = (await source.loadOwn())!;
    final fields = CoachProfessionalFields.fromJson({
      ...profile.fields.toJson(),
      'bio': 'Edited draft',
      'consultationFeeMinor': 12300
    });
    await source.save(
        expectedRevision: profile.revision,
        patch: CoachProfilePatch.between(profile.fields, fields),
        requestId: 'profile');
    expect((await source.loadOwn())!.fields.bio, 'Edited draft');
    expect((await source.loadOwn())!.fields.consultationFeeMinor, 12300);
    expect(source.passwordManagementAvailable, false);
    active = false;
    await expectLater(
        source.loadSettings(), throwsA(isA<CoachRepositoryException>()));
  });
  test(
      'Mock document uploads remain local immutable evidence with retained archive history',
      () async {
    final source = MockCoachModule8Repository(
        legacy: InMemoryCoachRepository(),
        scope: SessionScope(userId: 'coach', organizationId: 'mock'),
        isCurrent: () => true);
    final id = 'f' * 32,
        bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0]);
    final path =
        await source.upload('coachCertifications', id, bytes, 'image/png');
    await source.submitCertification(
        id, 'Local fixture', 'Fixture', path, 'submit');
    final cert = (await source.loadCertificationDetail(id)).certification;
    expect(cert.status, 'pending');
    expect(await source.read(path), orderedEquals(bytes));
    await source.archive(cert, 'archive');
    final detail = await source.loadCertificationDetail(id);
    expect(detail.certification.status, 'archived');
    expect(detail.history, hasLength(2));
    expect(await source.read(path), orderedEquals(bytes));
  });
}
