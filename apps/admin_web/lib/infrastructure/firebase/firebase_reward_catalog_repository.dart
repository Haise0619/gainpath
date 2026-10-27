import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/workout.dart' show EquipmentImage;
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'firebase_function_transport.dart';
import 'firebase_reward_media_store.dart';

class FirebaseRewardCatalogRepository
    implements
        RewardCatalogRepository,
        RewardManagementRepository,
        RewardMediaRepository,
        WorkoutRewardConfigurationRepository {
  FirebaseRewardCatalogRepository(
      {required this.scope,
      required this.isCurrent,
      FirebaseFirestore? firestore,
      FirebaseAuth? auth,
      Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
          catalogCall})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _catalogCall = catalogCall ??
            ((name, input) async => (await firebaseRewardCallable(name)
                    .call<Map<String, dynamic>>(input))
                .data);
  final SessionScope scope;
  final bool Function() isCurrent;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  @override
  Future<WorkoutRewardDraft> loadWorkoutRewardDraft() async {
    final response = await _command('workoutRewardOverview', {});
    if (response['hold'] != true || response['draft'] is! Map) {
      throw const FormatException('Workout reward draft unavailable.');
    }
    return WorkoutRewardDraft.fromJson(
        Map<String, dynamic>.from(response['draft'] as Map));
  }

  @override
  Future<void> saveWorkoutRewardDraft(
      {required String requestId,
      required int baseRevision,
      required WorkoutRewardDraft draft}) async {
    final response = await _command('saveWorkoutRewardDraft', {
      'requestId': requestId,
      'baseRevision': baseRevision,
      ...draft.toFields()
    });
    if (response['confirmed'] != true) {
      throw const FormatException('Workout reward draft save not confirmed.');
    }
  }

  late final _mediaStore = FirebaseRewardMediaStore(
      scope: scope,
      isCurrent: isCurrent,
      upload: (path, bytes, type) async {
        final response = await _command('uploadCover', {
          'uploadId': path.split('/').last,
          'contentType': type,
          'dataBase64': base64Encode(bytes)
        });
        final url = response['url'];
        if (url is! String) throw const RewardMediaUploadFailed();
        return url;
      });
  @override
  Future<String> uploadRewardCover(EquipmentImage image) async {
    _check();
    final url = await _mediaStore.upload(image);
    _check();
    return url;
  }

  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
      _catalogCall;
  @override
  bool get current {
    try {
      _check();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  String newItemId() {
    _check();
    return _records.doc().id;
  }

  @override
  Future<void> saveReward(
      {required String requestId,
      required String itemId,
      required int baseItemRevision,
      required String title,
      required String description,
      required String category,
      required String imageUrl,
      required int pointCost,
      required int stockToAdd,
      required int validityDays,
      required String conditions,
      required String collectionInstructions}) async {
    _check();
    _id(itemId);
    RewardCatalogDraft(
            id: itemId,
            title: title,
            description: description,
            category: category,
            imageUrl: imageUrl)
        .validate();
    await _command('savePoints', {
      'requestId': requestId,
      'itemId': itemId,
      'baseItemRevision': baseItemRevision,
      'title': title.trim(),
      'description': description.trim(),
      'category': category,
      'imageUrl': imageUrl.trim(),
      'pointCost': pointCost,
      'stockToAdd': stockToAdd,
      'validityDays': validityDays,
      'conditions': conditions.trim(),
      'collectionInstructions': collectionInstructions.trim()
    });
  }

  Future<Map<String, dynamic>> _command(
      String action, Map<String, dynamic> fields) async {
    _check();
    final response = await _catalogCall('rewardCatalogCommand', {
      'schemaVersion': 1,
      'organizationId': scope.organizationId,
      'action': action,
      ...fields,
    }).timeout(const Duration(seconds: 30));
    _check();
    if (response['schemaVersion'] != 1 ||
        response['organizationId'] != scope.organizationId) {
      throw const FormatException('Invalid reward publication response.');
    }
    return response;
  }

  @override
  Future<RewardShopAdministration> shopOverview() async {
    final response = await _command('pointsOverview', {});
    if (response['items'] is! List) {
      throw const FormatException('Invalid reward shop response.');
    }
    int number(Map d, String key, [int minimum = 0]) {
      final value = d[key];
      if (value is! int || value < minimum) {
        throw const FormatException('Invalid reward shop number.');
      }
      return value;
    }

    String string(Map d, String key) {
      final value = d[key];
      if (value is! String) {
        throw const FormatException('Invalid reward shop details.');
      }
      return value;
    }

    bool boolean(Map d, String key) {
      final value = d[key];
      if (value is! bool) {
        throw const FormatException('Invalid reward shop state.');
      }
      return value;
    }

    return RewardShopAdministration(
        items: (response['items'] as List).map((raw) {
      if (raw is! Map) {
        throw const FormatException('Invalid published reward.');
      }
      return PublishedReward(
          category:
              raw['category'] == null ? 'Merchandise' : string(raw, 'category'),
          itemId: string(raw, 'itemId'),
          title: string(raw, 'title'),
          pointCost: number(raw, 'pointCost', 1),
          stock: number(raw, 'stock'),
          revision: number(raw, 'revision', 1),
          active: boolean(raw, 'active'),
          validityDays: number(raw, 'validityDays', 1),
          conditions: string(raw, 'conditions'),
          collectionInstructions: string(raw, 'collectionInstructions'),
          imageUrl: string(raw, 'imageUrl'),
          description: string(raw, 'description'));
    }).toList());
  }

  @override
  Future<void> configureShop(
      {required String requestId,
      required int pointsPerUnit,
      required int unitValueMinor,
      required bool enabled}) async {
    await _command('configure', {
      'requestId': requestId,
      'pointsPerUnit': pointsPerUnit,
      'unitValueMinor': unitValueMinor,
      'enabled': enabled
    });
  }

  @override
  Future<void> publishReward(
      {required RewardCatalogDraft draft,
      required String requestId,
      required int pointCost,
      required int valueMinor,
      required int stockToAdd,
      required int validityDays,
      required String conditions,
      required String collectionInstructions,
      int baseItemRevision = 0}) async {
    draft.validate();
    final baseline = draft.editBaseline;
    if (draft.revision < 1 ||
        draft.isArchived ||
        baseline is! _Baseline ||
        !identical(baseline.lifetime, _lifetime) ||
        baseline.id != draft.id ||
        baseline.document?['revision'] != draft.revision) {
      throw const RewardCatalogConflict();
    }
    await _command('publish', {
      'requestId': requestId,
      'itemId': draft.id,
      'draftRevision': draft.revision,
      'baseItemRevision': baseItemRevision,
      'pointCost': pointCost,
      'valueMinor': valueMinor,
      'stockToAdd': stockToAdd,
      'validityDays': validityDays,
      'conditions': conditions.trim(),
      'collectionInstructions': collectionInstructions.trim()
    });
  }

  @override
  Future<void> retireReward(
      {required String itemId,
      required String requestId,
      required int baseItemRevision}) async {
    await _command('retirePoints', {
      'requestId': requestId,
      'itemId': itemId,
      'baseItemRevision': baseItemRevision
    });
  }

  final Object _lifetime = Object();
  bool _invalidated = false;
  CollectionReference<Map<String, dynamic>> get _records => _db
      .collection('orgs')
      .doc(scope.organizationId)
      .collection('rewardCatalog');
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
        _auth.currentUser?.uid != scope.userId ||
        _auth.currentUser?.emailVerified != true) {
      _invalidated = true;
      throw const RewardCatalogSessionChanged();
    }
  }

  void _author(Map<String, dynamic>? user, Map<String, dynamic>? member) {
    _check();
    if (user?['organizationId'] != scope.organizationId ||
        member?['organizationId'] != scope.organizationId ||
        member?['role'] != 'admin' ||
        member?['status'] != 'active') {
      _invalidated = true;
      throw const RewardCatalogSessionChanged();
    }
  }

  Future<(Map<String, dynamic>, Map<String, dynamic>)> _readAuthor() async {
    _check();
    final user =
        (await _user.get(const GetOptions(source: Source.server))).data();
    final member =
        (await _member.get(const GetOptions(source: Source.server))).data();
    _author(user, member);
    return (user!, member!);
  }

  @override
  RewardCatalogDraft beginCreate() {
    _check();
    final id = _records.doc().id;
    // One allocated ID per editor, including retries after an uncertain response.
    return RewardCatalogDraft(
        id: id, editBaseline: _Baseline(_lifetime, id, null, null, null));
  }

  @override
  Future<RewardCatalogPage> loadPage({String? afterId}) async {
    final author = await _readAuthor();
    Query<Map<String, dynamic>> query = _records.orderBy(FieldPath.documentId);
    if (afterId != null) {
      _id(afterId);
      query = query.startAfter([afterId]);
    }
    final page =
        await query.limit(25).get(const GetOptions(source: Source.server));
    final after = await _readAuthor();
    if (!_same(author.$1, after.$1) || !_same(author.$2, after.$2)) {
      _invalidated = true;
      throw const RewardCatalogSessionChanged();
    }
    final items = page.docs
        .take(24)
        .map((d) => _decode(d.id, d.data(), author.$1, author.$2))
        .toList();
    return RewardCatalogPage(items,
        nextCursor: page.docs.length > 24 ? items.last.id : null);
  }

  @override
  Future<RewardCatalogDraft> save(RewardCatalogDraft draft) async {
    draft.validate();
    _check();
    _id(draft.id);
    final baseline = draft.editBaseline;
    if (baseline is! _Baseline ||
        !identical(baseline.lifetime, _lifetime) ||
        baseline.id != draft.id ||
        draft.revision != (baseline.document?['revision'] ?? 0)) {
      throw const RewardCatalogConflict();
    }
    final create = baseline.document == null;
    if (create && draft.isArchived) {
      throw const FormatException('Save a draft before archiving.');
    }
    final fields = <String, dynamic>{
      'title': draft.title.trim(),
      'description': draft.description.trim(),
      'category': draft.category,
      'imageUrl': draft.imageUrl.trim(),
      'status': draft.isArchived ? 'archived' : 'draft'
    };
    final revision = draft.revision + 1, ref = _records.doc(draft.id);
    Object? failure;
    Map<String, dynamic>? savedUser, savedMember;
    try {
      await _db.runTransaction<void>((tx) async {
        if (failure != null) throw StateError('Reward metadata save aborted.');
        try {
          _check();
          final user = (await tx.get(_user)).data(),
              member = (await tx.get(_member)).data();
          _author(user, member);
          if (!create &&
              (!_same(user, baseline.user) ||
                  !_same(member, baseline.member))) {
            _invalidated = true;
            throw const RewardCatalogSessionChanged();
          }
          final current = (await tx.get(ref)).data();
          if (!_same(current, baseline.document)) {
            throw const RewardCatalogConflict();
          }
          _check();
          savedUser = user;
          savedMember = member;
          tx.set(ref, {
            'schemaVersion': 1,
            ...fields,
            'revision': revision,
            'createdAt':
                baseline.document?['createdAt'] ?? FieldValue.serverTimestamp(),
            'createdBy': baseline.document?['createdBy'] ?? scope.userId,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': scope.userId,
          });
        } on RewardCatalogConflict catch (e) {
          failure = e;
          throw StateError('Reward metadata save aborted.');
        } on RewardCatalogSessionChanged catch (e) {
          failure = e;
          throw StateError('Reward metadata save aborted.');
        }
      });
    } catch (_) {
      if (failure != null) throw failure!;
      rethrow;
    }
    _check();
    final saved =
        (await ref.get(const GetOptions(source: Source.server))).data();
    final author = await _readAuthor();
    if (!_same(author.$1, savedUser) || !_same(author.$2, savedMember)) {
      _invalidated = true;
      throw const RewardCatalogSessionChanged();
    }
    if (saved == null ||
        saved['revision'] != revision ||
        !fields.entries.every((f) => _same(saved[f.key], f.value))) {
      throw const RewardCatalogConflict();
    }
    return _decode(ref.id, saved, author.$1, author.$2);
  }

  void _id(String id) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)) {
      throw const FormatException('Invalid reward identifier.');
    }
  }

  RewardCatalogDraft _decode(String id, Map<String, dynamic> data,
      Map<String, dynamic> user, Map<String, dynamic> member) {
    if (data['schemaVersion'] != 1 ||
        !['draft', 'archived'].contains(data['status']) ||
        data['revision'] is! int ||
        data['revision'] < 1 ||
        data['createdAt'] is! Timestamp ||
        data['updatedAt'] is! Timestamp ||
        data['title'] is! String ||
        data['description'] is! String ||
        data['category'] is! String ||
        data['imageUrl'] is! String) {
      throw const FormatException('Reward metadata is unavailable.');
    }
    final draft = RewardCatalogDraft(
        id: id,
        title: data['title'],
        description: data['description'],
        category: data['category'],
        imageUrl: data['imageUrl'],
        isArchived: data['status'] == 'archived',
        revision: data['revision'],
        editBaseline: _Baseline(_lifetime, id, data, user, member));
    draft.validate();
    return draft;
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

class _Baseline {
  _Baseline(this.lifetime, this.id, Map<String, dynamic>? document,
      Map<String, dynamic>? user, Map<String, dynamic>? member)
      : document = document == null ? null : _freeze(document) as Map,
        user = user == null ? null : _freeze(user) as Map,
        member = member == null ? null : _freeze(member) as Map;
  final Object lifetime;
  final String id;
  final Map? document, user, member;
}
