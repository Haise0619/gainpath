import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

import 'firebase_function_transport.dart';

class FirebaseAnnouncementReader implements AnnouncementReader {
  FirebaseAnnouncementReader(
      {required this.scope,
      required this.activeScope,
      FirebaseFunctions? functions,
      FirebaseAuth? auth})
      : _functions = functions,
        _injectedAuth = auth;
  final SessionScope scope;
  final SessionScope? Function() activeScope;
  final FirebaseFunctions? _functions;
  final FirebaseAuth? _injectedAuth;
  late final FirebaseAuth _auth = _injectedAuth ?? FirebaseAuth.instance;
  void _check() {
    if (_auth.currentUser?.uid != scope.userId || activeScope() != scope) {
      throw const AnnouncementSessionChanged();
    }
  }

  @override
  Future<AnnouncementPage> loadAnnouncements({String? afterId}) async {
    _check();
    final callable =
        firebaseCallable('branchManagementCommand', functions: _functions);
    final result = await callable.call<Map<String, dynamic>>({
      'action': 'memberAnnouncements',
      'organizationId': scope.organizationId,
      if (afterId != null) 'afterId': afterId,
    }).timeout(const Duration(seconds: 20));
    _check();
    final items = (result.data['records'] as List).map((raw) {
      final d = Map<String, dynamic>.from(raw as Map);
      final entry = Announcement(
        id: d['id'] as String,
        title: d['title'] as String,
        body: d['body'] as String,
        validFrom: DateTime.fromMillisecondsSinceEpoch(
            d['validFromMillis'] as int,
            isUtc: true),
        validTo: DateTime.fromMillisecondsSinceEpoch(d['validToMillis'] as int,
            isUtc: true),
        revision: d['revision'] as int,
        audience:
            AnnouncementAudience.values.byName(d['audienceScope'] as String),
        category: AnnouncementCategory.values.byName(d['category'] as String),
        priority: AnnouncementPriority.values.byName(d['priority'] as String),
        targetBranchIds:
            List<String>.unmodifiable(d['targetBranchIds'] as List),
        targetBranchNames: List<String>.unmodifiable(d['branchNames'] as List),
      );
      entry.validate();
      return entry;
    });
    return AnnouncementPage(items,
        nextCursor: result.data['nextAfterId'] as String?);
  }
}
