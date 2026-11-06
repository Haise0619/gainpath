// Shared test-only transport, resolved with each Flutter app's dependencies.
// ignore_for_file: depend_on_referenced_packages, curly_braces_in_flow_control_structures
import 'dart:async';
import 'dart:convert';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:http/http.dart' as http;

/// Real Auth / protected Functions / Rules-backed Firestore REST transport for
/// ordinary Flutter widget compositions without native Firebase plugins.
class FypEmulatorGateway
    implements FirebaseAuthGateway, FirebaseAuthSessionGateway {
  FypEmulatorGateway(this.client,{this.canonicalAdminOnly=false});
  final bool canonicalAdminOnly;
  static const project = 'demo-gainpath-fyp';
  final http.Client client;
  String? _token;
  FirebaseAuthUser? current;
  int authSignInRequests = 0, protectedSessionRequests = 0;
  int activeCommandRequests = 0;
  final _changes = StreamController<FirebaseAuthUser?>.broadcast();
  @override
  Stream<FirebaseAuthUser?> get userChanges => _changes.stream;
  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token'
      };
  @override
  Future<FirebaseAuthUser> signIn(
      {required String email, required String password}) async {
    authSignInRequests++;
    final response = await client
        .post(
            Uri.parse(
                'http://127.0.0.1:19131/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulator-key'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
              'returnSecureToken': true
            }))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200)
      throw const AuthException('Emulator sign-in failed.');
    final body = jsonDecode(response.body) as Map;
    _token = body['idToken'] as String;
    final uid = body['localId'] as String;
    final lookup = await client
        .post(
            Uri.parse(
                'http://127.0.0.1:19131/identitytoolkit.googleapis.com/v1/accounts:lookup?key=emulator-key'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': _token}))
        .timeout(const Duration(seconds: 20));
    if (lookup.statusCode != 200) {
      throw const AuthException('Emulator Auth verification unavailable.');
    }
    final identity =
        ((jsonDecode(lookup.body) as Map)['users'] as List).single as Map;
    if (identity['localId'] != uid || identity['emailVerified'] != true) {
      throw const AuthException('A verified emulator identity is required.');
    }
    if(canonicalAdminOnly){
      final user=await document('users/$uid'),member=await document('orgs/gainpath/members/$uid');
      if(user['organizationId']!='gainpath'||member['role']!='admin'||member['status']!='active')throw const AuthException('Current canonical Admin required.');
      final result=FirebaseAuthUser(userId:uid,email:email,emailVerified:true,displayName:member['displayName'] as String?,claims:{'organizationId':'gainpath','role':'admin','status':'active','branchIds':member['branchIds']});current=result;return result;
    }
    await document('datasetAssignments/$uid');
    protectedSessionRequests++;
    final session = FypDatasetSession.fromResponse(
        await invoke('fypDatasetSessionCommand', {'schemaVersion': 1}));
    final result = FirebaseAuthUser(
        userId: uid,
        email: email,
        emailVerified: identity['emailVerified'] == true,
        datasetScope: session.scope,
        displayName: session.member['displayName'] as String?,
        claims: {
          'organizationId': session.member['organizationId'],
          'role': session.member['role'],
          'status': session.member['status'],
          'branchIds': session.member['branchIds']
        });
    current = result;
    return result;
  }

  @override
  Future<FirebaseAuthUser?> restoreUser() async => current;
  @override
  Future<void> signOut() async {
    current = null;
    _token = null;
    _changes.add(null);
  }

  @override
  Future<FirebaseAuthUser> register(
          {required String email,
          required String password,
          required String name}) =>
      Future.error(UnsupportedError('No emulator registration mutation.'));
  @override
  Future<void> sendEmailVerification() =>
      Future.error(UnsupportedError('No email delivery.'));
  Future<void> dispose() => _changes.close();
  Object? decodeValue(Object? raw) {
    if (raw is! Map) return null;
    if (raw.containsKey('stringValue')) return raw['stringValue'];
    if (raw.containsKey('integerValue'))
      return int.parse('${raw['integerValue']}');
    if (raw.containsKey('doubleValue')) return raw['doubleValue'];
    if (raw.containsKey('booleanValue')) return raw['booleanValue'];
    if (raw.containsKey('timestampValue'))
      return DateTime.parse(raw['timestampValue'] as String);
    if (raw.containsKey('arrayValue'))
      return ((raw['arrayValue'] as Map)['values'] as List? ?? [])
          .map(decodeValue)
          .toList();
    if (raw.containsKey('mapValue'))
      return decodeFields((raw['mapValue'] as Map)['fields'] as Map? ?? {});
    return null;
  }

  Map<String, Object?> decodeFields(Map fields) =>
      fields.map((k, v) => MapEntry(k as String, decodeValue(v)));
  Future<Map<String, Object?>> document(String path) async {
    final response = await client
        .get(
            Uri.parse(
                'http://127.0.0.1:18231/v1/projects/$project/databases/(default)/documents/$path'),
            headers: headers)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200)
      throw StateError('Rules refused document: ${response.statusCode}');
    return decodeFields((jsonDecode(response.body) as Map)['fields'] as Map);
  }

  Future<List<MapEntry<String, Map<String, Object?>>>> query(
      String root, String collection,
      {Map<String, Object?>? where, int limit = 30}) async {
    Map<String, Object?> encoded(Object? value) =>
        value is String ? {'stringValue': value} : {'booleanValue': value};
    final response = await client
        .post(
            Uri.parse(
                'http://127.0.0.1:18231/v1/projects/$project/databases/(default)/documents/$root:runQuery'),
            headers: headers,
            body: jsonEncode({
              'structuredQuery': {
                'from': [
                  {'collectionId': collection}
                ],
                'limit': limit,
                if (where != null)
                  'where': {
                    'compositeFilter': {
                      'op': 'AND',
                      'filters': [
                        for (final entry in where.entries)
                          {
                            'fieldFilter': {
                              'field': {'fieldPath': entry.key},
                              'op': 'EQUAL',
                              'value': encoded(entry.value)
                            }
                          }
                      ]
                    }
                  }
              }
            }))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200)
      throw StateError('Rules refused query: ${response.statusCode}');
    return (jsonDecode(response.body) as List)
        .where((r) => r['document'] != null)
        .map((r) {
      final d = r['document'] as Map;
      return MapEntry((d['name'] as String).split('/').last,
          decodeFields(d['fields'] as Map));
    }).toList();
  }

  Future<Object?> invoke(String name, Map<String, Object?> data) async {
    activeCommandRequests++;
    try {
      String part(Object v) =>
          base64UrlEncode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
      final appCheck = '${part({'alg': 'none'})}.${part({
            'sub': 'gainpath-fyp-widget',
            'aud': project,
            'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600
          })}.';
      final response = await client
          .post(
              Uri.parse(
                  'http://127.0.0.1:15031/$project/asia-southeast1/$name'),
              headers: {...headers, 'X-Firebase-AppCheck': appCheck},
              body: jsonEncode({'data': data}))
          .timeout(const Duration(seconds: 60));
      final body = jsonDecode(response.body) as Map;
      if (response.statusCode != 200 || body.containsKey('error'))
        throw StateError(
            'Protected emulator callable refused: ${body['error']}');
      return body['result'] ?? body['data'];
    } finally {
      activeCommandRequests--;
    }
  }

  ScopedCommandTransport transport(
          SessionScope scope, bool Function() currentSession) =>
      FypDatasetTransport(
          scope: scope,
          isCurrent: () => currentSession() && current?.userId == scope.userId,
          invoke: invoke);
}
