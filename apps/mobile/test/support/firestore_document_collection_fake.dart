// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Provides explicit collection/document paths for SDK boundary tests.
class FirestoreDocumentCollectionFake extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  FirestoreDocumentCollectionFake(this.path, this._document);

  @override
  final String path;
  final DocumentReference<Map<String, dynamic>> Function(String) _document;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    if (path == null) throw UnimplementedError('Generated document ID');
    return _document('${this.path}/$path');
  }
}
