import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

class FirebaseAnnouncementRepository extends ContentRepository {
  FirebaseAnnouncementRepository(
      {required this.scope,
      required this.isCurrent,
      FirebaseFirestore? firestore,
      FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;
  final SessionScope scope;
  final bool Function() isCurrent;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final Object _lifetime = Object();
  bool _invalidated = false;
  @override
  bool get isLive => true;
  @override
  List<Announcement> get announcements => const [];
  CollectionReference<Map<String, dynamic>> get _records => _db
      .collection('orgs')
      .doc(scope.organizationId)
      .collection('announcements');
  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(scope.userId);
  DocumentReference<Map<String, dynamic>> get _member => _db
      .collection('orgs')
      .doc(scope.organizationId)
      .collection('members')
      .doc(scope.userId);
  void _check() {
    if (_invalidated ||
        !isCurrent() ||
        _auth.currentUser?.uid != scope.userId) {
      _invalidated = true;
      throw const AnnouncementSessionChanged();
    }
  }

  void _author(Map<String, dynamic>? user, Map<String, dynamic>? member) {
    _check();
    if (user?['organizationId'] != scope.organizationId ||
        member?['organizationId'] != scope.organizationId ||
        member?['status'] != 'active' ||
        !['admin', 'staff'].contains(member?['role'])) {
      _invalidated = true;
      throw const AnnouncementSessionChanged();
    }
  }

  @override
  Future<AnnouncementPage> loadAnnouncements({String? afterId}) async {
    _check();
    final user =
        (await _user.get(const GetOptions(source: Source.server))).data();
    final member =
        (await _member.get(const GetOptions(source: Source.server))).data();
    _author(user, member);
    Query<Map<String, dynamic>> query = _records.orderBy(FieldPath.documentId);
    if (afterId != null) query = query.startAfter([afterId]);
    final page =
        await query.limit(51).get(const GetOptions(source: Source.server));
    _check();
    final items = page.docs
        .take(50)
        .map((d) => _decode(d.id, d.data(),
            _Baseline(_lifetime, d.id, d.data(), user!, member!)))
        .toList();
    return AnnouncementPage(items,
        nextCursor: page.docs.length > 50 ? items.last.id : null);
  }

  @override
  Future<Announcement> saveAnnouncement(Announcement entry) async {
    entry.validate();
    _check();
    final original = entry.editBaseline;
    final create = entry.id.isEmpty;
    if (!create &&
        (original is! _Baseline ||
            !identical(original.lifetime, _lifetime) ||
            original.id != entry.id)) {
      throw const AnnouncementConflict();
    }
    final baseline = original is _Baseline ? original : null;
    final ref = create ? _records.doc() : _records.doc(entry.id);
    final fields = <String, dynamic>{
      'title': entry.title.trim(),
      'body': entry.body.trim(),
      'validFrom': Timestamp.fromDate(entry.validFrom),
      'validTo': Timestamp.fromDate(entry.validTo),
      'status': entry.status.name
    };
    Object? failure;
    Map<String, dynamic>? savedUser, savedMember;
    try {
      await _db.runTransaction<void>((tx) async {
        if (failure != null) throw StateError('Announcement save aborted.');
        try {
          _check();
          final user = (await tx.get(_user)).data();
          final member = (await tx.get(_member)).data();
          _author(user, member);
          if (baseline != null &&
              (!_same(user, baseline.user) ||
                  !_same(member, baseline.member))) {
            throw const AnnouncementSessionChanged();
          }
          final current = (await tx.get(ref)).data();
          if (create
              ? current != null
              : current == null || !_same(current, baseline!.document)) {
            throw const AnnouncementConflict();
          }
          _check();
          savedUser = user;
          savedMember = member;
          final patch = <String, dynamic>{
            for (final f in fields.entries)
              if (create || !_same(f.value, baseline!.document[f.key]))
                f.key: f.value
          };
          if (!create && patch.isEmpty) return;
          patch.addAll({
            'revision':
                create ? 1 : (baseline!.document['revision'] as int) + 1,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': scope.userId
          });
          if (entry.status == AnnouncementStatus.published &&
              (create || baseline!.document['status'] != 'published')) {
            patch['publishedAt'] = FieldValue.serverTimestamp();
          }
          if (create) {
            tx.set(ref, {
              ...patch,
              'schemaVersion': 1,
              'createdAt': FieldValue.serverTimestamp(),
              'createdBy': scope.userId,
              if (!patch.containsKey('publishedAt')) 'publishedAt': null
            });
          } else {
            tx.update(ref, patch);
          }
        } on AnnouncementConflict catch (e) {
          failure = e;
          throw StateError('Announcement save aborted.');
        } on AnnouncementSessionChanged catch (e) {
          failure = e;
          throw StateError('Announcement save aborted.');
        }
      });
    } catch (_) {
      if (failure != null) throw failure!;
      rethrow;
    }
    _check();
    final saved =
        (await ref.get(const GetOptions(source: Source.server))).data();
    _check();
    if (saved == null) throw StateError('Announcement save was not verified.');
    return _decode(ref.id, saved,
        _Baseline(_lifetime, ref.id, saved, savedUser!, savedMember!));
  }

  Announcement _decode(String id, Map<String, dynamic> d, _Baseline baseline) {
    if (d['schemaVersion'] != 1 ||
        d['revision'] is! int ||
        d['revision'] < 1 ||
        d['validFrom'] is! Timestamp ||
        d['validTo'] is! Timestamp ||
        !AnnouncementStatus.values.any((s) => s.name == d['status'])) {
      throw const FormatException('Announcement data is unavailable.');
    }
    final entry = Announcement(
        id: id,
        title: d['title'] as String,
        body: d['body'] as String,
        validFrom: (d['validFrom'] as Timestamp).toDate(),
        validTo: (d['validTo'] as Timestamp).toDate(),
        status: AnnouncementStatus.values.byName(d['status'] as String),
        revision: d['revision'] as int,
        editBaseline: baseline);
    entry.validate();
    return entry;
  }
}

Object? _freeze(Object? v) => v is Map
    ? Map.unmodifiable(v.map((k, e) => MapEntry(k, _freeze(e))))
    : v is List
        ? List.unmodifiable(v.map(_freeze))
        : v;
bool _same(Object? a, Object? b) => a is Map && b is Map
    ? a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && _same(a[k], b[k]))
    : a is List && b is List
        ? a.length == b.length &&
            List.generate(a.length, (i) => i).every((i) => _same(a[i], b[i]))
        : a == b;

class _Baseline extends AnnouncementEditBaseline {
  _Baseline(this.lifetime, this.id, Map<String, dynamic> d,
      Map<String, dynamic> u, Map<String, dynamic> m)
      : document = _freeze(d) as Map,
        user = _freeze(u) as Map,
        member = _freeze(m) as Map;
  final Object lifetime;
  final String id;
  final Map document, user, member;
}
