import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

class FirebaseAnnouncementReader implements AnnouncementReader {
  FirebaseAnnouncementReader(
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
  late final FirebaseFirestore _db = _injectedDb ?? FirebaseFirestore.instance;
  late final FirebaseAuth _auth = _injectedAuth ?? FirebaseAuth.instance;
  void _check() {
    if (_auth.currentUser?.uid != scope.userId || activeScope() != scope) {
      throw const AnnouncementSessionChanged();
    }
  }

  @override
  Future<AnnouncementPage> loadAnnouncements({String? afterId}) async {
    _check();
    Query<Map<String, dynamic>> query = _db
        .collection('orgs')
        .doc(scope.organizationId)
        .collection('announcements')
        .where('status', isEqualTo: 'published')
        .orderBy(FieldPath.documentId);
    if (afterId != null) query = query.startAfter([afterId]);
    final page = await query
        .limit(21)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    _check();
    final items = page.docs.take(20).map((doc) {
      final d = doc.data();
      if (d['schemaVersion'] != 1 ||
          d['status'] != 'published' ||
          d['revision'] is! int ||
          d['revision'] < 1 ||
          d['validFrom'] is! Timestamp ||
          d['validTo'] is! Timestamp) {
        throw const FormatException('Announcement data is unavailable.');
      }
      final result = Announcement(
          id: doc.id,
          title: d['title'] as String,
          body: d['body'] as String,
          validFrom: (d['validFrom'] as Timestamp).toDate(),
          validTo: (d['validTo'] as Timestamp).toDate(),
          revision: d['revision'] as int);
      result.validate();
      return result;
    }).toList();
    return AnnouncementPage(items,
        nextCursor: page.docs.length > 20 ? items.last.id : null);
  }
}
