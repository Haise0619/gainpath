import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'firebase_equipment_image_store.dart';
import 'firebase_equipment_video_store.dart';

class FirebaseEquipmentRepository extends EquipmentRepository {
  FirebaseEquipmentRepository(
      {required this.scope,
      required this.isCurrent,
      FirebaseFirestore? firestore,
      FirebaseAuth? auth,
      EquipmentImageStore? imageStore,
      EquipmentVideoStore? videoStore})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _imageStore = imageStore ?? FirebaseEquipmentImageStore(scope: scope),
        _videoStore = videoStore ?? FirebaseEquipmentVideoStore(scope: scope);
  final SessionScope scope;
  final bool Function() isCurrent;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final EquipmentImageStore _imageStore;
  final EquipmentVideoStore _videoStore;
  final Object _lifetime = Object();
  bool _invalidated = false;
  @override
  bool get isLive => true;
  @override
  List<GymEquipment> get gymEquipment => const [];
  CollectionReference<Map<String, dynamic>> get _records => _db
      .collection('orgs')
      .doc(scope.organizationId)
      .collection('gymEquipment');
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
      throw const EquipmentSessionChanged();
    }
  }

  void _author(Map<String, dynamic>? user, Map<String, dynamic>? member) {
    _check();
    if (user?['organizationId'] != scope.organizationId ||
        member?['organizationId'] != scope.organizationId ||
        member?['status'] != 'active' ||
        !['admin', 'staff'].contains(member?['role'])) {
      _invalidated = true;
      throw const EquipmentSessionChanged();
    }
  }

  @override
  Future<EquipmentPage> loadEquipment({String? afterId}) async {
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
    return EquipmentPage(items,
        nextCursor: page.docs.length > 50 ? items.last.id : null);
  }

  @override
  Future<GymEquipment> saveEquipment(GymEquipment equipment,
      {EquipmentImage? image,
      EquipmentVideo? video,
      void Function(double)? onVideoProgress}) async {
    equipment.validate();
    _check();
    final original = equipment.editBaseline;
    final create = equipment.id.isEmpty;
    if (!create &&
        (original is! _Baseline ||
            !identical(original.lifetime, _lifetime) ||
            original.id != equipment.id)) {
      throw const EquipmentConflict();
    }
    final baseline = original is _Baseline ? original : null;
    final ref = create ? _records.doc() : _records.doc(equipment.id);
    var imageUrl = equipment.imageUrl.trim();
    var tutorialVideoUrl = equipment.tutorialVideoUrl;
    if (image != null || video != null) {
      final user =
          (await _user.get(const GetOptions(source: Source.server))).data();
      final member =
          (await _member.get(const GetOptions(source: Source.server))).data();
      _author(user, member);
      if (baseline != null) {
        if (!_same(user, baseline.user) || !_same(member, baseline.member)) {
          throw const EquipmentSessionChanged();
        }
        final document =
            (await ref.get(const GetOptions(source: Source.server))).data();
        if (!_same(document, baseline.document)) {
          throw const EquipmentConflict();
        }
      }
      _check();
      if (image != null) imageUrl = await _imageStore.upload(image);
      _check();
      if (video != null) {
        tutorialVideoUrl =
            await _videoStore.upload(video, onProgress: onVideoProgress);
      }
      _check();
    }
    final fields = <String, dynamic>{
      'name': equipment.name.trim(),
      'category': equipment.category.trim(),
      'muscleGroup': equipment.muscleGroup.trim(),
      'description': equipment.description.trim(),
      'imageUrl': imageUrl,
      if (tutorialVideoUrl.isNotEmpty ||
          baseline?.document.containsKey('tutorialVideoUrl') == true)
        'tutorialVideoUrl': tutorialVideoUrl,
      'isActive': equipment.isActive,
      'howToUse':
          equipment.howToUse.map((s) => s.trim()).toList(growable: false),
      'safetyTips':
          equipment.safetyTips.map((s) => s.trim()).toList(growable: false),
    };
    Object? failure;
    Map<String, dynamic>? savedUser, savedMember;
    try {
      await _db.runTransaction<void>((tx) async {
        if (failure != null) throw StateError('Equipment save aborted.');
        try {
          _check();
          final user = (await tx.get(_user)).data();
          final member = (await tx.get(_member)).data();
          _author(user, member);
          if (baseline != null &&
              (!_same(user, baseline.user) ||
                  !_same(member, baseline.member))) {
            throw const EquipmentSessionChanged();
          }
          final current = (await tx.get(ref)).data();
          if (create
              ? current != null
              : current == null || !_same(current, baseline!.document)) {
            throw const EquipmentConflict();
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
          if (create) {
            tx.set(ref, {
              ...patch,
              'schemaVersion': 1,
              'createdAt': FieldValue.serverTimestamp(),
              'createdBy': scope.userId,
            });
          } else {
            tx.update(ref, patch);
          }
        } on EquipmentConflict catch (e) {
          failure = e;
          throw StateError('Equipment save aborted.');
        } on EquipmentSessionChanged catch (e) {
          failure = e;
          throw StateError('Equipment save aborted.');
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
    if (saved == null) throw StateError('Equipment save was not verified.');
    return _decode(ref.id, saved,
        _Baseline(_lifetime, ref.id, saved, savedUser!, savedMember!));
  }

  GymEquipment _decode(String id, Map<String, dynamic> d, _Baseline baseline) {
    if (d['createdAt'] is! Timestamp || d['updatedAt'] is! Timestamp) {
      throw const FormatException('Equipment data is unavailable.');
    }
    return GymEquipment.fromDocument(id, d, baseline: baseline);
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

class _Baseline extends EquipmentEditBaseline {
  _Baseline(this.lifetime, this.id, Map<String, dynamic> d,
      Map<String, dynamic> u, Map<String, dynamic> m)
      : document = _freeze(d) as Map,
        user = _freeze(u) as Map,
        member = _freeze(m) as Map;
  final Object lifetime;
  final String id;
  final Map document, user, member;
}
