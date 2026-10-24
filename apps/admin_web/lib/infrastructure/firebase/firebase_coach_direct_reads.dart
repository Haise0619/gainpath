import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_data/coach_direct_reads.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';

/// Server-only read transaction: never returns offline cache or falls back to a
/// callable after a security rejection. Rules/App Check remain authoritative.
CoachDirectReads firebaseCoachDirectReads({
  required SessionScope scope,
  required void Function() checkSession,
  FirebaseFirestore? firestore,
  FirebaseAuth? auth,
}) {
  final identity = auth ?? FirebaseAuth.instance;
  void check() {
    checkSession();
    if (identity.currentUser?.uid != scope.userId ||
        identity.currentUser?.emailVerified != true) {
      throw const CoachRepositoryException('unauthenticated');
    }
  }

  return CoachDirectReads(
      scope: scope,
      checkSession: check,
      gateway:
          _FirestoreCoachReads(firestore ?? FirebaseFirestore.instance, check));
}

class _FirestoreCoachReads implements CoachDirectReadGateway {
  _FirestoreCoachReads(this.db, this.check);
  final FirebaseFirestore db;
  final void Function() check;

  @override
  Future<T> transact<T>(Future<T> Function(CoachReadSnapshot) action) async {
    check();
    try {
      // Firestore transactions require a server connection and retry the entire
      // callback on concurrent writes, including all authority documents.
      final result = await db.runTransaction<T>((tx) async {
        check();
        final value = await action(_FirestoreCoachSnapshot(db, tx, check));
        check();
        return value;
      }, timeout: const Duration(seconds: 20), maxAttempts: 3);
      check();
      return result;
    } on FirebaseException catch (error) {
      throw CoachRepositoryException(error.code);
    }
  }
}

class _FirestoreCoachSnapshot implements CoachReadSnapshot {
  _FirestoreCoachSnapshot(this.db, this.transaction, this.check);
  final FirebaseFirestore db;
  final Transaction transaction;
  final void Function() check;
  @override
  Future<Map<String, dynamic>?> get(String path) async {
    check();
    final document = await transaction.get(db.doc(path));
    check();
    return document.data();
  }
}
