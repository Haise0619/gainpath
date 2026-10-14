import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/exercise_catalog_store.dart';
import 'package:gainpath_domain/workout.dart';

class _Transaction implements ExerciseCatalogTransaction {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  for (final code in ['permission-denied', 'unauthenticated']) {
    test('restores safe authorization failure when web wraps Firebase $code',
        () async {
      await expectLater(
          runCatalogTransactionPreservingFailures((action) async {
            try {
              await action(_Transaction());
            } catch (_) {
              throw StateError('JS bridge wrapped callback exception');
            }
          },
              (_) async => throw FirebaseException(
                  plugin: 'cloud_firestore', code: code)),
          throwsA(isA<TutorialEditAuthorizationChanged>()));
    });
  }
  for (final failure in [
    const TutorialEditConflict(),
    const TutorialEditAuthorizationChanged()
  ]) {
    test(
        'restores domain failure after web bridge wraps callback: ${failure.runtimeType}',
        () async {
      await expectLater(
          runCatalogTransactionPreservingFailures((action) async {
            try {
              await action(_Transaction());
            } catch (_) {
              throw StateError('JS bridge wrapped callback exception');
            }
          }, (_) async => throw failure),
          throwsA(same(failure)));
    });
  }
  test('successful transaction does not introduce failure', () async {
    var calls = 0;
    await runCatalogTransactionPreservingFailures(
        (action) => action(_Transaction()), (_) async {
      calls++;
    });
    expect(calls, 1);
  });
}
