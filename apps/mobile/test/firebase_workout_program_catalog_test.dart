import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/infrastructure/firebase/firebase_workout_program_catalog.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_app_check_readiness.dart';
import 'workout_program_controller_test.dart' show programFixture;

void main() {
  test('App Check readiness failure blocks calls and later Retry can recover',
      () async {
    final scope = SessionScope(userId: 'member', organizationId: 'gym');
    var activation = 0, calls = 0;
    final readiness = FirebaseAppCheckReadiness(
        mode: 'debug',
        release: false,
        supported: true,
        activate: (_) async {
          if (++activation == 1) throw StateError('temporary');
        },
        token: () async => 'verified-token');
    final catalog = FirebaseWorkoutProgramCatalog(
        scope: scope,
        activeScope: () => scope,
        activeAccount: () => true,
        readiness: readiness,
        invoke: (_) async {
          calls++;
          return {
            'programs': [programFixture().toJson()]
          };
        });
    await expectLater(catalog.load(), throwsStateError);
    expect(calls, 0);
    expect((await catalog.load()).single.version, 1);
    expect(calls, 1);
    expect(activation, 2);
  });
  test(
      'catalog loads only validated published versions using scoped list command',
      () async {
    final scope = SessionScope(userId: 'member', organizationId: 'gym');
    final catalog = FirebaseWorkoutProgramCatalog(
        scope: scope,
        activeScope: () => scope,
        activeAccount: () => true,
        invoke: (payload) async {
          expect(payload,
              {'schemaVersion': 2, 'organizationId': 'gym', 'action': 'list'});
          return {
            'programs': [programFixture().toJson()]
          };
        });
    expect((await catalog.load()).single.version, 1);
  });
  test('catalog rejects session changes after delayed response', () async {
    final scope = SessionScope(userId: 'member', organizationId: 'gym');
    var current = true;
    final catalog = FirebaseWorkoutProgramCatalog(
        scope: scope,
        activeScope: () => current ? scope : null,
        activeAccount: () => current,
        invoke: (_) async {
          current = false;
          return {
            'programs': [programFixture().toJson()]
          };
        });
    await expectLater(catalog.load(), throwsStateError);
  });
  test('old server explicitly rejecting v2 is retried with v1 once', () async {
    final scope = SessionScope(userId: 'member', organizationId: 'gym');
    final versions = <Object?>[];
    final catalog = FirebaseWorkoutProgramCatalog(
        scope: scope,
        activeScope: () => scope,
        activeAccount: () => true,
        invoke: (payload) async {
          versions.add(payload['schemaVersion']);
          if (payload['schemaVersion'] == 2) {
            throw FirebaseFunctionsException(
                code: 'invalid-argument',
                message: 'Unsupported schema version');
          }
          return {
            'programs': [programFixture().toJson()]
          };
        });
    expect((await catalog.load()).single.version, 1);
    expect(versions, [2, 1]);
  });
  test('authorization and malformed v2 responses never trigger downgrade',
      () async {
    final scope = SessionScope(userId: 'member', organizationId: 'gym');
    var calls = 0;
    final catalog = FirebaseWorkoutProgramCatalog(
        scope: scope,
        activeScope: () => scope,
        activeAccount: () => true,
        invoke: (_) async {
          calls++;
          throw FirebaseFunctionsException(
              code: 'permission-denied', message: 'schema forbidden');
        });
    await expectLater(
        catalog.load(), throwsA(isA<FirebaseFunctionsException>()));
    expect(calls, 1);
    final malformed = FirebaseWorkoutProgramCatalog(
        scope: scope,
        activeScope: () => scope,
        activeAccount: () => true,
        invoke: (_) async {
          calls++;
          return {
            'programs': [
              {'schemaVersion': 2}
            ]
          };
        });
    await expectLater(malformed.load(), throwsFormatException);
    expect(calls, 2);
  });
}
