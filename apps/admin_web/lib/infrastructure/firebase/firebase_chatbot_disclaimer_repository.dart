import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

class FirebaseChatbotDisclaimerRepository extends ChatbotDisclaimerRepository {
  FirebaseChatbotDisclaimerRepository(
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
  DocumentReference<Map<String, dynamic>> get _config => _db
      .collection('orgs')
      .doc(scope.organizationId)
      .collection('chatbotDisclaimer')
      .doc('config');
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
      throw const ChatbotDisclaimerSessionChanged();
    }
  }

  void _author(Map<String, dynamic>? user, Map<String, dynamic>? member) {
    _check();
    if (user?['organizationId'] != scope.organizationId ||
        member?['organizationId'] != scope.organizationId ||
        member?['status'] != 'active' ||
        !['admin', 'staff'].contains(member?['role']) ||
        _auth.currentUser?.emailVerified != true) {
      _invalidated = true;
      throw const ChatbotDisclaimerSessionChanged();
    }
  }

  @override
  Future<ChatbotDisclaimerSnapshot> load() async {
    _check();
    final user =
        (await _user.get(const GetOptions(source: Source.server))).data();
    final member =
        (await _member.get(const GetOptions(source: Source.server))).data();
    _author(user, member);
    final data =
        (await _config.get(const GetOptions(source: Source.server))).data();
    final versions = await _config
        .collection('versions')
        .orderBy('revision', descending: true)
        .limit(20)
        .get(const GetOptions(source: Source.server));
    _check();
    return ChatbotDisclaimerSnapshot(
        current: data == null ? null : _decode(data),
        history: List.unmodifiable(versions.docs.map((d) => _decode(d.data()))),
        editBaseline: _Baseline(_lifetime, data, user!, member!));
  }

  @override
  Future<ChatbotDisclaimerSnapshot> save(ChatbotDisclaimerSnapshot original,
      {required String text, required bool isActive}) async {
    text = text.trim();
    if (text.isEmpty || text.runes.length > 4000) {
      throw const FormatException(
          'Enter disclaimer text of 1–4000 characters.');
    }
    _check();
    final baseline = original.editBaseline;
    if (baseline is! _Baseline || !identical(baseline.lifetime, _lifetime)) {
      throw const ChatbotDisclaimerConflict();
    }
    final previous = baseline.document;
    if (previous == null && isActive) {
      throw const FormatException('Save an inactive version first.');
    }
    final revision = previous == null ? 1 : (previous['revision'] as int) + 1;
    Object? failure;
    await (() async {
      try {
        await _db.runTransaction<void>((tx) async {
          if (failure != null) throw StateError('Disclaimer save aborted.');
          try {
            _check();
            final user = (await tx.get(_user)).data();
            final member = (await tx.get(_member)).data();
            _author(user, member);
            if (!_same(user, baseline.user) ||
                !_same(member, baseline.member)) {
              throw const ChatbotDisclaimerSessionChanged();
            }
            final current = (await tx.get(_config)).data();
            if (!_same(current, previous)) {
              throw const ChatbotDisclaimerConflict();
            }
            _check();
            final data = <String, dynamic>{
              'schemaVersion': 1,
              'text': text,
              'isActive': isActive,
              'revision': revision,
              'createdAt':
                  previous?['createdAt'] ?? FieldValue.serverTimestamp(),
              'createdBy': previous?['createdBy'] ?? scope.userId,
              'updatedAt': FieldValue.serverTimestamp(),
              'updatedBy': scope.userId,
            };
            tx.set(_config, data);
            tx.set(_config.collection('versions').doc('$revision'), data);
          } on ChatbotDisclaimerConflict catch (e) {
            failure = e;
            throw StateError('Disclaimer save aborted.');
          } on ChatbotDisclaimerSessionChanged catch (e) {
            _invalidated = true;
            failure = e;
            throw StateError('Disclaimer save aborted.');
          }
        });
      } catch (_) {
        if (failure != null) throw failure!;
        rethrow;
      }
    })();
    final saved = await load();
    if (saved.current?.revision != revision ||
        saved.current?.text != text ||
        saved.current?.isActive != isActive) {
      throw const ChatbotDisclaimerConflict();
    }
    return saved;
  }

  ChatbotDisclaimer _decode(Map<String, dynamic> d) {
    if (d['schemaVersion'] != 1 ||
        d['text'] is! String ||
        (d['text'] as String).trim().isEmpty ||
        (d['text'] as String).runes.length > 4000 ||
        d['isActive'] is! bool ||
        d['revision'] is! int ||
        d['revision'] < 1 ||
        d['updatedAt'] is! Timestamp) {
      throw const FormatException('Disclaimer data is unavailable.');
    }
    return ChatbotDisclaimer(
        text: d['text'] as String,
        isActive: d['isActive'] as bool,
        revision: d['revision'] as int,
        updatedAt: (d['updatedAt'] as Timestamp).toDate());
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

class _Baseline extends ChatbotDisclaimerEditBaseline {
  _Baseline(this.lifetime, Map<String, dynamic>? d, Map<String, dynamic> u,
      Map<String, dynamic> m)
      : document = _freeze(d) as Map?,
        user = _freeze(u) as Map,
        member = _freeze(m) as Map;
  final Object lifetime;
  final Map? document;
  final Map user, member;
}
