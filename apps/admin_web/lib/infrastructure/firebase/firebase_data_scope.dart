import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

/// Resolves paths before the SDK request. Canonical query shapes are preserved;
/// Rules independently verify every cohort request against its assignment.
extension FirebaseDataScope on FirebaseFirestore {
  DocumentReference<Map<String, dynamic>> scopeRoot(SessionScope scope) =>
      scope.datasetScope == null
          ? collection('orgs').doc(scope.organizationId)
          : doc(scope.dataRootPath);
  DocumentReference<Map<String, dynamic>> scopeUser(SessionScope scope) =>
      scope.datasetScope == null
          ? collection('users').doc(scope.userId)
          : doc(scope.userDocumentPath);
}
