import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

class FirebaseEquipmentReader implements EquipmentReader {
  FirebaseEquipmentReader(
      {required this.scope,
      required this.activeScope,
      FirebaseFirestore? firestore,
      FirebaseAuth? auth})
      : _injectedDb = firestore,
        _injectedAuth = auth;
  final SessionScope scope;
  final SessionScope? Function() activeScope;
  final FirebaseFirestore? _injectedDb;
  final FirebaseAuth? _injectedAuth;
  late final _db = _injectedDb ?? FirebaseFirestore.instance;
  late final _auth = _injectedAuth ?? FirebaseAuth.instance;
  void _check() {
    if (_auth.currentUser?.uid != scope.userId || activeScope() != scope) {
      throw const EquipmentSessionChanged();
    }
  }

  @override
  Future<EquipmentPage> loadEquipment({String? afterId}) async {
    _check();
    Query<Map<String, dynamic>> query = _db
        .collection('orgs')
        .doc(scope.organizationId)
        .collection('gymEquipment')
        .where('isActive', isEqualTo: true)
        .orderBy(FieldPath.documentId);
    if (afterId != null) query = query.startAfter([afterId]);
    final page = await query
        .limit(21)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    _check();
    final items = page.docs
        .take(20)
        .map((d) => GymEquipment.fromDocument(d.id, d.data()))
        .toList();
    if (items.any((e) => !e.isActive)) {
      throw const FormatException('Inactive equipment is unavailable.');
    }
    return EquipmentPage(items,
        nextCursor: page.docs.length > 20 ? items.last.id : null);
  }
}
